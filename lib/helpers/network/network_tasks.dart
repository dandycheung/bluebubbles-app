import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart'
    if (dart.library.html) 'package:bluebubbles/models/html/network_tools.dart';

class NetworkTasks {
  static Future<void>? _configureNetworkToolsFuture;

  static Future<void> onConnect() async {
    if (!SettingsSvc.settings.finishedSetup.value) return;
    Logger.info('[NetworkTasks] Handling onConnect tasks. Finished Setup: ${SettingsSvc.settings.finishedSetup.value}');

    // scan if server is on localhost
    if (!kIsWeb && SettingsSvc.settings.localhostPort.value != null) {
      detectLocalhost();
    }

    if (kIsWeb) {
      if (ChatsSvc.isEmpty) {
        ChatsSvc.reset();
        await ChatsSvc.init();
      }
    }
  }

  static Future<void> detectLocalhost({bool createSnackbar = false}) async {
    if (SettingsSvc.settings.localhostPort.value == null || kIsWeb) {
      HttpSvc.originOverride = null;
      return;
    }

    List<ConnectivityResult> status = await (Connectivity().checkConnectivity());
    if (!status.contains(ConnectivityResult.wifi) && !status.contains(ConnectivityResult.ethernet)) {
      HttpSvc.originOverride = null;
      return;
    }

    final schemes = ['https', 'http'];

    try {
      await HttpSvc.serverInfo().then((response) async {
        List<String> localIpv4s = ((response.data?['data']?['local_ipv4s'] ?? []) as List).cast<String>();
        List<String> localIpv6s = ((response.data?['data']?['local_ipv6s'] ?? []) as List).cast<String>();
        String? address;
        if (SettingsSvc.settings.useLocalIpv6.value) {
          for (String ip in localIpv6s) {
            for (String scheme in schemes) {
              String addr = "$scheme://[$ip]:${SettingsSvc.settings.localhostPort.value!}";
              try {
                Response response = await HttpSvc.ping(customUrl: addr);
                if (response.data.toString().contains("pong")) {
                  address = addr;
                  break;
                }
              } catch (ex) {
                Logger.debug('Failed to connect to localhost addres: $addr');
              }
            }
            if (address != null) break;
          }
        }
        if (address == null) {
          for (String ip in localIpv4s) {
            for (String scheme in schemes) {
              String addr = "$scheme://$ip:${SettingsSvc.settings.localhostPort.value!}";
              try {
                final response = await HttpSvc.ping(customUrl: addr);
                if (response.data.toString().contains("pong")) {
                  address = addr;
                  break;
                }
              } catch (ex) {
                Logger.debug('Failed to connect to localhost addres: $addr');
              }
            }
            if (address != null) break;
          }
        }

        if (address != null) {
          Logger.debug('Localhost Detected. Connected to $address');
          if (createSnackbar) {
            showSnackbar('Localhost Detected', 'Connected to $address');
          }

          HttpSvc.originOverride = address;
        } else {
          HttpSvc.originOverride = null;
        }
      });
    } catch (_) {}

    if (HttpSvc.originOverride != null) return;

    // This was moved from main.dart to here because this is the only place we use it.
    // This will also make an API call to a github file containing a mapping of MAC addresses
    // to vendor information. That info is used to display metadata about an ActiveHost found
    // on the network via a port scan. We don't want that API call to happen on first-boot, nor
    // do we need it to.
    _configureNetworkToolsFuture ??= configureNetworkTools(FilesystemSvc.appDocDir.path, enableDebugging: kDebugMode);

    await _configureNetworkToolsFuture;

    Logger.debug("Falling back to port scanning");
    final wifiIP = await NetworkInfo().getWifiIP();
    if (wifiIP != null) {
      final stream = HostScannerService.instance.scanDevicesForSinglePort(
        wifiIP.substring(0, wifiIP.lastIndexOf('.')),
        int.parse(SettingsSvc.settings.localhostPort.value!),
      );
      Set<ActiveHost> hosts = {};
      stream.listen((host) {
        hosts.add(host);
      }, onDone: () async {
        String? address;
        for (ActiveHost h in hosts) {
          for (String scheme in schemes) {
            String addr = "$scheme://${h.address}:${SettingsSvc.settings.localhostPort.value!}";
            try {
              Response response = await HttpSvc.ping(customUrl: addr);
              if (response.data.toString().contains("pong")) {
                address = addr;
                break;
              }
            } catch (ex) {
              Logger.debug('Failed to connect to localhost addres: $addr');
            }
          }
          if (address != null) break;
        }
        if (address != null) {
          if (createSnackbar) {
            showSnackbar('Localhost Detected', 'Connected to $address');
          }

          HttpSvc.originOverride = address;
        } else {
          HttpSvc.originOverride = null;
        }
      }, onError: (_, __) {
        HttpSvc.originOverride = null;
      });
    } else {
      HttpSvc.originOverride = null;
    }
  }
}
