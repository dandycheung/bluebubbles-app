import 'package:bluebubbles/database/models.dart';
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
        height: 96,
        color: backgroundColor,
        child: themes == null
            ? const Center(child: CircularProgressIndicator.adaptive())
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: MaterialYouVariant.values.length,
                itemBuilder: (context, index) {
                  final variant = MaterialYouVariant.values[index];
                  final pair = themes[variant]!;
                  final themeData = isLight ? pair.light : pair.dark;
                  final isSelected = variant.name == selectedVariant;

                  return _VariantSwatch(
                    variant: variant,
                    label: _displayNames[variant] ?? variant.name,
                    primaryColor: themeData.colorScheme.primary,
                    secondaryColor: themeData.colorScheme.secondary,
                    surfaceColor: themeData.colorScheme.surface,
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

class _VariantSwatch extends StatelessWidget {
  const _VariantSwatch({
    required this.variant,
    required this.label,
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    required this.isSelected,
    required this.onTap,
  });

  final MaterialYouVariant variant;
  final String label;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: context.theme.colorScheme.onSurface, width: 2.5)
                      : Border.all(color: Colors.transparent, width: 2.5),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    // Secondary color accent dot in bottom-right
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: surfaceColor.withValues(alpha: 0.6), width: 1),
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Positioned(
                        left: 4,
                        top: 4,
                        child: Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
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
}
