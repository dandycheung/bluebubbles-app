import 'dart:async';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_location_clipper.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_pin_clipper.dart';
import 'package:bluebubbles/helpers/helpers.dart';

class FindMyController extends GetxController {
  // Scroll Controllers
  final ScrollController devicesController = ScrollController();
  final ScrollController itemsController = ScrollController();
  final ScrollController friendsController = ScrollController();

  // Map & Panel Controllers
  final PopupController popupController = PopupController();
  final MapController mapController = MapController();
  final PanelController panelController = PanelController();
  final completer = Completer<void>();

  // Tab Controller (needs to be created with vsync in the widget)
  TabController? tabController;

  // Observable state variables
  final RxInt tabIndex = 0.obs;
  final RxList<FindMyDevice> devices = <FindMyDevice>[].obs;
  final RxList<FindMyFriend> friends = <FindMyFriend>[].obs;
  final RxList<FindMyFriend> friendsWithLocation = <FindMyFriend>[].obs;
  final RxList<FindMyFriend> friendsWithoutLocation = <FindMyFriend>[].obs;
  final RxMap<String, Marker> markers = <String, Marker>{}.obs;
  final Rxn<Position> location = Rxn<Position>();
  final Rxn<bool> fetching = Rxn<bool>(true);
  final RxBool refreshing = false.obs;
  final Rxn<bool> fetching2 = Rxn<bool>(true);
  final RxBool refreshing2 = false.obs;
  final RxBool canRefresh = false.obs;
  final RxBool hasMovedToCurrentLocation = false.obs;

  StreamSubscription? locationSub;

  @override
  void onInit() {
    super.onInit();
    getLocations();

    // Setup socket listener
    SocketSvc.socket?.on("new-findmy-location", _handleNewFindMyLocation);

    // Allow users to refresh after 30sec
    Future.delayed(const Duration(seconds: 30), () {
      canRefresh.value = true;
    });
  }

  void _handleNewFindMyLocation(dynamic data) {
    try {
      final friend = FindMyFriend.fromJson(data);
      Logger.info("Received new location for ${friend.handle?.address}");
      if ((friend.latitude ?? 0) == 0 && (friend.longitude ?? 0) == 0) return;

      final existingFriendIndex =
          friends.indexWhere((e) => e.handle?.uniqueAddressAndService == friend.handle?.uniqueAddressAndService);
      final existingFriend = existingFriendIndex == -1 ? null : friends[existingFriendIndex];

      if (existingFriend == null ||
          existingFriend.status == null ||
          friend.locatingInProgress ||
          LocationStatus.values.indexOf(existingFriend.status!) <=
              LocationStatus.values.indexOf(friend.status ?? LocationStatus.legacy)) {
        Logger.info("Updating map for ${friend.handle?.address}");
        friends[existingFriendIndex] = friend;

        friendsWithLocation.value =
            friends.where((item) => (item.latitude ?? 0) != 0 && (item.longitude ?? 0) != 0).toList();
        friendsWithoutLocation.value =
            friends.where((item) => (item.latitude ?? 0) == 0 && (item.longitude ?? 0) == 0).toList();

        buildFriendMarker(friend);
      }
    } catch (_) {}
  }

  /// Fetches the FindMy data from the server.
  /// The toggles for refresh friends & devices are separate due to an inconsistency in the server API.
  /// As of v1.9.7 (server), the refresh devices endpoint doesn't return the devices data,
  /// however, the refresh friends endpoint does. The way this was coded assumes that the server
  /// will return the data for both endpoints. A server update will fix this, but for now,
  /// we will "patch" it by only "refreshing" devices when the user manually refreshes the data.
  Future<void> getLocations({bool refreshFriends = true, bool refreshDevices = false}) async {
    if (!(Platform.isLinux && !kIsWeb)) {
      LocationPermission granted = await Geolocator.checkPermission();
      if (granted == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }

      if (granted == LocationPermission.whileInUse || granted == LocationPermission.always) {
        Geolocator.getCurrentPosition().then((loc) {
          location.value = loc;
          buildLocationMarker(location.value!);
          if (!kIsDesktop) {
            locationSub = Geolocator.getPositionStream().listen((event) {
              buildLocationMarker(event);

              if (!hasMovedToCurrentLocation.value) {
                mapController.move(LatLng(location.value!.latitude, location.value!.longitude), 10);
                hasMovedToCurrentLocation.value = true;
              }
            });
          }
        });
      }
    }

    // Fetch friends data
    final response2 = refreshFriends
        ? await HttpSvc.refreshFindMyFriends().catchError((_) async {
            refreshing2.value = false;
            showSnackbar("Error", "Something went wrong refreshing FindMy Friends data!");
            return Response(requestOptions: RequestOptions(path: ''));
          })
        : await HttpSvc.findMyFriends().catchError((_) async {
            fetching2.value = null;
            return Response(requestOptions: RequestOptions(path: ''));
          });

    if (response2.statusCode == 200 && response2.data['data'] != null) {
      try {
        friends.value =
            (response2.data['data'] as List).map((e) => FindMyFriend.fromJson(e)).toList().cast<FindMyFriend>();

        friendsWithLocation.value =
            friends.where((item) => (item.latitude ?? 0) != 0 && (item.longitude ?? 0) != 0).toList();
        friendsWithoutLocation.value =
            friends.where((item) => (item.latitude ?? 0) == 0 && (item.longitude ?? 0) == 0).toList();

        for (FindMyFriend e in friendsWithLocation) {
          buildFriendMarker(e);
        }
        fetching2.value = false;
        refreshing2.value = false;
      } catch (e, s) {
        Logger.error("Failed to parse FindMy Friends location data!", error: e, trace: s);
        fetching2.value = null;
        refreshing2.value = false;
        return;
      }
    } else {
      fetching2.value = false;
      refreshing2.value = false;
    }

    // Fetch devices data
    final response = refreshDevices
        ? await HttpSvc.refreshFindMyDevices().catchError((_) async {
            refreshing.value = false;
            showSnackbar("Error", "Something went wrong refreshing FindMy Devices data!");
            return Response(requestOptions: RequestOptions(path: ''));
          })
        : await HttpSvc.findMyDevices().catchError((_) async {
            fetching.value = null;
            return Response(requestOptions: RequestOptions(path: ''));
          });

    if (response.statusCode == 200 && response.data['data'] != null) {
      try {
        devices.value =
            (response.data['data'] as List).map((e) => FindMyDevice.fromJson(e)).toList().cast<FindMyDevice>();

        for (FindMyDevice e in devices.where((e) => e.location?.latitude != null && e.location?.longitude != null)) {
          buildDeviceMarker(e);
        }
        fetching.value = false;
        refreshing.value = false;
      } catch (e, s) {
        Logger.error("Failed to parse FindMy Devices location data!", error: e, trace: s);
        fetching.value = null;
        refreshing.value = false;
        return;
      }
    } else {
      fetching.value = false;
      refreshing.value = false;
    }

    // Call the FindMy Friends refresh anyways so that new data comes through the socket
    if (!refreshFriends) {
      HttpSvc.refreshFindMyFriends();
    } else {
      canRefresh.value = false;
      // Allow users to refresh after 30sec
      Future.delayed(const Duration(seconds: 30), () {
        canRefresh.value = true;
      });
    }
  }

  void buildDeviceMarker(FindMyDevice e) {
    markers[e.id ?? randomString(6)] = Marker(
      key: ValueKey('device-${e.id ?? randomString(6)}'),
      point: LatLng(e.location!.latitude!, e.location!.longitude!),
      width: 30,
      height: 35,
      child: ClipShadowPath(
        clipper: const FindMyPinClipper(),
        shadow: const BoxShadow(
          color: Colors.black,
          blurRadius: 2,
        ),
        child: Container(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5.0),
              child: e.role?['emoji'] != null
                  ? Text(e.role!['emoji'],
                      style: Get.context!.theme.textTheme.bodyLarge!.copyWith(fontFamily: 'Apple Color Emoji'))
                  : Icon(
                      (e.isMac ?? false)
                          ? Icons.computer
                          : e.isConsideredAccessory
                              ? Icons.headphones
                              : Icons.phone_iphone,
                      color: Colors.black,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
      alignment: Alignment.topCenter,
    );
  }

  void buildFriendMarker(FindMyFriend friend) {
    markers[friend.handle?.uniqueAddressAndService ?? randomString(6)] = Marker(
      key: ValueKey('friend-${friend.handle?.uniqueAddressAndService ?? randomString(6)}'),
      point: LatLng(friend.latitude!, friend.longitude!),
      width: 35,
      height: 35,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ContactAvatarWidget(
                editable: false, handle: friend.handle ?? Handle(address: friend.title ?? "Unknown")),
          ),
        ),
      ),
      alignment: Alignment.topCenter,
    );
  }

  void buildLocationMarker(Position pos) {
    markers['current'] = Marker(
      key: const ValueKey('current'),
      point: LatLng(pos.latitude, pos.longitude),
      width: 25,
      height: 55,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pos.heading.isFinite)
            Transform.rotate(
              angle: pos.heading,
              child: ClipPath(
                clipper: const FindMyLocationClipper(),
                child: Container(
                  width: 25,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.center,
                      end: Alignment.topCenter,
                      colors: [
                        Get.context!.theme.colorScheme.primary,
                        Get.context!.theme.colorScheme.primary.withAlpha(50)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: 25,
            height: 25,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Get.context!.theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      alignment: Alignment.topCenter,
    );
  }

  @override
  void onClose() {
    locationSub?.cancel();
    mapController.dispose();
    popupController.dispose();
    tabController?.dispose();
    SocketSvc.socket?.off("new-findmy-location");
    itemsController.dispose();
    devicesController.dispose();
    friendsController.dispose();
    super.onClose();
  }
}
