import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Quick-filter chip row for custom groups, shown above the chat list when
/// [Settings.showCustomGroupFilterChips] is enabled and at least one custom
/// group exists. Tapping a chip toggles that group in the same
/// [ChatsSvc.chatListFilters] state the Chat Filters sheet reads/writes, so
/// the two stay in sync.
class CustomGroupFilterChipRow extends StatelessWidget {
  const CustomGroupFilterChipRow({super.key, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4)});

  /// Padding around the horizontally-scrolling chip list. Callers can widen
  /// the top/bottom insets to add extra separation from surrounding content
  /// (e.g. the chat list edge) without affecting the other skins.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!SettingsSvc.settings.showCustomGroupFilterChips.value) return const SizedBox.shrink();
      final groups = CustomGroupsSvc.groups;
      if (groups.isEmpty) return const SizedBox.shrink();

      final current = ChatsSvc.chatListFilters.value.customGroupIds;

      // Read chatListVersion so this rebuilds when chats are added/removed, and
      // read each ChatState's hasUnreadMessage below so it rebuilds when any
      // chat's read status changes.
      ChatsSvc.chatListVersion.value;
      final unreadStates = ChatsSvc.chatStates.values.where((s) => s.hasUnreadMessage.value).toList();
      final unreadCounts = <int, int>{
        for (final group in groups)
          group.id!: unreadStates.where((s) => s.chat.customGroups.any((g) => g.id == group.id)).length,
      };

      return SizedBox(
        height: 44 + padding.vertical,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: groups.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            final selected = current.contains(group.id);
            final unreadCount = unreadCounts[group.id] ?? 0;
            return BBChip(
              label: Text(unreadCount > 0 ? '${group.name} ($unreadCount)' : group.name),
              selected: selected,
              showCheckmark: true,
              onPressed: () {
                final next = Set<int>.from(current);
                if (selected) {
                  next.remove(group.id);
                } else {
                  next.add(group.id!);
                }
                ChatsSvc.chatListFilters.value = ChatsSvc.chatListFilters.value.copyWith(customGroupIds: next);
              },
              onLongPress: () {
                // Long-press singles out this group, replacing any other
                // selected groups, instead of toggling it alongside them.
                ChatsSvc.chatListFilters.value = ChatsSvc.chatListFilters.value.copyWith(customGroupIds: {group.id!});
              },
            );
          },
        ),
      );
    });
  }
}
