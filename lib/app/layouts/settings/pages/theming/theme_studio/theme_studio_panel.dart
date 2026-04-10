import 'dart:convert';

import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/color_editor_section.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/preset_theme_strip.dart'
    show ThemeSelectorSection;
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/theme_management_section.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/theme_preview_card.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/widgets/typography_editor.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ─── Controller ───────────────────────────────────────────────────────────────

class ThemeStudioController extends StatefulController {
  late ThemeStruct lightTheme;
  late ThemeStruct darkTheme;
  final RxBool isDark = false.obs;
  final RxList<ThemeStruct> allThemes = <ThemeStruct>[].obs;

  /// Bumped whenever state changes so that Obx() widgets rebuild.
  final RxInt version = 0.obs;

  ThemeStruct get activeTheme => isDark.value ? darkTheme : lightTheme;

  bool get isEditable => !activeTheme.isPreset && SettingsSvc.settings.monetTheming.value == Monet.none;

  void init(bool isDarkMode) {
    isDark.value = isDarkMode;
    _reload();
  }

  void _reload() {
    lightTheme = ThemeStruct.getLightTheme();
    darkTheme = ThemeStruct.getDarkTheme();
    allThemes.value = ThemeStruct.getThemes();
    version.value++;
  }

  void bump() => version.value++;

  // ── Theme selection ────────────────────────────────────────────────────────

  Future<void> applyTheme(BuildContext context, ThemeStruct struct) async {
    final isThemeDark = struct.data.colorScheme.brightness == Brightness.dark;
    isDark.value = isThemeDark;
    struct.save();
    if (isThemeDark) {
      darkTheme = struct;
      await ThemeSvc.changeTheme(context, dark: struct);
    } else {
      lightTheme = struct;
      await ThemeSvc.changeTheme(context, light: struct);
    }
    _reload();
    EventDispatcherSvc.emit('theme-update', null);
  }

  // ── Color editing ──────────────────────────────────────────────────────────

  Future<void> updateColorKey(BuildContext context, String colorKey, Color newColor) async {
    if (!isEditable) return;
    final map = activeTheme.toMap();
    map["data"]["colorScheme"][colorKey] = newColor.toARGB32();
    activeTheme.data = ThemeStruct.fromMap(map).data;
    activeTheme.save();
    if (isDark.value) {
      await ThemeSvc.changeTheme(context, dark: activeTheme);
    } else {
      await ThemeSvc.changeTheme(context, light: activeTheme);
    }
    version.value++;
    EventDispatcherSvc.emit('theme-update', null);
  }

  // ── Typography ─────────────────────────────────────────────────────────────

  Future<void> updateFont(BuildContext context, String fontName) async {
    final map = activeTheme.toMap();
    map["data"]["textTheme"]["font"] = fontName;
    activeTheme.googleFont = fontName;
    activeTheme.data = ThemeStruct.fromMap(map).data;
    activeTheme.save();
    if (isDark.value) {
      await ThemeSvc.changeTheme(context, dark: activeTheme);
    } else {
      await ThemeSvc.changeTheme(context, light: activeTheme);
    }
    version.value++;
    EventDispatcherSvc.emit('theme-update', null);
  }

  Future<void> updateTextSize(BuildContext context, String key, double multiplier, {bool save = false}) async {
    final map = activeTheme.toMap();
    final keys = key == 'master' ? activeTheme.textSizes.keys.toList() : [key];
    for (final k in keys) {
      map["data"]["textTheme"][k]['fontSize'] = ThemeStruct.defaultTextSizes[k]! * multiplier;
    }
    activeTheme.data = ThemeStruct.fromMap(map).data;
    if (save) {
      activeTheme.save();
      if (isDark.value) {
        await ThemeSvc.changeTheme(context, dark: activeTheme);
      } else {
        await ThemeSvc.changeTheme(context, light: activeTheme);
      }
      version.value++;
      EventDispatcherSvc.emit('theme-update', null);
    }
  }

  // ── Theme management ───────────────────────────────────────────────────────

  Future<ThemeStruct> createTheme(BuildContext context, String name, {bool? forDark}) async {
    final darkMode = forDark ?? isDark.value;
    isDark.value = darkMode;
    final tuple = ThemeSvc.getStructsFromData(activeTheme.data, activeTheme.data);
    final newData = darkMode ? tuple.dark : tuple.light;
    final newTheme = ThemeStruct(name: name, themeData: newData);
    newTheme.save();
    if (darkMode) {
      darkTheme = newTheme;
      await ThemeSvc.changeTheme(context, dark: newTheme);
    } else {
      lightTheme = newTheme;
      await ThemeSvc.changeTheme(context, light: newTheme);
    }
    _reload();
    EventDispatcherSvc.emit('theme-update', null);
    return newTheme;
  }

  Future<bool> renameTheme(BuildContext context, String newName) async {
    if (activeTheme.isPreset || newName.isEmpty) return false;
    if (ThemeStruct.findOne(newName) != null) return false;
    final oldName = activeTheme.name;
    activeTheme.name = newName;
    activeTheme.save();
    if (PrefsSvc.i.getString("selected-light") == oldName) {
      await PrefsSvc.i.setString("selected-light", newName);
    }
    if (PrefsSvc.i.getString("selected-dark") == oldName) {
      await PrefsSvc.i.setString("selected-dark", newName);
    }
    _reload();
    EventDispatcherSvc.emit('theme-update', null);
    return true;
  }

  Future<void> generateFromSeed(BuildContext context, Color seed) async {
    if (!isEditable) return;
    final brightness = isDark.value ? Brightness.dark : Brightness.light;
    final swatch = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    activeTheme.data = activeTheme.data.copyWith(colorScheme: swatch);
    activeTheme.save();
    if (isDark.value) {
      await ThemeSvc.changeTheme(context, dark: activeTheme);
    } else {
      await ThemeSvc.changeTheme(context, light: activeTheme);
    }
    version.value++;
    EventDispatcherSvc.emit('theme-update', null);
  }

  Future<void> generateFromImage(BuildContext context) async {
    if (!isEditable) return;
    final res = await FilePicker.platform
        .pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final image = MemoryImage(res.files.first.bytes!);
    final swatch = await ColorScheme.fromImageProvider(
        provider: image, brightness: isDark.value ? Brightness.dark : Brightness.light);
    activeTheme.data = activeTheme.data.copyWith(colorScheme: swatch);
    activeTheme.save();
    if (isDark.value) {
      await ThemeSvc.changeTheme(context, dark: activeTheme);
    } else {
      await ThemeSvc.changeTheme(context, light: activeTheme);
    }
    version.value++;
    EventDispatcherSvc.emit('theme-update', null);
  }

  Future<void> resetToDefault(BuildContext context) async {
    if (activeTheme.isPreset) return;
    final defaultTheme = isDark.value
        ? ThemesService.defaultThemes.firstWhere((e) => e.name == "OLED Dark")
        : ThemesService.defaultThemes.firstWhere((e) => e.name == "Bright White");
    activeTheme.data = defaultTheme.data;
    activeTheme.save();
    if (isDark.value) {
      await ThemeSvc.changeTheme(context, dark: activeTheme);
    } else {
      await ThemeSvc.changeTheme(context, light: activeTheme);
    }
    version.value++;
    EventDispatcherSvc.emit('theme-update', null);
  }

  Future<void> deleteTheme(BuildContext context) async {
    if (activeTheme.isPreset) return;
    activeTheme.delete();
    if (isDark.value) {
      darkTheme = await ThemeSvc.revertToPreviousDarkTheme();
      await ThemeSvc.changeTheme(context, dark: darkTheme);
    } else {
      lightTheme = await ThemeSvc.revertToPreviousLightTheme();
      await ThemeSvc.changeTheme(context, light: lightTheme);
    }
    _reload();
    EventDispatcherSvc.emit('theme-update', null);
  }

  String exportThemeJson() {
    return const JsonEncoder.withIndent('  ').convert(activeTheme.toMap());
  }

  Future<ThemeStruct?> importThemeFromJson(String json) async {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      // Remove source device's ROWID so ObjectBox assigns a new one
      map["ROWID"] = null;
      final imported = ThemeStruct.fromMap(map);
      // Resolve name conflict with auto-suffix
      String name = imported.name;
      int suffix = 2;
      while (ThemeStruct.findOne(name) != null) {
        name = "${imported.name} ($suffix)";
        suffix++;
      }
      final finalTheme = ThemeStruct(
        name: name,
        themeData: imported.data,
        gradientBg: imported.gradientBg,
        googleFont: imported.googleFont,
      );
      finalTheme.save();
      _reload();
      return finalTheme;
    } catch (_) {
      return null;
    }
  }
}

// ─── Panel ────────────────────────────────────────────────────────────────────

class ThemeStudioPanel extends CustomStateful<ThemeStudioController> {
  ThemeStudioPanel({super.key}) : super(parentController: Get.put(ThemeStudioController()));

  @override
  State<StatefulWidget> createState() => _ThemeStudioPanelState();
}

class _ThemeStudioPanelState extends CustomState<ThemeStudioPanel, void, ThemeStudioController> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      controller.init(ThemeSvc.inDarkMode(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Theme Studio",
      initialHeader: null,
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        // Live preview
        SliverToBoxAdapter(
          child: Obx(() {
            controller.version.value;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.theme.colorScheme.outline.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: ThemePreviewCard(struct: controller.activeTheme),
              ),
            );
          }),
        ),

        // Themes
        SliverToBoxAdapter(child: _sectionHeader(context, "Themes")),
        SliverToBoxAdapter(
          child: Obx(() {
            controller.version.value;
            return ThemeSelectorSection(controller: controller);
          }),
        ),

        // Colors
        SliverToBoxAdapter(child: _sectionHeader(context, "Colors")),
        SliverToBoxAdapter(
          child: Obx(() {
            controller.version.value;
            if (!controller.isEditable) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: context.theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "To customize the app colors, create a new theme.",
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            controller.version.value;
            return _ColorEditorBody(controller: controller);
          }),
        ),

        // Typography
        SliverToBoxAdapter(child: _sectionHeader(context, "Typography")),
        SliverToBoxAdapter(
          child: Obx(() {
            controller.version.value;
            return TypographyEditor(controller: controller);
          }),
        ),

        // Manage
        SliverToBoxAdapter(child: _sectionHeader(context, "Manage Theme")),
        SliverToBoxAdapter(
          child: Obx(() {
            controller.version.value;
            return ThemeManagementSection(controller: controller);
          }),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6, left: 20, right: 20),
      child: Text(
        text.toUpperCase(),
        style: context.theme.textTheme.bodySmall?.copyWith(
          color: context.theme.colorScheme.outline,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Color editor body ────────────────────────────────────────────────────────

class _ColorEditorBody extends StatelessWidget {
  const _ColorEditorBody({required this.controller});
  final ThemeStudioController controller;

  static const _groups = [
    ColorGroup(
      title: "Brand",
      icon: Icons.palette_outlined,
      pairs: [
        ColorPair("primary", "onPrimary"),
        ColorPair("primaryContainer", "onPrimaryContainer"),
        ColorPair("secondary", "onSecondary"),
        ColorPair("tertiaryContainer", "onTertiaryContainer"),
      ],
    ),
    ColorGroup(
      title: "Surfaces & Backgrounds",
      icon: Icons.layers_outlined,
      pairs: [
        ColorPair("background", "onBackground"),
        ColorPair("surface", "onSurface"),
        ColorPair("surfaceVariant", "onSurfaceVariant"),
        ColorPair("inverseSurface", "onInverseSurface"),
      ],
    ),
    ColorGroup(
      title: "Chat Bubbles",
      icon: Icons.chat_bubble_outline,
      pairs: [
        ColorPair("smsBubble", "onSmsBubble"),
      ],
    ),
    ColorGroup(
      title: "Semantic",
      icon: Icons.warning_amber_outlined,
      pairs: [
        ColorPair("error", "onError"),
        ColorPair("errorContainer", "onErrorContainer"),
      ],
    ),
    ColorGroup(
      title: "Borders & Outlines",
      icon: Icons.border_outer_outlined,
      pairs: [
        ColorPair("outline", null),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = controller.activeTheme.colors(controller.isDark.value, returnMaterialYou: false);
    final editable = controller.isEditable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _groups
            .map((group) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ColorEditorSection(
                    group: group,
                    colors: colors,
                    editable: editable,
                    controller: controller,
                  ),
                ))
            .toList(),
      ),
    );
  }
}
