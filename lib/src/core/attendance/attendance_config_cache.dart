import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/mobile_api_client.dart';
import '../utils/app_logger.dart';

/// Persiste la ultima [AttendanceConfig] conocida en almacenamiento seguro.
///
/// Permite que el empleado pueda fichar offline incluso despues de reiniciar
/// la app sin conexion: si la API falla al arrancar, se usa la config guardada
/// del ultimo uso exitoso.
class AttendanceConfigCache {
  AttendanceConfigCache({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static final _log = AppLogger.get('AttendanceConfigCache');
  static const _key = 'attendance_config_cache_v1';

  final FlutterSecureStorage _storage;

  /// Guarda [config] en el cache persistente.
  Future<void> save(AttendanceConfig config) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(config.toJson()));
    } catch (e, stack) {
      _log.warning('Error al guardar config en cache.', e, stack);
    }
  }

  /// Carga la config persistida. Retorna `null` si no hay cache o si esta
  /// corrupto.
  Future<AttendanceConfig?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _log.warning('Config cache con formato invalido, se descarta.');
        await _clear();
        return null;
      }
      return AttendanceConfig.fromJson(decoded);
    } catch (e, stack) {
      _log.warning('Error al leer config cache, se descarta.', e, stack);
      await _clear();
      return null;
    }
  }

  Future<void> _clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
