import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A live, non-interactive mockup of the app's UI that re-renders whenever
/// [struct] changes.  Wrap the caller in [Obx] and read version to rebuild.
class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({super.key, required this.struct});

  final ThemeStruct struct;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Theme(
        data: struct.data,
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 460;
              return SizedBox(
                height: 240,
                child: wide ? _wideLayout(context) : _narrowLayout(context),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _chatListPane(context)),
        VerticalDivider(
          width: 1,
          color: context.theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        Expanded(child: _chatViewPane(context)),
      ],
    );
  }

  Widget _narrowLayout(BuildContext context) {
    return _chatViewPane(context);
  }

  // ── Chat list pane ──────────────────────────────────────────────────────────

  Widget _chatListPane(BuildContext context) {
    final cs = context.theme.colorScheme;
    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _miniAppBar(context, "BlueBubbles"),
          Expanded(
            child: Column(
              children: [
                _fakeChatRow(context, "Alice", "Hey! Are you free later?", "9:41 AM", cs.primaryContainer,
                    cs.onPrimaryContainer),
                _fakeChatRow(context, "Bob & Emma", "See you tomorrow!", "Yesterday", cs.secondaryContainer,
                    cs.onSecondaryContainer),
                _fakeChatRow(
                    context, "Work Chat", "Meeting at 3pm", "Mon", cs.tertiaryContainer, cs.onTertiaryContainer),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAppBar(BuildContext context, String title) {
    final cs = context.theme.colorScheme;
    return Container(
      height: 40,
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: context.theme.textTheme.titleSmall?.copyWith(color: cs.onSurface),
      ),
    );
  }

  Widget _fakeChatRow(BuildContext context, String name, String preview, String time, Color avatarBg, Color avatarFg) {
    final cs = context.theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarBg,
            child: Text(
              name.substring(0, 1),
              style: TextStyle(color: avatarFg, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: context.theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                    Text(time, style: context.theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat view pane ──────────────────────────────────────────────────────────

  Widget _chatViewPane(BuildContext context) {
    final cs = context.theme.colorScheme;
    final bubbleColors = context.theme.extensions[BubbleColors] as BubbleColors?;
    final sentColor = bubbleColors?.iMessageBubbleColor ?? cs.iMessageBubble;
    final onSentColor = bubbleColors?.oniMessageBubbleColor ?? cs.oniMessageBubble;
    final receivedColor = bubbleColors?.receivedBubbleColor ?? cs.surfaceVariant;
    final onReceivedColor = bubbleColors?.onReceivedBubbleColor ?? cs.onSurfaceVariant;

    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _miniAppBar(context, "Alice"),
          Expanded(
            child: Container(
              color: cs.surface,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _fakeBubble(context, "Hey! How are you doing?", false, receivedColor, onReceivedColor),
                  const SizedBox(height: 6),
                  _fakeBubble(context, "I'm great, thanks for asking!", true, sentColor, onSentColor),
                  const SizedBox(height: 6),
                  _fakeBubble(context, "Want to grab coffee?", false, receivedColor, onReceivedColor),
                  const SizedBox(height: 6),
                  _fakeBubble(context, "Absolutely! ☕️", true, sentColor, onSentColor),
                ],
              ),
            ),
          ),
          _fakeInputBar(context),
        ],
      ),
    );
  }

  Widget _fakeBubble(BuildContext context, String text, bool isMe, Color bg, Color fg) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(
          text,
          style: context.theme.textTheme.labelSmall?.copyWith(color: fg),
        ),
      ),
    );
  }

  Widget _fakeInputBar(BuildContext context) {
    final cs = context.theme.colorScheme;
    return Container(
      height: 40,
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.send_rounded, size: 18, color: cs.primary),
        ],
      ),
    );
  }
}
