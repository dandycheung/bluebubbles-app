import 'package:bluebubbles/helpers/ui/system_ui_overlay_style_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _lightSurface = Color(0xFFF6F7F8);
const Color _darkSurface = Color(0xFF101214);
const Color _overrideSurface = Color(0xFF4B5563);
const Color _overrideStatus = Color(0xFFE5E7EB);

void main() {
  test('uses surface color for navigation bar by default', () {
    final style = _style(surfaceColor: _lightSurface);

    expect(style.systemNavigationBarColor, _lightSurface);
  });

  test('leaves navigation divider color unset outside immersive mode', () {
    final style = _style();

    expect(style.systemNavigationBarDividerColor, isNull);
  });

  test('leaves navigation contrast enforcement unset outside immersive mode', () {
    final style = _style();

    expect(style.systemNavigationBarContrastEnforced, isNull);
  });

  test('uses transparent status bar by default', () {
    final style = _style();

    expect(style.statusBarColor, Colors.transparent);
  });

  test('disables status bar contrast enforcement', () {
    final style = _style();

    expect(style.systemStatusBarContrastEnforced, isFalse);
  });

  test('uses dark navigation icons on a light surface', () {
    final style = _style(surfaceColor: _lightSurface);

    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
  });

  test('uses dark status icons on a light surface', () {
    final style = _style(surfaceColor: _lightSurface);

    expect(style.statusBarIconBrightness, Brightness.dark);
  });

  test('uses light navigation icons on a dark surface', () {
    final style = _style(surfaceColor: _darkSurface);

    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });

  test('uses light status icons on a dark surface', () {
    final style = _style(surfaceColor: _darkSurface);

    expect(style.statusBarIconBrightness, Brightness.light);
  });

  test('sets status brightness from the surface brightness', () {
    final style = _style(surfaceColor: _darkSurface);

    expect(style.statusBarBrightness, Brightness.dark);
  });

  test('makes immersive navigation bar transparent', () {
    final style = _style(immersiveMode: true);

    expect(style.systemNavigationBarColor, Colors.transparent);
  });

  test('makes immersive navigation divider transparent', () {
    final style = _style(immersiveMode: true);

    expect(style.systemNavigationBarDividerColor, Colors.transparent);
  });

  test('disables immersive navigation contrast enforcement', () {
    final style = _style(immersiveMode: true);

    expect(style.systemNavigationBarContrastEnforced, isFalse);
  });

  test('uses explicit navigation bar color outside immersive mode', () {
    final style = _style(systemNavigationBarColor: _overrideSurface);

    expect(style.systemNavigationBarColor, _overrideSurface);
  });

  test('immersive mode ignores explicit navigation bar color', () {
    final style = _style(
      immersiveMode: true,
      systemNavigationBarColor: _overrideSurface,
    );

    expect(style.systemNavigationBarColor, Colors.transparent);
  });

  test('uses explicit status bar color', () {
    final style = _style(statusBarColor: _overrideStatus);

    expect(style.statusBarColor, _overrideStatus);
  });

  test('uses explicit background brightness', () {
    final style = _style(backgroundBrightness: Brightness.dark);

    expect(style.statusBarBrightness, Brightness.dark);
  });

  test('uses explicit navigation icon brightness', () {
    final style = _style(systemNavigationBarIconBrightness: Brightness.light);

    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });

  test('uses explicit status icon brightness', () {
    final style = _style(statusBarIconBrightness: Brightness.light);

    expect(style.statusBarIconBrightness, Brightness.light);
  });
}

SystemUiOverlayStyle _style({
  Color surfaceColor = _lightSurface,
  bool immersiveMode = false,
  Color? systemNavigationBarColor,
  Color statusBarColor = Colors.transparent,
  Brightness? backgroundBrightness,
  Brightness? systemNavigationBarIconBrightness,
  Brightness? statusBarIconBrightness,
}) {
  return buildSystemUiOverlayStyle(
    surfaceColor: surfaceColor,
    immersiveMode: immersiveMode,
    systemNavigationBarColor: systemNavigationBarColor,
    statusBarColor: statusBarColor,
    backgroundBrightness: backgroundBrightness,
    systemNavigationBarIconBrightness: systemNavigationBarIconBrightness,
    statusBarIconBrightness: statusBarIconBrightness,
  );
}
