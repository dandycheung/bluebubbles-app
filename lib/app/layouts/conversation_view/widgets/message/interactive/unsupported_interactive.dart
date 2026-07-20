import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class UnsupportedInteractive extends StatefulWidget {
  const UnsupportedInteractive({
    super.key,
    required this.payloadData,
  });

  final iMessageAppData? payloadData;

  @override
  State<UnsupportedInteractive> createState() => _UnsupportedInteractiveState();
}

class _UnsupportedInteractiveState extends State<UnsupportedInteractive>
    with AutomaticKeepAliveClientMixin, ThemeHelpers {
  iMessageAppData? get data => widget.payloadData;
  dynamic get file => File(content.path!);

  dynamic content;

  String getAppName(Message message) {
    final balloonBundleId = message.balloonBundleId;
    final temp = balloonBundleIdMap[balloonBundleId?.split(":").first];
    String? name;
    if (temp is Map) {
      name = temp[balloonBundleId?.split(":").last];
    } else if (temp is String) {
      name = temp;
    }
    return name ?? "Unknown";
  }

  IconData getIcon(Message message) {
    final balloonBundleId = message.balloonBundleId;
    final temp = balloonBundleIdIconMap[balloonBundleId?.split(":").first];
    IconData? icon;
    if (temp is Map) {
      icon = temp[balloonBundleId?.split(":").last];
    } else if (temp is IconData) {
      icon = temp;
    }
    return icon ?? (SettingsSvc.settings.skin.value == Skins.iOS ? CupertinoIcons.square_grid_3x2 : Icons.apps);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final message = MessageStateScope.messageOf(context);
    if (content == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final attachment = MessageStateScope.messageOf(context).dbAttachments.firstOrNull;
        if (attachment != null) {
          content = AttachmentsSvc.getContent(attachment, autoDownload: true, onComplete: (file) {
            if (mounted) {
              setState(() {
                content = file;
              });
            }
          });
          if (content != null && mounted) setState(() {});
        }
      });
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content is PlatformFile && content.bytes != null)
          Image.memory(
            content.bytes!,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, object, stacktrace) => Center(
              heightFactor: 1,
              child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
            ),
          ),
        if (content is PlatformFile && content.bytes == null && content.path != null)
          Image.file(
            file,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, object, stacktrace) => Center(
              heightFactor: 1,
              child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    data?.appName ?? getAppName(message),
                    style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isNullOrEmpty(data?.userInfo?.caption)) const SizedBox(height: 2.5),
                  if (!isNullOrEmpty(data?.userInfo?.caption))
                    Text(data!.userInfo!.caption!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal)),
                  const SizedBox(height: 5),
                  Text(
                    "Unsupported interactive message",
                    style: context.theme.textTheme.labelMedium!
                        .copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                    overflow: TextOverflow.clip,
                    maxLines: 2,
                  ),
                ]),
              ),
              Icon(getIcon(message), color: context.theme.colorScheme.onSurfaceVariant, size: 48),
            ],
          ),
        ),
      ],
    );
  }
}
