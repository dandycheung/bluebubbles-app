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

  ThemeStudioController get ctrl => widget.controller;

  void _resetAllSizes(BuildContext context) {
    ctrl.updateTextSize(context, 'master', 1.0);
  }

  double _multiplierFor(String key) {
    final sizes = ctrl.activeTheme.textSizes;
    final def = ThemeStruct.defaultTextSizes[key]!;
    return (sizes[key] ?? def) / def;
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

          // ── Master + individual size presets ───────────────────────────────
          if (editable) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: tileColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SizePresetRow(
                      label: 'master',
                      currentMultiplier: _multiplierFor('bodyMedium'),
                      onChanged: (v) => ctrl.updateTextSize(context, 'master', v),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: TextButton.icon(
                          onPressed: () => _resetAllSizes(context),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: context.theme.colorScheme.onSurfaceVariant,
                          ),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text("Reset All", style: TextStyle(fontSize: 12)),
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
                            Icon(Icons.format_size, size: 20, color: context.theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text("Individual Sizes",
                                  style: context.theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            AnimatedRotation(
                              turns: _sizesExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(Icons.expand_more, color: context.theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _sizesExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        children: theme.textSizes.keys.map((key) {
                          return _SizePresetRow(
                            label: key,
                            currentMultiplier: _multiplierFor(key),
                            onChanged: (v) => ctrl.updateTextSize(context, key, v),
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
        style: activeTheme.data.textTheme.bodyMedium?.copyWith(
          color: context.theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ─── Size preset row ──────────────────────────────────────────────────────────

class _SizePresetRow extends StatelessWidget {
  const _SizePresetRow({
    required this.label,
    required this.currentMultiplier,
    required this.onChanged,
  });

  final String label;
  final double currentMultiplier;
  final ValueChanged<double> onChanged;

  static const Map<String, double> _presets = {
    'Small': 0.85,
    'Normal': 1.0,
    'Large': 1.15,
    'XL': 1.30,
  };

  String get _selected {
    for (final entry in _presets.entries) {
      if ((currentMultiplier - entry.value).abs() < 0.02) return entry.key;
    }
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: context.theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: SegmentedButton<String>(
              segments: _presets.keys
                  .map((k) => ButtonSegment<String>(value: k, label: Text(k)))
                  .toList(),
              selected: {selected},
              onSelectionChanged: (s) => onChanged(_presets[s.first]!),
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12),
              ),
              showSelectedIcon: false,
            ),
          ),
        ],
      ),
    );
  }
}

// (removed _StyleSlider — replaced by _SizePresetRow above)
