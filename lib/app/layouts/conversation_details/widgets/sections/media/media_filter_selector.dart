import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MediaFilterSelector extends StatelessWidget {
  final MediaFilter value;
  final ValueChanged<MediaFilter> onChanged;

  const MediaFilterSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  bool get _isIOS => SettingsSvc.settings.skin.value == Skins.iOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Obx(() {
        SettingsSvc.settings.skin.value;
        if (_isIOS) {
          return CupertinoSlidingSegmentedControl<MediaFilter>(
            groupValue: value,
            thumbColor: theme.colorScheme.primary,
            children: {
              for (final filter in MediaFilter.values)
                filter: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    filter.label,
                    style: TextStyle(
                      color: value == filter ? theme.colorScheme.onPrimary : null,
                    ),
                  ),
                ),
            },
            onValueChanged: (filter) {
              if (filter != null) onChanged(filter);
            },
          );
        }

        return SegmentedButton<MediaFilter>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            selectedForegroundColor: theme.colorScheme.onPrimary,
            selectedBackgroundColor: theme.colorScheme.primary,
          ),
          segments: [
            for (final filter in MediaFilter.values)
              ButtonSegment(value: filter, label: Text(filter.label)),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        );
      }),
    );
  }
}
