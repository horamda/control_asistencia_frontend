import 'package:ficharqr/src/core/attendance/clock_readiness_service.dart';
import 'package:ficharqr/src/core/attendance/qr_clock_submission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClockReadinessService', () {
    test('warmUp refresca permisos y captura GPS cuando falta muestra fresca', () async {
      var captureCount = 0;
      final service = ClockReadinessService(
        cameraGrantedProvider: () async => true,
        locationGrantedProvider: () async => true,
        locationServiceEnabledProvider: () async => true,
        nowProvider: () => DateTime(2026, 3, 17, 10, 0, 0),
      );

      final result = await service.warmUp(
        current: const ClockReadinessSnapshot(),
        forceGps: false,
        canCaptureGps: true,
        gpsTtl: const Duration(minutes: 2),
        captureGps: () async {
          captureCount += 1;
          return ClockGpsPoint(
            lat: -34.6,
            lon: -58.4,
            capturedAt: DateTime(2026, 3, 17, 10, 0, 0),
          );
        },
      );

      expect(captureCount, 1);
      expect(result.cameraReady, isTrue);
      expect(result.locationReady, isTrue);
      expect(result.locationServiceReady, isTrue);
      expect(
        result.hasFreshGps(
          const Duration(minutes: 2),
          now: DateTime(2026, 3, 17, 10, 0, 30),
        ),
        isTrue,
      );
    });

    test('warmUp reutiliza GPS fresco cuando no hace falta recapturar', () async {
      var captureCount = 0;
      final current = ClockReadinessSnapshot(
        cameraGranted: true,
        locationGranted: true,
        locationServiceEnabled: true,
        gps: ClockGpsPoint(
          lat: -34.6,
          lon: -58.4,
          capturedAt: DateTime(2026, 3, 17, 10, 0, 0),
        ),
      );
      final service = ClockReadinessService(
        cameraGrantedProvider: () async => true,
        locationGrantedProvider: () async => true,
        locationServiceEnabledProvider: () async => true,
        nowProvider: () => DateTime(2026, 3, 17, 10, 1, 0),
      );

      final result = await service.warmUp(
        current: current,
        forceGps: false,
        canCaptureGps: true,
        gpsTtl: const Duration(minutes: 2),
        captureGps: () async {
          captureCount += 1;
          return null;
        },
      );

      expect(captureCount, 0);
      expect(result.gps?.lat, -34.6);
      expect(
        result.hasFreshGps(
          const Duration(minutes: 2),
          now: DateTime(2026, 3, 17, 10, 1, 30),
        ),
        isTrue,
      );
    });
  });
}
