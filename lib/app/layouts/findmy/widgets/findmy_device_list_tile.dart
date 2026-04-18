import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_raw_data_dialog.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_launcher/maps_launcher.dart';

class FindMyDeviceListTile extends StatelessWidget {
  final FindMyDevice item;
  final FindMyController controller;
  final bool isItem;

  const FindMyDeviceListTile({
    super.key,
    required this.item,
    required this.controller,
    this.isItem = false,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final displayName = SettingsSvc.settings.redactedMode.value
          ? (isItem ? "Item" : "Device")
          : (item.name ?? (isItem ? "Unknown Item" : "Unknown Device"));

      final displayLocation = SettingsSvc.settings.redactedMode.value
          ? "Location"
          : (item.address?.label ?? item.address?.mapItemFullAddress ?? "No location found");

      return ListTile(
        mouseCursor: MouseCursor.defer,
        title: Text(displayName),
        subtitle: Text(displayLocation),
        onTap: item.location?.latitude != null && item.location?.longitude != null
            ? () async {
                await controller.panelController.close();
                await controller.completer.future;
                final marker = controller.markers.values.firstWhere((e) =>
                    e.point.latitude == item.location?.latitude && e.point.longitude == item.location?.longitude);
                controller.popupController.showPopupsOnlyFor([marker]);
                controller.mapController.move(LatLng(item.location!.latitude!, item.location!.longitude!), 10);
              }
            : null,
        trailing: item.location?.latitude != null && item.location?.longitude != null
            ? ButtonTheme(
                minWidth: 1,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: context.theme.colorScheme.primaryContainer,
                  ),
                  onPressed: () async {
                    await MapsLauncher.launchCoordinates(item.location!.latitude!, item.location!.longitude!);
                  },
                  child: const Icon(Icons.directions, size: 20),
                ),
              )
            : null,
        onLongPress: () async {
          showDialog(
            context: context,
            builder: (context) => FindMyRawDataDialog(item: item),
          );
        },
      );
    }); // end Obx
  }
}
