import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/filters/chat_list_filters.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the conversation-list filter bottom sheet. Each section (Status,
/// Sender, Chat Type) is single-select via chips, but the sections combine
/// with AND semantics — e.g. picking "Unread" + "Group Chats" shows only
/// unread group chats.
void showChatListFilterSheet(
  BuildContext context, {
  required ChatListFilters current,
  required ValueChanged<ChatListFilters> onChanged,
}) {
  HapticFeedback.lightImpact();

  // The legacy "Filter Unknown Senders" setting already owns known/unknown
  // sender classification globally (see ChatsService.getFilteredChats) — if a
  // stale Sender selection was persisted (e.g. via "Remember Filters") from
  // before this setting was turned on, normalize it so the greyed-out section
  // doesn't silently show an inert selected chip.
  final legacyUnknownSenderFilterActive = SettingsSvc.settings.filterUnknownSenders.value;
  var current0 = current;
  if (legacyUnknownSenderFilterActive && current0.senderFilter != ChatSenderFilter.all) {
    current0 = current0.copyWith(senderFilter: ChatSenderFilter.all);
    onChanged(current0);
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      var currentFilters = current0;

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

          void update({
            ChatReadFilter? readFilter,
            ChatSenderFilter? senderFilter,
            ChatTypeFilter? typeFilter,
            ChatMuteFilter? muteFilter,
            ChatServiceFilter? serviceFilter,
          }) {
            currentFilters = currentFilters.copyWith(
              readFilter: readFilter,
              // Sender doesn't meaningfully apply to group chats (a group is always
              // treated as a "known" sender regardless of its participants) — reset
              // it to All whenever the user switches to the Group Chats chip so the
              // greyed-out Sender section doesn't silently hold a stale selection.
              senderFilter: typeFilter == ChatTypeFilter.group ? ChatSenderFilter.all : senderFilter,
              typeFilter: typeFilter,
              muteFilter: muteFilter,
              serviceFilter: serviceFilter,
            );
            onChanged(currentFilters);
            setSheetState(() {});
          }

          Widget sectionLabel(String label) => Padding(
                padding: const EdgeInsets.only(top: 16, left: 10),
                child: Text(label, style: sectionLabelStyle),
              );

          Widget chipWrap(List<Widget> chips) => Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                  child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                ),
              );

          Widget filterChip(String label, bool selected, VoidCallback onTap, {bool enabled = true}) {
            return Opacity(
              opacity: enabled ? 1.0 : 0.4,
              child: BBChip(
                showCheckmark: true,
                selected: selected,
                checkmarkColor: primaryColor,
                tapEnabled: enabled,
                label: Text(label, style: labelStyle),
                onSelected: enabled ? (_) => onTap() : null,
              ),
            );
          }

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "Filter",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  sectionLabel("Status"),
                  chipWrap([
                    filterChip("All Messages", currentFilters.readFilter == ChatReadFilter.all,
                        () => update(readFilter: ChatReadFilter.all)),
                    filterChip("Unread Messages", currentFilters.readFilter == ChatReadFilter.unread,
                        () => update(readFilter: ChatReadFilter.unread)),
                  ]),
                  sectionLabel("Chat Type"),
                  chipWrap([
                    filterChip("All", currentFilters.typeFilter == ChatTypeFilter.all,
                        () => update(typeFilter: ChatTypeFilter.all)),
                    filterChip("Group Chats", currentFilters.typeFilter == ChatTypeFilter.group,
                        () => update(typeFilter: ChatTypeFilter.group)),
                    filterChip("Direct Messages", currentFilters.typeFilter == ChatTypeFilter.direct,
                        () => update(typeFilter: ChatTypeFilter.direct)),
                  ]),
                  sectionLabel("Sender"),
                  if (legacyUnknownSenderFilterActive)
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10, top: 2),
                      child: Text(
                        "Controlled by \"Filter Unknown Senders\" in Settings",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                  chipWrap([
                    filterChip("All", currentFilters.senderFilter == ChatSenderFilter.all,
                        () => update(senderFilter: ChatSenderFilter.all),
                        enabled: currentFilters.typeFilter != ChatTypeFilter.group && !legacyUnknownSenderFilterActive),
                    filterChip("Known Senders", currentFilters.senderFilter == ChatSenderFilter.known,
                        () => update(senderFilter: ChatSenderFilter.known),
                        enabled: currentFilters.typeFilter != ChatTypeFilter.group && !legacyUnknownSenderFilterActive),
                    filterChip("Unknown Senders", currentFilters.senderFilter == ChatSenderFilter.unknown,
                        () => update(senderFilter: ChatSenderFilter.unknown),
                        enabled: currentFilters.typeFilter != ChatTypeFilter.group && !legacyUnknownSenderFilterActive),
                  ]),
                  sectionLabel("Mute Status"),
                  chipWrap([
                    filterChip("All", currentFilters.muteFilter == ChatMuteFilter.all,
                        () => update(muteFilter: ChatMuteFilter.all)),
                    filterChip("Muted", currentFilters.muteFilter == ChatMuteFilter.muted,
                        () => update(muteFilter: ChatMuteFilter.muted)),
                    filterChip("Unmuted", currentFilters.muteFilter == ChatMuteFilter.unmuted,
                        () => update(muteFilter: ChatMuteFilter.unmuted)),
                  ]),
                  sectionLabel("Message Service"),
                  chipWrap([
                    filterChip("All", currentFilters.serviceFilter == ChatServiceFilter.all,
                        () => update(serviceFilter: ChatServiceFilter.all)),
                    filterChip("iMessage", currentFilters.serviceFilter == ChatServiceFilter.iMessage,
                        () => update(serviceFilter: ChatServiceFilter.iMessage)),
                    filterChip("SMS & Other", currentFilters.serviceFilter == ChatServiceFilter.other,
                        () => update(serviceFilter: ChatServiceFilter.other)),
                  ]),
                  // Future "Category" section, pending Message.isServiceMessage / Message.isSpam:
                  // sectionLabel("Category"),
                  // chipWrap([
                  //   filterChip("2FA Codes", ...),
                  //   filterChip("Spam", ...),
                  //   filterChip("Promotions", ...),
                  //   filterChip("Transactions", ...),
                  // ]),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
