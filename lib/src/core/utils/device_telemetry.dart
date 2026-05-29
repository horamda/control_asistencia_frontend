import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

/// Recolecta metadatos del dispositivo para telemetría de login.
/// Falla silenciosamente — si hay cualquier error, retorna nulos.
Future<({String? platform, String? deviceModel, String? appVersion})>
buildLoginTelemetry({Duration timeout = const Duration(seconds: 2)}) async {
  try {
    final pkg = await PackageInfo.fromPlatform().timeout(timeout);
    final appVersion = pkg.version;

    if (kIsWeb) {
      return (platform: 'web', deviceModel: null, appVersion: appVersion);
    }

    String? platform;
    String? deviceModel;

    if (Platform.isAndroid) {
      platform = 'android';
      try {
        final info = await DeviceInfoPlugin().androidInfo.timeout(timeout);
        deviceModel = '${info.brand} ${info.model}'.trim();
      } catch (_) {
        deviceModel = null;
      }
    } else if (Platform.isIOS) {
      platform = 'ios';
      try {
        final info = await DeviceInfoPlugin().iosInfo.timeout(timeout);
        deviceModel = info.utsname.machine;
      } catch (_) {
        deviceModel = null;
      }
    }

    return (
      platform: platform,
      deviceModel: deviceModel,
      appVersion: appVersion,
    );
  } catch (_) {
    return (platform: null, deviceModel: null, appVersion: null);
  }
}
