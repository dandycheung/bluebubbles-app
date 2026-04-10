import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A live, non-interactive mockup of the app's UI that re-renders whenever
/// [struct] changes.  Wrap the caller in [Obx] and read version to rebuild.
/// The preview adapts to the currently selected skin (iOS / Material / Samsung).
class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({super.key, required this.struct});

  final ThemeStruct struct;

  @override
  Widget build(BuildContext context) {
    final skin = SettingsSvc.settings.skin.value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Theme(
        data: struct.data,
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 460;
              return SizedBox(
                height: skin == Skins.iOS ? 265 : 240,
                child: wide ? _wideLayout(ctx, skin) : _narrowLayout(ctx, skin),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context, Skins skin) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _chatListPane(context, skin)),
        VerticalDivider(width: 1, color: context.theme.colorScheme.outline.withValues(alpha: 0.3)),
        Expanded(child: _chatViewPane(context, skin)),
      ],
    );
  }

  Widget _narrowLayout(BuildContext context, Skins skin) => _chatViewPane(context, skin);

  // ── Chat list pane ──────────────────────────────────────────────────────────

  Widget _chatListPane(BuildContext context, Skins skin) {
    final cs = context.theme.colorScheme;
    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _listHeader(context, skin, "BlueBubbles"),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _fakeChatRow(context, skin, "Alice", "Hey, are you free later?", "9:41 AM", cs.primaryContainer,
                    cs.onPrimaryContainer),
                _chatDivider(context, skin),
                _fakeChatRow(context, skin, "Bob & Emma", "See you tomorrow!", "Yesterday", cs.secondaryContainer,
                    cs.onSecondaryContainer),
                _chatDivider(context, skin),
                _fakeChatRow(
                    context, skin, "Work Chat", "Meeting at 3pm", "Mon", cs.tertiaryContainer, cs.onTertiaryContainer),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listHeader(BuildContext context, Skins skin, String title) {
    final cs = context.theme.colorScheme;
    final bool isIOS = skin == Skins.iOS;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isIOS ? cs.surfaceContainerHighest.withValues(alpha: 0.7) : cs.surfaceContainerHighest,
        border: isIOS ? Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25), width: 0.5)) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: context.theme.textTheme.titleSmall
            ?.copyWith(color: cs.onSurface, fontWeight: isIOS ? FontWeight.bold : FontWeight.w500),
      ),
    );
  }

  Widget _chatDivider(BuildContext context, Skins skin) {
    final divColor = context.theme.colorScheme.outline.withValues(alpha: 0.15);
    if (skin == Skins.iOS) {
      return Padding(
        padding: const EdgeInsets.only(left: 58),
        child: Divider(height: 0.5, thickness: 0.5, color: divColor),
      );
    }
    return Divider(height: 0.5, thickness: 0.5, color: divColor);
  }

  Widget _fakeChatRow(
      BuildContext context, Skins skin, String name, String preview, String time, Color avatarBg, Color avatarFg) {
    final cs = context.theme.colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarBg,
            child: Text(name.substring(0, 1),
                style: TextStyle(color: avatarFg, fontSize: 13, fontWeight: FontWeight.bold)),
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
          if (skin != Skins.iOS) ...[
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }

  // ── Chat view pane ──────────────────────────────────────────────────────────

  Widget _chatViewPane(BuildContext context, Skins skin) {
    final cs = context.theme.colorScheme;
    final bubbleColors = context.theme.extensions[BubbleColors] as BubbleColors?;
    final sentColor = bubbleColors?.iMessageBubbleColor ?? cs.iMessageBubble;
    final onSentColor = bubbleColors?.oniMessageBubbleColor ?? cs.oniMessageBubble;
    final receivedColor = bubbleColors?.receivedBubbleColor ?? cs.surfaceContainerHighest;
    final onReceivedColor = bubbleColors?.onReceivedBubbleColor ?? cs.onSurfaceVariant;

    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _chatHeader(context, skin),
          Expanded(
            child: Container(
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: skin == Skins.iOS
                  ? _iOSMessageList(context, sentColor, onSentColor, receivedColor, onReceivedColor)
                  : _groupedMessageList(context, sentColor, onSentColor, receivedColor, onReceivedColor),
            ),
          ),
          _textField(context, skin),
        ],
      ),
    );
  }

  // ── Per-skin chat header ────────────────────────────────────────────────────

  Widget _chatHeader(BuildContext context, Skins skin) {
    final cs = context.theme.colorScheme;
    if (skin == Skins.iOS) {
      return Container(
        height: 62,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
          border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25), width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Icon(Icons.chevron_left_rounded, color: cs.primary, size: 24),
            const Spacer(),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.primaryContainer,
                    child: Text("A", style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer))),
                const SizedBox(height: 2),
                Text("Alice", style: context.theme.textTheme.labelSmall?.copyWith(color: cs.onSurface, fontSize: 9)),
              ],
            ),
            const Spacer(),
            Icon(Icons.videocam_outlined, color: cs.primary, size: 20),
            const SizedBox(width: 4),
          ],
        ),
      );
    } else {
      // Material / Samsung — standard AppBar style
      return Container(
        height: 50,
        color: cs.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            const SizedBox(width: 2),
            Icon(Icons.arrow_back, size: 20, color: cs.onSurface),
            const SizedBox(width: 4),
            CircleAvatar(
                radius: 14,
                backgroundColor: cs.primaryContainer,
                child: Text("A", style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer))),
            const SizedBox(width: 8),
            Expanded(
              child: Text("Alice",
                  style: context.theme.textTheme.bodySmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.more_vert, size: 18, color: cs.onSurface),
            const SizedBox(width: 4),
          ],
        ),
      );
    }
  }

  // ── iOS message list (independent bubbles with tail + avatar) ───────────────

  Widget _iOSMessageList(
      BuildContext context, Color sentColor, Color onSentColor, Color receivedColor, Color onReceivedColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _iOSBubbleRow(context, "Hey! How are you?", false, receivedColor, onReceivedColor, showTail: true),
        const SizedBox(height: 5),
        _iOSBubbleRow(context, "I'm great, thanks!", true, sentColor, onSentColor, showTail: true),
        const SizedBox(height: 5),
        _iOSBubbleRow(context, "Coffee soon? ☕", false, receivedColor, onReceivedColor, showTail: true),
        const SizedBox(height: 5),
        _iOSBubbleRow(context, "Absolutely! 😄", true, sentColor, onSentColor, showTail: true),
      ],
    );
  }

  Widget _iOSBubbleRow(BuildContext context, String text, bool isMe, Color bg, Color onBg, {required bool showTail}) {
    final cs = context.theme.colorScheme;
    if (isMe) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [_bubble(context, text, true, bg, onBg, showTail: showTail)],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        showTail
            ? CircleAvatar(
                radius: 11,
                backgroundColor: cs.primaryContainer,
                child: Text("A", style: TextStyle(fontSize: 8, color: cs.onPrimaryContainer)))
            : const SizedBox(width: 22),
        const SizedBox(width: 2),
        _bubble(context, text, false, bg, onBg, showTail: showTail),
      ],
    );
  }

  // ── Material/Samsung message list (connected bubble groups) ────────────────

  Widget _groupedMessageList(
      BuildContext context, Color sentColor, Color onSentColor, Color receivedColor, Color onReceivedColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Received group
        Align(
          alignment: Alignment.centerLeft,
          child: _bubble(context, "Hey! How are you?", false, receivedColor, onReceivedColor,
              showTail: false, connectLower: true, connectUpper: false),
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: _bubble(context, "Miss you! 😊", false, receivedColor, onReceivedColor,
              showTail: true, connectLower: false, connectUpper: true),
        ),
        const SizedBox(height: 6),
        // Sent group
        Align(
          alignment: Alignment.centerRight,
          child: _bubble(context, "Doing great!", true, sentColor, onSentColor,
              showTail: false, connectLower: true, connectUpper: false),
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: _bubble(context, "Coffee soon? ☕", true, sentColor, onSentColor,
              showTail: true, connectLower: false, connectUpper: true),
        ),
      ],
    );
  }

  // ── Shared bubble widget (shape via TailClipper) ────────────────────────────

  Widget _bubble(BuildContext context, String text, bool isMe, Color bg, Color onBg,
      {required bool showTail, bool connectLower = false, bool connectUpper = false}) {
    return ClipPath(
      clipper: TailClipper(
        isFromMe: isMe,
        showTail: showTail,
        connectLower: connectLower,
        connectUpper: connectUpper,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 155),
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10)
            .add(EdgeInsets.only(left: isMe ? 0 : 10, right: isMe ? 10 : 0)),
        color: bg,
        child: Text(text, style: context.theme.textTheme.labelSmall?.copyWith(color: onBg, fontSize: 10)),
      ),
    );
  }

  // ── Per-skin text field ─────────────────────────────────────────────────────

  Widget _textField(BuildContext context, Skins skin) {
    switch (skin) {
      case Skins.iOS:
        return _iOSTextField(context);
      case Skins.Samsung:
        return _samsungTextField(context);
      case Skins.Material:
        return _materialTextField(context);
    }
  }

  Widget _iOSTextField(BuildContext context) {
    final cs = context.theme.colorScheme;
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, size: 18, color: cs.outline),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25), width: 1),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text("iMessage",
                        style: context.theme.textTheme.labelSmall?.copyWith(color: cs.outline, fontSize: 10)),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                    child: Icon(Icons.arrow_upward_rounded, size: 12, color: cs.onPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialTextField(BuildContext context) {
    final cs = context.theme.colorScheme;
    return Container(
      height: 46,
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, size: 18, color: cs.outline),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text("Message",
                        style: context.theme.textTheme.labelSmall?.copyWith(color: cs.outline, fontSize: 10)),
                  ),
                  Icon(Icons.send_rounded, size: 16, color: cs.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _samsungTextField(BuildContext context) {
    final cs = context.theme.colorScheme;
    return Container(
      height: 46,
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, size: 18, color: cs.outline),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              child:
                  Text("Message", style: context.theme.textTheme.labelSmall?.copyWith(color: cs.outline, fontSize: 10)),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.send_rounded, size: 20, color: cs.primary),
        ],
      ),
    );
  }
}
