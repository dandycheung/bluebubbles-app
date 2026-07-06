import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/app/layouts/conversation_details/attachment_section_type.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

typedef MediaFiltersChanged = void Function(
  MediaFilter typeFilter,
  MediaSenderFilter senderFilter,
  DateTime? sinceDate,
);

void showMediaFiltersSheet(
  BuildContext context, {
  required Chat chat,
  required Color tileColor,
  required MediaFilter mediaFilter,
  required MediaSenderFilter senderFilter,
  required DateTime? sinceDate,
  required MediaFiltersChanged onChanged,
}) {
  HapticFeedback.lightImpact();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      var currentTypeFilter = mediaFilter;
      var currentSenderFilter = senderFilter;
      var currentSinceDate = sinceDate;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final labelStyle = TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface,
          );
          final sectionLabelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              );
          final primaryColor = Theme.of(context).colorScheme.primary;

          void updateFilters({
            MediaFilter? type,
            MediaSenderFilter? sender,
            DateTime? date,
            bool clearDate = false,
          }) {
            if (type != null) currentTypeFilter = type;
            if (sender != null) currentSenderFilter = sender;
            if (clearDate) {
              currentSinceDate = null;
            } else if (date != null) {
              currentSinceDate = date;
            }
            onChanged(currentTypeFilter, currentSenderFilter, currentSinceDate);
            setSheetState(() {});
          }

          final showFromYou = currentSenderFilter.kind != MediaSenderFilterKind.fromOthers &&
              currentSenderFilter.kind != MediaSenderFilterKind.participant;
          final showFromOthers = chat.isGroup &&
              currentSenderFilter.kind != MediaSenderFilterKind.fromYou &&
              currentSenderFilter.kind != MediaSenderFilterKind.participant;
          final showParticipants = currentSenderFilter.kind != MediaSenderFilterKind.fromYou &&
              currentSenderFilter.kind != MediaSenderFilterKind.fromOthers;

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: tileColor,
            ),
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 20),
            child: SingleChildScrollView(
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
                    child: Text("Sender", style: sectionLabelStyle),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 0,
                        children: [
                          if (showFromYou)
                            BBChip(
                              showCheckmark: true,
                              selected: currentSenderFilter.kind == MediaSenderFilterKind.fromYou,
                              checkmarkColor: primaryColor,
                              avatar: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: const ContactAvatarWidget(
                                  handle: null,
                                  size: 24,
                                  editable: false,
                                  scaleSize: false,
                                  borderThickness: 0,
                                ),
                              ),
                              label: Text("From You", style: labelStyle),
                              onSelected: (selected) {
                                updateFilters(
                                  sender: selected ? const MediaSenderFilter.fromYou() : const MediaSenderFilter.any(),
                                );
                              },
                            ),
                          if (showFromOthers)
                            BBChip(
                              showCheckmark: true,
                              selected: currentSenderFilter.kind == MediaSenderFilterKind.fromOthers,
                              checkmarkColor: primaryColor,
                              label: Text("From Others", style: labelStyle),
                              onSelected: (selected) {
                                updateFilters(
                                  sender:
                                      selected ? const MediaSenderFilter.fromOthers() : const MediaSenderFilter.any(),
                                );
                              },
                            ),
                          if (showParticipants)
                            for (final handle in chat.handles)
                              if (currentSenderFilter.kind != MediaSenderFilterKind.participant ||
                                  currentSenderFilter.participant?.address == handle.address)
                                _ParticipantSenderChip(
                                  handle: handle,
                                  labelStyle: labelStyle,
                                  primaryColor: primaryColor,
                                  selected: currentSenderFilter.kind == MediaSenderFilterKind.participant &&
                                      currentSenderFilter.participant?.address == handle.address,
                                  onSelected: (selected) {
                                    updateFilters(
                                      sender: selected
                                          ? MediaSenderFilter.participant(handle)
                                          : const MediaSenderFilter.any(),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, left: 10),
                    child: Text("Type", style: sectionLabelStyle),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 0,
                        children: [
                          if (currentTypeFilter != MediaFilter.videos)
                            BBChip(
                              showCheckmark: true,
                              selected: currentTypeFilter == MediaFilter.images,
                              checkmarkColor: primaryColor,
                              label: Text("Images", style: labelStyle),
                              onSelected: (selected) {
                                updateFilters(type: selected ? MediaFilter.images : MediaFilter.all);
                              },
                            ),
                          if (currentTypeFilter != MediaFilter.images)
                            BBChip(
                              showCheckmark: true,
                              selected: currentTypeFilter == MediaFilter.videos,
                              checkmarkColor: primaryColor,
                              label: Text("Videos", style: labelStyle),
                              onSelected: (selected) {
                                updateFilters(type: selected ? MediaFilter.videos : MediaFilter.all);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, left: 10),
                    child: Text("Date", style: sectionLabelStyle),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 0,
                        children: [
                          BBChip(
                            avatar: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.calendar_today_outlined,
                                color: primaryColor,
                                size: 12,
                              ),
                            ),
                            label: currentSinceDate != null
                                ? Text(
                                    "Since ${buildFullDate(currentSinceDate!, includeTime: currentSinceDate!.isToday(), useTodayYesterday: true)}",
                                    style: labelStyle,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text("Filter by Date", style: labelStyle),
                            onDeleted: currentSinceDate == null
                                ? null
                                : () => updateFilters(clearDate: true),
                            onPressed: () async {
                              final picked = await showTimeframePicker(
                                "Since When?",
                                context,
                                customTimeframes: {
                                  "1 Hour": 1,
                                  "1 Day": 24,
                                  "1 Week": 168,
                                  "1 Month": 720,
                                  "6 Months": 4320,
                                  "1 Year": 8760,
                                },
                                selectionSuffix: "Ago",
                                useTodayYesterday: true,
                              );
                              if (picked != null) {
                                updateFilters(date: picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _ParticipantSenderChip extends StatelessWidget {
  final Handle handle;
  final TextStyle labelStyle;
  final Color primaryColor;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _ParticipantSenderChip({
    required this.handle,
    required this.labelStyle,
    required this.primaryColor,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final handleState = HandleSvc.getOrCreateHandleState(handle);

    return Obx(() {
      final displayName = handleState.displayName.value ?? handle.address;
      return BBChip(
        showCheckmark: true,
        selected: selected,
        checkmarkColor: primaryColor,
        avatar: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: ContactAvatarWidget(
            handle: handle,
            size: 24,
            editable: false,
            scaleSize: false,
            borderThickness: 0,
          ),
        ),
        label: Text("From $displayName", style: labelStyle, overflow: TextOverflow.ellipsis),
        onSelected: onSelected,
      );
    });
  }
}

/// Filter button with badge, matching the search filters trigger.
class MediaFiltersButton extends StatelessWidget {
  final MediaFilter mediaFilter;
  final MediaSenderFilter senderFilter;
  final DateTime? sinceDate;
  final Color? iconColor;
  final VoidCallback onPressed;

  const MediaFiltersButton({
    super.key,
    required this.mediaFilter,
    required this.senderFilter,
    required this.sinceDate,
    required this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter =
        mediaFilter != MediaFilter.all || senderFilter.isActive || sinceDate != null;
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
