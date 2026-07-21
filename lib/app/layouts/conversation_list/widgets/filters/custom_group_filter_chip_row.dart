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
            return BBChip(
              label: Text(group.name),
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
            );
          },
        ),
      );
    });
  }
}
