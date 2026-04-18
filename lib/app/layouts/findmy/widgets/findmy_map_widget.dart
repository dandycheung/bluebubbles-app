import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/wrappers/trackpad_bug_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class FindMyMapWidget extends StatelessWidget {
  final FindMyController controller;

  const FindMyMapWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TrackpadBugWrapper(builder: (context, bugDetected) {
      return Obx(() => FlutterMap(
            mapController: controller.mapController,
            options: MapOptions(
              initialZoom: 5.0,
              minZoom: 1.0,
              maxZoom: 18.0,
              initialCenter: controller.location.value == null
                  ? const LatLng(0, 0)
                  : LatLng(controller.location.value!.latitude, controller.location.value!.longitude),
              onTap: (_, __) => controller.popupController.hideAllPopups(),
              keepAlive: true,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                forceOnlySinglePinchGesture: bugDetected,
              ),
              onMapReady: () {
                if (!controller.completer.isCompleted) {
                  controller.completer.complete();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bluebubbles.app',
              ),
              PopupMarkerLayer(
                options: PopupMarkerLayerOptions(
                  popupController: controller.popupController,
                  markers: controller.markers.values.toList(),
                  popupDisplayOptions: PopupDisplayOptions(
                    builder: (context, marker) => _buildMarkerPopup(context, marker),
                  ),
                ),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          ));
    });
  }

  Widget _buildMarkerPopup(BuildContext context, Marker marker) {
    final ValueKey? key = marker.key as ValueKey?;
    if (key?.value == "current") return const SizedBox();

    if (key?.value.contains("device")) {
      final item = controller.devices.firstWhere(
          (e) => e.location?.latitude == marker.point.latitude && e.location?.longitude == marker.point.longitude);
      return _buildDevicePopup(context, item);
    } else {
      final item = controller.friends
          .firstWhere((e) => e.latitude == marker.point.latitude && e.longitude == marker.point.longitude);
      return _buildFriendPopup(context, item);
    }
  }

  Widget _buildDevicePopup(BuildContext context, FindMyDevice item) {
    return Obx(() => Padding(
          padding: const EdgeInsets.only(bottom: 5.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SettingsSvc.settings.redactedMode.value ? "Device" : (item.name ?? "Unknown Device"),
                    style: context.theme.textTheme.labelLarge),
                Text(
                    SettingsSvc.settings.redactedMode.value
                        ? "Location"
                        : (item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found"),
                    style: context.theme.textTheme.bodySmall),
              ],
            ),
          ),
        ));
  }

  Widget _buildFriendPopup(BuildContext context, FindMyFriend item) {
    return Obx(() => Padding(
          padding: const EdgeInsets.only(bottom: 5.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.handle?.displayName ?? item.title ?? "Unknown Friend",
                    style: context.theme.textTheme.labelLarge),
                Text(SettingsSvc.settings.redactedMode.value ? "Location" : (item.longAddress ?? "No location found"),
                    style: context.theme.textTheme.bodySmall),
                if (item.lastUpdated != null && item.status != LocationStatus.live)
                  Text("Last updated ${buildDate(item.lastUpdated)}", style: context.theme.textTheme.bodySmall),
                if (item.status != null)
                  Text("${item.status!.name.capitalize!} Location", style: context.theme.textTheme.bodySmall),
              ],
            ),
          ),
        ));
  }
}
