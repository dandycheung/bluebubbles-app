import 'package:bluebubbles/helpers/types/helpers/misc_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart' as las;
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

class LaunchAtStartup {
  static Future<bool> enable() => las.LaunchAtStartup.instance.enable();

  static Future<bool> disable() => las.LaunchAtStartup.instance.disable();

  /// Where the current platform's startup entry lives — matches what the package's enable() creates.
  static String? get shortcutPath {
    final appName = FilesystemSvc.packageInfo.appName;
    if (Platform.isWindows) {
      if (isMsix) {
        return p.join(Platform.environment['APPDATA']!, 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup',
            '$appName.lnk');
      }
      return 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\$appName';
    } else if (Platform.isLinux) {
      return p.join(Platform.environment['HOME']!, '.config', 'autostart', '$appName.desktop');
    }
    return null;
  }

  /// Reveals the startup entry: selects the file in Explorer, opens regedit at the Run key, or
  /// opens the autostart folder on Linux.
  static Future<void> revealShortcut() async {
    final path = shortcutPath;
    if (path == null) return;
    if (Platform.isWindows && !isMsix) {
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit',
        '/v',
        'LastKey',
        '/d',
        r'Computer\HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run',
        '/f'
      ]);
      // regedit requires elevation; 'start' uses ShellExecute so the UAC prompt appears
      await Process.start('cmd', ['/c', 'start', '', 'regedit']);
    } else if (Platform.isWindows) {
      await Process.start('explorer', ['/select,$path']);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [p.dirname(path)]);
    }
  }

  static void setup(String appName, bool minimized) {
    String appPath;
    String? packageName;
    if (isMsix) {
      final segments = p.split(Platform.resolvedExecutable);
      final parts = segments[segments.indexOf('WindowsApps') + 1].split('_');
      final familyName = '${parts.first}_${parts.last}';
      packageName = parts.first;
      appPath = 'shell:AppsFolder\\$familyName!bluebubbles';
    } else if (isFlatpak) {
      appPath = 'flatpak run app.bluebubbles.BlueBubbles';
    } else {
      appPath = Platform.resolvedExecutable;
    }
    las.LaunchAtStartup.instance.setup(
      appName: appName,
      appPath: appPath,
      packageName: packageName,
      args: minimized ? ['minimized'] : [],
    );
  }
}
