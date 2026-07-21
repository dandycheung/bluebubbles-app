import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the conversation-list filter bottom sheet, letting the user pick a
/// single [ChatListFilter] category via tappable chips.
void showChatListFilterSheet(
  BuildContext context, {
  required ChatListFilter current,
  required ValueChanged<ChatListFilter> onChanged,
}) {
  HapticFeedback.lightImpact();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      var selected = current;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final labelStyle = TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface,
          );
          final primaryColor = Theme.of(context).colorScheme.primary;

          void select(ChatListFilter value) {
            setSheetState(() => selected = value);
            onChanged(value);
          }

          Widget filterChip(String label, ChatListFilter value) {
            return BBChip(
              showCheckmark: true,
              selected: selected == value,
              checkmarkColor: primaryColor,
              label: Text(label, style: labelStyle),
              onSelected: (_) => select(value),
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
                  Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, left: 10, right: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          filterChip("All Messages", ChatListFilter.all),
                          filterChip("Known Senders", ChatListFilter.knownSenders),
                          filterChip("Unknown Senders", ChatListFilter.unknownSenders),
                          // filterChip("2FA Codes", ChatListFilter.twoFactor),     // requires Message.isServiceMessage
                          // filterChip("Spam", ChatListFilter.spam),               // requires Message.isSpam
                          // filterChip("Promotions", ChatListFilter.promotions),   // future
                          // filterChip("Transactions", ChatListFilter.transactions), // future
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
