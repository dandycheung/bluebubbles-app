import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A horizontally-scrollable row of color swatches that lets the user choose
/// one of the 9 Material You variant themes generated from the chat's
/// background image.  Shown twice — once for light mode, once for dark mode.
/// [brightness] determines which half of the generated theme pairs to preview
/// and which [ChatState] field to read/write.
class AdaptiveThemeVariantPicker extends StatelessWidget {
  const AdaptiveThemeVariantPicker({
    super.key,
    required this.chat,
    required this.brightness,
    this.backgroundColor,
  });

  final Chat chat;

  /// Whether this picker controls the light or dark mode variant.
  final Brightness brightness;

  final Color? backgroundColor;

  static const Map<MaterialYouVariant, String> _displayNames = {
    MaterialYouVariant.base: 'Default',
    MaterialYouVariant.vibrant: 'Vibrant',
    MaterialYouVariant.expressive: 'Expressive',
    MaterialYouVariant.soft: 'Soft',
    MaterialYouVariant.neutral: 'Neutral',
    MaterialYouVariant.lagoon: 'Style 1',
    MaterialYouVariant.sunset: 'Style 2',
    MaterialYouVariant.neonPop: 'Style 3',
    MaterialYouVariant.earthy: 'Style 4',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chatState = ChatsSvc.getChatState(chat.guid);
      final themes = chatState?.adaptiveThemes.value;
      final isLight = brightness == Brightness.light;
      final selectedVariant =
          isLight ? chatState?.adaptiveThemeVariantLight.value : chatState?.adaptiveThemeVariantDark.value;
      return Container(
        height: 130,
        color: backgroundColor,
        child: themes == null
            ? const Center(child: CircularProgressIndicator.adaptive())
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: MaterialYouVariant.values.length,
                itemBuilder: (context, index) {
                  final variant = MaterialYouVariant.values[index];
                  final pair = themes[variant]!;
                  final themeData = isLight ? pair.light : pair.dark;
                  final isSelected = variant.name == selectedVariant;

                  return _VariantPreviewCard(
                    variant: variant,
                    label: _displayNames[variant] ?? variant.name,
                    themeData: themeData,
                    isSelected: isSelected,
                    onTap: () => isLight
                        ? ChatsSvc.setAdaptiveThemeVariantLight(chat, variant.name)
                        : ChatsSvc.setAdaptiveThemeVariantDark(chat, variant.name),
                  );
                },
              ),
      );
    });
  }
}

class _VariantPreviewCard extends StatelessWidget {
  const _VariantPreviewCard({
    required this.variant,
    required this.label,
    required this.themeData,
    required this.isSelected,
    required this.onTap,
  });

  final MaterialYouVariant variant;
  final String label;
  final ThemeData themeData;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = themeData.colorScheme;
    final bubbleColors = themeData.extensions[BubbleColors] as BubbleColors?;
    final sentColor = bubbleColors?.iMessageBubbleColor ?? cs.iMessageBubble;
    final onSentColor = bubbleColors?.oniMessageBubbleColor ?? cs.oniMessageBubble;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Content clipped to rounded rect
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 80,
                      height: 88,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Messages area
                          Expanded(
                            child: Container(
                              color: cs.surface,
                              padding: const EdgeInsets.fromLTRB(6, 5, 6, 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _miniBubble('Hey! 👋', false, cs),
                                  const SizedBox(height: 3),
                                  _miniBubble('Hi there!', true, cs),
                                  const SizedBox(height: 3),
                                  _miniBubble('How are you?', false, cs),
                                ],
                              ),
                            ),
                          ),
                          // Text field
                          Container(
                            height: 18,
                            color: cs.surface,
                            padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35), width: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.fromLTRB(5, 0, 3, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'iMessage',
                                      style: TextStyle(color: cs.outline.withValues(alpha: 0.6), fontSize: 5),
                                    ),
                                  ),
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(color: sentColor, shape: BoxShape.circle),
                                    child: Icon(Icons.arrow_upward_rounded, size: 6, color: onSentColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Border + shadow overlay painted on top of content so it's fully visible
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 80,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? sentColor : cs.outlineVariant.withValues(alpha: 0.5),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                  ),
                  // Selection checkmark badge
                  if (isSelected)
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: sentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.theme.colorScheme.surface, width: 1.5),
                        ),
                        child: Icon(Icons.check_rounded, size: 11, color: onSentColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: context.theme.textTheme.labelSmall!.copyWith(
                  color: isSelected ? context.theme.colorScheme.onSurface : context.theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBubble(String text, bool isMe, ColorScheme cs) {
    final bubbleColors = themeData.extensions[BubbleColors] as BubbleColors?;
    // Mirror conversation_view: use explicit BubbleColors values first (set by
    // materialYouTheme to `primary` / `surfaceVariant`), then fall back to
    // the computed colorfulness-based getters.
    final bg = isMe
        ? (bubbleColors?.iMessageBubbleColor ?? cs.iMessageBubble)
        : (bubbleColors?.receivedBubbleColor ?? cs.surfaceContainerHighest);
    final textColor = isMe
        ? (bubbleColors?.oniMessageBubbleColor ?? cs.oniMessageBubble)
        : (bubbleColors?.onReceivedBubbleColor ?? cs.onSurfaceVariant);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: Radius.circular(isMe ? 8 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 8),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor, fontSize: 5.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
