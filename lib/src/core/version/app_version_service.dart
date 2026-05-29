import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../src/config/app_config.dart';

enum AppVersionStatus {
  upToDate,
  updateRecommended,
  updateRequired,
}

class AppVersionCheckResult {
  const AppVersionCheckResult({
    required this.status,
    required this.currentVersion,
    required this.versionMinima,
    required this.versionRecomendada,
    this.urlDescarga,
    this.mensaje,
  });

  final AppVersionStatus status;
  final String currentVersion;
  final String versionMinima;
  final String versionRecomendada;
  final String? urlDescarga;
  final String? mensaje;

  bool get requiresUpdate => status == AppVersionStatus.updateRequired;
  bool get recommendsUpdate => status == AppVersionStatus.updateRecommended;
}

class AppVersionService {
  static const _platformInfoTimeout = Duration(seconds: 2);

  static Future<AppVersionCheckResult?> check() async {
    try {
      final info = await PackageInfo.fromPlatform().timeout(
        _platformInfoTimeout,
      );
      final currentVersion = info.version; // e.g. "1.2.3"

      final platform = kIsWeb ? 'android' : (Platform.isIOS ? 'ios' : 'android');
      final cfg = AppConfig.current;
      final uri = Uri.parse(
        '${cfg.apiBaseUrl}${cfg.mobileApiPrefix}/version?platform=$platform',
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final versionMinima = (json['version_minima'] as String?) ?? '1.0.0';
      final versionRecomendada =
          (json['version_recomendada'] as String?) ?? '1.0.0';
      final urlDescarga = json['url_descarga'] as String?;
      final mensaje = json['mensaje'] as String?;

      final status = _computeStatus(
        current: currentVersion,
        minima: versionMinima,
        recomendada: versionRecomendada,
      );

      return AppVersionCheckResult(
        status: status,
        currentVersion: currentVersion,
        versionMinima: versionMinima,
        versionRecomendada: versionRecomendada,
        urlDescarga: urlDescarga,
        mensaje: mensaje,
      );
    } catch (_) {
      // Si falla la verificacion (sin conexion, error de BD, etc.) no bloqueamos el acceso
      return null;
    }
  }

  static AppVersionStatus _computeStatus({
    required String current,
    required String minima,
    required String recomendada,
  }) {
    final cur = _parseVersion(current);
    final min = _parseVersion(minima);
    final rec = _parseVersion(recomendada);

    if (_isLessThan(cur, min)) return AppVersionStatus.updateRequired;
    if (_isLessThan(cur, rec)) return AppVersionStatus.updateRecommended;
    return AppVersionStatus.upToDate;
  }

  static List<int> _parseVersion(String version) {
    return version
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
  }

  static bool _isLessThan(List<int> a, List<int> b) {
    final len = [a.length, b.length].reduce((x, y) => x > y ? x : y);
    for (var i = 0; i < len; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av < bv) return true;
      if (av > bv) return false;
    }
    return false;
  }
}
