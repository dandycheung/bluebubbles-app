import 'package:flutter/material.dart';

/// Section header row with ALL CAPS label and always-visible "See More" action.
class AttachmentSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onShowMore;

  const AttachmentSectionHeader({
    super.key,
    required this.title,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 5, left: 20, right: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          TextButton(
            onPressed: onShowMore,
            child: const Text("See More"),
          ),
        ],
      ),
    );
  }
}
