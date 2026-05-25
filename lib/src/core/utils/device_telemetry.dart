import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

/// Recolecta metadatos del dispositivo para telemetría de login.
/// Falla silenciosamente — si hay cualquier error, retorna nulos.
Future<({String? platform, String? deviceModel, String? appVersion})>
    buildLoginTelemetry() async {
  try {
    final pkg = await PackageInfo.fromPlatform();
    final appVersion = pkg.version;

    if (kIsWeb) {
      return (platform: 'web', deviceModel: null, appVersion: appVersion);
    }

    String? platform;
    String? deviceModel;

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      platform = 'android';
      deviceModel = '${info.brand} ${info.model}'.trim();
    } else if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      platform = 'ios';
      deviceModel = info.utsname.machine;
    }

    return (platform: platform, deviceModel: deviceModel, appVersion: appVersion);
  } catch (_) {
    return (platform: null, deviceModel: null, appVersion: null);
  }
}
