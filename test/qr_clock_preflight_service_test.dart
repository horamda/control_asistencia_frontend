import 'package:ficharqr/src/core/attendance/clock_readiness_service.dart';
import 'package:ficharqr/src/core/attendance/qr_clock_preflight_service.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QrClockPreflightService', () {
    test('marca error cuando falta config', () async {
      final service = QrClockPreflightService(
        cameraGrantedProvider: () async => true,
        locationGrantedProvider: () async => true,
        locationServiceEnabledProvider: () async => true,
        nowProvider: () => DateTime(2026, 3, 17, 10, 0, 0),
      );

      final result = await service.validate(
        config: null,
        current: const ClockReadinessSnapshot(),
      );

      expect(result.status, QrClockPreflightStatus.missingConfig);
      expect(result.canProceed, isFalse);
      expect(result.readiness.checkedAt, DateTime(2026, 3, 17, 10, 0, 0));
    });

    test('corta en camara si el permiso no esta otorgado', () async {
      var locationServiceChecks = 0;
      final service = QrClockPreflightService(
        cameraGrantedProvider: () async => false,
        locationGrantedProvider: () async => true,
        locationServiceEnabledProvider: () async {
          locationServiceChecks += 1;
          return true;
        },
        nowProvider: () => DateTime(2026, 3, 17, 10, 0, 0),
      );

      final result = await service.validate(
        config: AttendanceConfig(
          empresaId: 1,
          requiereQr: true,
          requiereFoto: false,
          requiereGeo: true,
          toleranciaGlobal: null,
          cooldownScanSegundos: 0,
          intervaloMinimoFichadasMinutos: null,
          metodosHabilitados: const <String>['qr'],
        ),
        current: const ClockReadinessSnapshot(),
      );

      expect(result.status, QrClockPreflightStatus.cameraPermissionDenied);
      expect(result.readiness.cameraGranted, isFalse);
      expect(locationServiceChecks, 0);
    });

    test('reutiliza snapshot fresco sin llamar a los providers', () async {
      var cameraChecks = 0;
      var locationChecks = 0;
      var locationServiceChecks = 0;
      final now = DateTime(2026, 3, 17, 10, 0, 0);
      final service = QrClockPreflightService(
        cameraGrantedProvider: () async {
          cameraChecks += 1;
          return true;
        },
        locationGrantedProvider: () async {
          locationChecks += 1;
          return true;
        },
        locationServiceEnabledProvider: () async {
          locationServiceChecks += 1;
          return true;
        },
        nowProvider: () => now,
        snapshotTtl: const Duration(seconds: 30),
      );

      // snapshot chequeado 10s atras — dentro del TTL
      final freshSnapshot = ClockReadinessSnapshot(
        cameraGranted: true,
        locationGranted: true,
        locationServiceEnabled: true,
        checkedAt: now.subtract(const Duration(seconds: 10)),
      );

      final result = await service.validate(
        config: AttendanceConfig(
          empresaId: 1,
          requiereQr: true,
          requiereFoto: false,
          requiereGeo: true,
          toleranciaGlobal: null,
          cooldownScanSegundos: 0,
          intervaloMinimoFichadasMinutos: null,
          metodosHabilitados: const <String>['qr'],
        ),
        current: freshSnapshot,
      );

      expect(result.status, QrClockPreflightStatus.ready);
      // los providers NO deben haberse invocado
      expect(cameraChecks, 0);
      expect(locationChecks, 0);
      expect(locationServiceChecks, 0);
    });

    test('re-chequea providers cuando el snapshot esta vencido', () async {
      var cameraChecks = 0;
      final now = DateTime(2026, 3, 17, 10, 0, 0);
      final service = QrClockPreflightService(
        cameraGrantedProvider: () async {
          cameraChecks += 1;
          return true;
        },
        locationGrantedProvider: () async => true,
        locationServiceEnabledProvider: () async => true,
        nowProvider: () => now,
        snapshotTtl: const Duration(seconds: 30),
      );

      // snapshot chequeado hace 60s — fuera del TTL
      final staleSnapshot = ClockReadinessSnapshot(
        cameraGranted: true,
        locationGranted: true,
        locationServiceEnabled: true,
        checkedAt: now.subtract(const Duration(seconds: 60)),
      );

      final result = await service.validate(
        config: AttendanceConfig(
          empresaId: 1,
          requiereQr: true,
          requiereFoto: false,
          requiereGeo: true,
          toleranciaGlobal: null,
          cooldownScanSegundos: 0,
          intervaloMinimoFichadasMinutos: null,
          metodosHabilitados: const <String>['qr'],
        ),
        current: staleSnapshot,
      );

      expect(result.status, QrClockPreflightStatus.ready);
      // el provider SI debe haberse invocado porque el snapshot es viejo
      expect(cameraChecks, 1);
    });

    test('queda listo cuando permisos y servicio estan OK', () async {
      final service = QrClockPreflightService(
        cameraGrantedProvider: () async => true,
        locationGrantedProvider: () async => true,
        locationServiceEnabledProvider: () async => true,
        nowProvider: () => DateTime(2026, 3, 17, 10, 0, 0),
      );

      final result = await service.validate(
        config: AttendanceConfig(
          empresaId: 1,
          requiereQr: true,
          requiereFoto: false,
          requiereGeo: true,
          toleranciaGlobal: null,
          cooldownScanSegundos: 0,
          intervaloMinimoFichadasMinutos: null,
          metodosHabilitados: const <String>['qr'],
        ),
        current: const ClockReadinessSnapshot(),
      );

      expect(result.status, QrClockPreflightStatus.ready);
      expect(result.canProceed, isTrue);
      expect(result.readiness.cameraReady, isTrue);
      expect(result.readiness.locationReady, isTrue);
      expect(result.readiness.locationServiceReady, isTrue);
    });
  });
}
