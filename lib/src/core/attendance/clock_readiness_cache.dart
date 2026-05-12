import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/app_logger.dart';

/// Persiste el estado de permisos de camara y ubicacion del ultimo arranque.
///
/// Los permisos del sistema son persistentes (el usuario los otorga una vez
/// y permanecen hasta que los revoca manualmente). Al arrancar la app con
/// estos valores pre-cargados, los badges de readiness muestran estado
/// correcto de inmediato sin esperar el primer warm-up.
///
/// No se persiste [locationServiceEnabled] (el GPS del sistema puede
/// activarse/desactivarse en cualquier momento) ni la posicion GPS (siempre
/// debe ser fresca).
class ClockReadinessCache {
  ClockReadinessCache({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static final _log = AppLogger.get('ClockReadinessCache');
  static const _cameraKey = 'clock_readiness_camera_v1';
  static const _locationKey = 'clock_readiness_location_v1';

  final FlutterSecureStorage _storage;

  /// Guarda el estado de permisos si algun valor cambio a `true`.
  ///
  /// Solo persiste permisos concedidos — si el usuario los revoca, el
  /// warm-up lo detectara y el valor quedara en `false` en memoria, pero
  /// el cache no se actualiza hasta el proximo arranque.
  Future<void> saveGranted({
    required bool cameraGranted,
    required bool locationGranted,
  }) async {
    try {
      await Future.wait([
        if (cameraGranted) _storage.write(key: _cameraKey, value: '1'),
        if (locationGranted) _storage.write(key: _locationKey, value: '1'),
      ]);
    } catch (e, stack) {
      _log.warning('Error al guardar permisos en cache.', e, stack);
    }
  }

  /// Carga el estado de permisos persistido.
  ///
  /// Retorna `(cameraGranted: false, locationGranted: false)` si no hay cache.
  Future<({bool cameraGranted, bool locationGranted})> load() async {
    try {
      final values = await Future.wait([
        _storage.read(key: _cameraKey),
        _storage.read(key: _locationKey),
      ]);
      return (
        cameraGranted: values[0] == '1',
        locationGranted: values[1] == '1',
      );
    } catch (e, stack) {
      _log.warning('Error al leer permisos desde cache.', e, stack);
      return (cameraGranted: false, locationGranted: false);
    }
  }

  /// Limpia el cache de permisos (util si el usuario revoca permisos
  /// manualmente desde Ajustes del sistema).
  Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(key: _cameraKey),
        _storage.delete(key: _locationKey),
      ]);
    } catch (_) {}
  }
}
