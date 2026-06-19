# windows/ — Windows Native

## C++ Runner (`runner/`)
- `main.cpp` — entry point: COM init, `DartProject` setup, 1280×720 `FlutterWindow`, Win32 message loop
- `flutter_window.cpp/h` — `FlutterViewController` host; plugin registration on `OnCreate`
- `win32_window.cpp/h` — Win32 window base class (creation, message routing)
- `utils.cpp/h` — UTF-8 / UTF-16 helpers

## Installer
- `build.ps1` — release build script: cleans Release dir, builds two MSIX variants, then compiles the installer (mirrors `linux/build.sh`)
  - `--store` build → `bluebubbles-store.msix` (MS Store; Microsoft signs it; store identity/publisher from `pubspec.yaml`)
  - sideload build → `bluebubbles.msix` (directly distributed; unsigned, SignPath signs it in CI). Only built when `SIGNED_MSIX_PUBLISHER` env is set; that value must equal the SignPath cert's subject DN.
  - `store:` is deliberately absent from `pubspec.yaml` (msix forces store mode if present and can't be overridden via CLI); pass `--store` for the store build instead.
- `bluebubbles_installer_script.iss` — Inno Setup installer definition
- `CodeDependencies.iss` — installer dependency declarations
- SignPath code signing is wired in `.github/workflows/desktop-builds.yml` (installer + msix, on tags or manual `sign=true`)

## Key Flutter-Side Files for Windows
- `lib/utils/window_effects.dart` — Mica/acrylic transparency (`flutter_acrylic`)
- `lib/app/wrappers/titlebar_wrapper.dart` — custom window frame (`bitsdojo_window`)
- `lib/services/ui/navigator/navigator_service.dart` — Windows taskbar integration (`windows_taskbar`)
- `lib/services/backend/sync/full_sync_manager.dart` — taskbar progress bar during sync

## Build
Target: x64. Binary: `bluebubbles_app.exe`. CMake build system.
MSIX identity: `23344BlueBubbles.BlueBubbles`
