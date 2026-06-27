import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/conversation_text_field_local_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:file_picker/file_picker.dart' as pf;
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Left-side icon buttons in the conversation text field row:
/// add (+), GIF, emoji picker toggle, and location share.
///
/// All button logic is self-contained here; heavy async flows reference
/// [controller] and [localController] directly.
class TextFieldIconBar extends StatelessWidget {
  const TextFieldIconBar({
    super.key,
    required this.controller,
    required this.localController,
  });

  final ConversationViewController controller;
  final ConversationTextFieldLocalController localController;

  Chat get _chat => controller.chat;

  bool get _iOS => SettingsSvc.settings.skin.value == Skins.iOS;

  bool get _showAttachmentPicker => controller.showAttachmentPicker.value;

  @override
  Widget build(BuildContext context) {
    final hasBackground = ChatsSvc.getChatState(controller.chat.guid)?.customBackgroundPath.value?.isNotEmpty == true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: hasBackground
                  ? context.theme.colorScheme.surfaceContainerHighest
                  : context.theme.colorScheme.outline.withValues(alpha: 0.2),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
              fixedSize: const Size(36, 36),
            ),
            icon: Icon(
              Icons.add,
              color: context.theme.colorScheme.outline,
              size: 22,
            ),
            visualDensity: Platform.isAndroid ? VisualDensity.compact : null,
            onPressed: () async {
              if (kIsDesktop) {
                final res = await FilePicker.pickFiles(withReadStream: true, allowMultiple: true);
                if (res == null || res.files.isEmpty || res.files.first.readStream == null) return;
                for (pf.PlatformFile e in res.files) {
                  if (e.size / 1024000 > 1000) {
                    showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.");
                    continue;
                  }
                  controller.pickedAttachments.add(PlatformFile(
                    path: e.path,
                    name: e.name,
                    size: e.size,
                    bytes: await readByteStream(e.readStream!),
                  ));
                }
              } else if (kIsWeb) {
                showBBDialog(
                  context: context,
                  title: "What would you like to do?",
                  content: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ListTile(
                        title: Text("Upload file", style: Theme.of(context).textTheme.bodyLarge),
                        onTap: () async {
                          final res = await FilePicker.pickFiles(withData: true, allowMultiple: true);
                          if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
                            return;
                          }

                          for (pf.PlatformFile e in res.files) {
                            if (e.size / 1024000 > 1000) {
                              showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.");
                              continue;
                            }
                            controller.pickedAttachments.add(PlatformFile(
                              path: null,
                              name: e.name,
                              size: e.size,
                              bytes: e.bytes!,
                            ));
                          }
                          Get.back();
                        },
                      ),
                      ListTile(
                        title: Text("Send location", style: Theme.of(context).textTheme.bodyLarge),
                        onTap: () async {
                          Share.location(_chat);
                          Get.back();
                        },
                      ),
                    ],
                  ),
                );
              } else {
                if (!_showAttachmentPicker) {
                  controller.focusNode.unfocus();
                  controller.subjectFocusNode.unfocus();
                }
                controller.showAttachmentPicker.value = !_showAttachmentPicker;
              }
            },
          ),
        ),
        if (kIsDesktop || kIsWeb)
          IconButton(
            icon: Icon(_iOS ? CupertinoIcons.smiley_fill : Icons.emoji_emotions,
                color: context.theme.colorScheme.outline, size: 28),
            onPressed: () {
              controller.showEmojiPicker.value = !controller.showEmojiPicker.value;
              (controller.editing.lastOrNull?.controller.focusNode ?? controller.lastFocusedNode).requestFocus();
            },
          ),
        if (kIsDesktop && !Platform.isLinux)
          IconButton(
            icon: Icon(_iOS ? CupertinoIcons.location_solid : Icons.location_on_outlined,
                color: context.theme.colorScheme.outline, size: 28),
            onPressed: () async {
              await Share.location(_chat);
            },
          ),
      ],
    );
  }
}
