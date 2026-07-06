import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showMediaFiltersSheet(
  BuildContext context, {
  required Color tileColor,
  required MediaFilter mediaFilter,
  required ValueChanged<MediaFilter> onChanged,
}) {
  HapticFeedback.lightImpact();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      var currentFilter = mediaFilter;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final labelStyle = TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface,
          );

          return Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: tileColor,
            ),
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    "Filters",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 10),
                  child: Text(
                    "Type",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
                    child: Wrap(
                      direction: Axis.horizontal,
                      alignment: WrapAlignment.start,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (currentFilter != MediaFilter.videos)
                          BBChip(
                            showCheckmark: true,
                            selected: currentFilter == MediaFilter.images,
                            checkmarkColor: Theme.of(context).colorScheme.primary,
                            label: Text("Images", style: labelStyle),
                            onSelected: (selected) {
                              final next = selected ? MediaFilter.images : MediaFilter.all;
                              setSheetState(() => currentFilter = next);
                              onChanged(next);
                            },
                          ),
                        if (currentFilter != MediaFilter.images)
                          BBChip(
                            showCheckmark: true,
                            selected: currentFilter == MediaFilter.videos,
                            checkmarkColor: Theme.of(context).colorScheme.primary,
                            label: Text("Videos", style: labelStyle),
                            onSelected: (selected) {
                              final next = selected ? MediaFilter.videos : MediaFilter.all;
                              setSheetState(() => currentFilter = next);
                              onChanged(next);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Filter button with badge, matching the search filters trigger.
class MediaFiltersButton extends StatelessWidget {
  final MediaFilter mediaFilter;
  final Color? iconColor;
  final VoidCallback onPressed;

  const MediaFiltersButton({
    super.key,
    required this.mediaFilter,
    required this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = mediaFilter != MediaFilter.all;
    final color = iconColor ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (hasActiveFilter)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onPressed();
            },
            icon: Icon(Icons.tune, color: color),
          ),
        ],
      ),
    );
  }
}
