import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

Future<String?> showCustomMentionDialog(BuildContext context, Mentionable? mention) async {
  final TextEditingController mentionController = TextEditingController(text: mention?.displayName);
  final adaptiveTheme = Theme.of(context);
  String? changed;
  await showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: adaptiveTheme,
          child: AlertDialog(
            actions: [
              TextButton(
                child: Text("Cancel",
                    style: adaptiveTheme.textTheme.bodyLarge!.copyWith(color: adaptiveTheme.colorScheme.primary)),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
              TextButton(
                child: Text("OK",
                    style: adaptiveTheme.textTheme.bodyLarge!.copyWith(color: adaptiveTheme.colorScheme.primary)),
                onPressed: () {
                  if (isNullOrEmptyString(mentionController.text)) {
                    changed = mention?.handle.displayName ?? "";
                  } else {
                    changed = mentionController.text;
                  }
                  Navigator.of(context, rootNavigator: true).pop();
                },
              ),
            ],
            content: TextField(
              controller: mentionController,
              textCapitalization: TextCapitalization.sentences,
              autocorrect: true,
              scrollPhysics: const CustomBouncingScrollPhysics(),
              autofocus: true,
              enableIMEPersonalizedLearning: !SettingsSvc.settings.incognitoKeyboard.value,
              decoration: InputDecoration(
                labelText: "Custom Mention",
                hintText: mention?.handle.displayName ?? "",
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (val) {
                if (isNullOrEmptyString(val)) {
                  val = mention?.handle.displayName ?? "";
                }
                changed = val;
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            title: Text("Custom Mention", style: adaptiveTheme.textTheme.titleLarge),
            backgroundColor: adaptiveTheme.colorScheme.surfaceContainerHighest,
          ),
        );
      });
  return changed;
}
