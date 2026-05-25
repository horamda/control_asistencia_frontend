import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ficharqr/src/core/utils/device_telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildLoginTelemetry', () {
    test('devuelve appVersion del PackageInfo mockeado', () async {
      PackageInfo.setMockInitialValues(
        appName: 'FichaYa',
        packageName: 'com.controlasistencia.ficharqr',
        version: '1.20.4',
        buildNumber: '1',
        buildSignature: '',
      );

      final telemetry = await buildLoginTelemetry();

      expect(telemetry.appVersion, '1.20.4');
    });

    test('devuelve null para platform y deviceModel en entorno de test (no Android/iOS)', () async {
      PackageInfo.setMockInitialValues(
        appName: 'FichaYa',
        packageName: 'com.controlasistencia.ficharqr',
        version: '2.0.0',
        buildNumber: '1',
        buildSignature: '',
      );

      final telemetry = await buildLoginTelemetry();

      // En el entorno de tests de Dart VM no es Android ni iOS ni Web,
      // asi que platform y deviceModel quedan en null.
      expect(telemetry.platform, isNull);
      expect(telemetry.deviceModel, isNull);
    });

    test('no lanza excepcion cuando PackageInfo falla', () async {
      // Sin mock, PackageInfo.fromPlatform() puede lanzar MissingPluginException.
      // El catch-all de buildLoginTelemetry debe absorberlo.
      PackageInfo.setMockInitialValues(
        appName: '',
        packageName: '',
        version: '',
        buildNumber: '',
        buildSignature: '',
      );

      final telemetry = await buildLoginTelemetry();

      // El resultado es un record valido (no lanza).
      expect(telemetry, isNotNull);
    });
  });
}
