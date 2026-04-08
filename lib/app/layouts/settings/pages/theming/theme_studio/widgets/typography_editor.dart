import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/theme_studio_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font-family selector + master + per-style size sliders.
class TypographyEditor extends StatefulWidget {
  const TypographyEditor({super.key, required this.controller});

  final ThemeStudioController controller;

  @override
  State<TypographyEditor> createState() => _TypographyEditorState();
}

class _TypographyEditorState extends State<TypographyEditor> {
  bool _sizesExpanded = false;
  int _masterResetKey = 0;
  int _styleResetKey = 0;

  ThemeStudioController get ctrl => widget.controller;

  void _resetMaster(BuildContext context) {
    ctrl.updateTextSize(context, 'master', 1.0, save: true);
    setState(() => _masterResetKey++);
  }

  void _resetAllSizes(BuildContext context) {
    ctrl.updateTextSize(context, 'master', 1.0, save: true);
    setState(() {
      _masterResetKey++;
      _styleResetKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ctrl.activeTheme;
    final editable = ctrl.isEditable;
    final tileColor = context.tileColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Font selector ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: tileColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IgnorePointer(
                    ignoring: !editable,
                    child: Opacity(
                      opacity: editable ? 1.0 : 0.5,
                      child: SettingsOptions<String>(
                        title: "Font Family",
                        initial: theme.googleFont,
                        clampWidth: false,
                        options: ['Default', ...GoogleFonts.asMap().keys],
                        textProcessing: (s) => s,
                        secondaryColor: context.headerColor,
                        useCupertino: false,
                        materialCustomWidgets: (font) {
                          if (font == 'Default') return null;
                          try {
                            return Text(font,
                                style: GoogleFonts.getFont(font, fontSize: 14));
                          } catch (_) {
                            return null;
                          }
                        },
                        onChanged: (value) {
                          if (!editable || value == null) return;
                          ctrl.updateFont(context, value);
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                    child: _FontPreviewBanner(activeTheme: theme),
                  ),
                  SettingsSubtitle(
                    subtitle: editable
                        ? "Fonts are downloaded on selection. Visit fonts.google.com to preview them."
                        : "Select a custom theme above to change the font.",
                    unlimitedSpace: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Master scale slider ────────────────────────────────────────────
          if (editable) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: tileColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MasterSlider(key: ValueKey(_masterResetKey), controller: ctrl),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: TextButton.icon(
                          onPressed: () => _resetMaster(context),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: context.theme.colorScheme.onSurfaceVariant,
                          ),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text("Reset", style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Per-style sliders (collapsible) ──────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: tileColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _sizesExpanded = !_sizesExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.format_size,
                                size: 20, color: context.theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text("Individual Sizes",
                                  style: context.theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            TextButton.icon(
                              onPressed: () => _resetAllSizes(context),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: context.theme.colorScheme.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text("Reset All", style: TextStyle(fontSize: 12)),
                            ),
                            AnimatedRotation(
                              turns: _sizesExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(Icons.expand_more,
                                  color: context.theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _sizesExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        children: theme.textSizes.keys.map((key) {
                          return _StyleSlider(
                            key: ValueKey('$key-$_styleResetKey'),
                            styleKey: key,
                            controller: ctrl,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Font preview banner ───────────────────────────────────────────────────────

class _FontPreviewBanner extends StatelessWidget {
  const _FontPreviewBanner({required this.activeTheme});
  final ThemeStruct activeTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "The quick brown fox jumps over the lazy dog. 0123456789",
        style: activeTheme.data.textTheme.bodyMedium,
      ),
    );
  }
}

// ─── Master slider ─────────────────────────────────────────────────────────────

class _MasterSlider extends StatefulWidget {
  const _MasterSlider({super.key, required this.controller});
  final ThemeStudioController controller;

  @override
  State<_MasterSlider> createState() => _MasterSliderState();
}

class _MasterSliderState extends State<_MasterSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    // Infer current master scale from the bodyMedium ratio
    final sizes = widget.controller.activeTheme.textSizes;
    final defaults = ThemeStruct.defaultTextSizes;
    final def = defaults['bodyMedium']!;
    _value = (sizes['bodyMedium'] ?? def) / def;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSlider(
      leading: const Text("master"),
      leadingMinWidth: 80,
      startingVal: _value,
      min: 0.5,
      max: 3.0,
      divisions: 30,
      backgroundColor: context.tileColor,
      formatValue: (v) => '${v.toStringAsFixed(2)}×',
      update: (v) {
        setState(() => _value = v);
        widget.controller.updateTextSize(context, 'master', v);
      },
      onChangeEnd: (v) {
        setState(() => _value = v);
        widget.controller.updateTextSize(context, 'master', v, save: true);
      },
    );
  }
}

// ─── Per-style slider ──────────────────────────────────────────────────────────

class _StyleSlider extends StatefulWidget {
  const _StyleSlider({super.key, required this.styleKey, required this.controller});
  final String styleKey;
  final ThemeStudioController controller;

  @override
  State<_StyleSlider> createState() => _StyleSliderState();
}

class _StyleSliderState extends State<_StyleSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = _currentMultiplier();
  }

  double _currentMultiplier() {
    final current = widget.controller.activeTheme.textSizes[widget.styleKey] ?? 14;
    final def = ThemeStruct.defaultTextSizes[widget.styleKey] ?? 14;
    return current / def;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSlider(
      leading: Text(widget.styleKey),
      leadingMinWidth: 80,
      startingVal: _value,
      min: 0.5,
      max: 3.0,
      divisions: 30,
      backgroundColor: context.tileColor,
      formatValue: (v) => '${v.toStringAsFixed(2)}×',
      update: (v) {
        setState(() => _value = v);
        widget.controller.updateTextSize(context, widget.styleKey, v);
      },
      onChangeEnd: (v) {
        setState(() => _value = v);
        widget.controller.updateTextSize(context, widget.styleKey, v, save: true);
      },
    );
  }
}
