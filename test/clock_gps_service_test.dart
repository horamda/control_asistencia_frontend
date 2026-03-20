import 'package:ficharqr/src/core/attendance/clock_gps_service.dart';
import 'package:ficharqr/src/core/attendance/qr_clock_submission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClockGpsService', () {
    test('reutiliza GPS cacheado cuando sigue fresco', () async {
      var currentCalls = 0;
      final cachedGps = ClockGpsPoint(
        lat: -34.6,
        lon: -58.4,
        capturedAt: DateTime(2026, 3, 17, 10, 0, 0),
      );
      final service = ClockGpsService(
        locationServiceEnabledProvider: () async => true,
        locationGrantedProvider: () async => true,
        lastKnownGpsProvider: () async => null,
        currentGpsProvider: (_) async {
          currentCalls += 1;
          return null;
        },
        nowProvider: () => DateTime(2026, 3, 17, 10, 1, 0),
      );

      final result = await service.capture(
        cachedGps: cachedGps,
        gpsTtl: const Duration(minutes: 2),
      );

      expect(result, same(cachedGps));
      expect(currentCalls, 0);
    });

    test('forceRefresh ignora cache y reacquire GPS actual', () async {
      var currentCalls = 0;
      final service = ClockGpsService(
        locationServiceEnabledProvider: () async => true,
        locationGrantedProvider: () async => true,
        lastKnownGpsProvider: () async => ClockGpsPoint(
          lat: -34.5,
          lon: -58.3,
          capturedAt: DateTime(2026, 3, 17, 10, 0, 30),
        ),
        currentGpsProvider: (_) async {
          currentCalls += 1;
          return ClockGpsPoint(
            lat: -34.7,
            lon: -58.5,
            capturedAt: DateTime(2026, 3, 17, 10, 1, 0),
          );
        },
        nowProvider: () => DateTime(2026, 3, 17, 10, 1, 0),
      );

      final result = await service.capture(
        cachedGps: ClockGpsPoint(
          lat: -34.6,
          lon: -58.4,
          capturedAt: DateTime(2026, 3, 17, 10, 0, 45),
        ),
        gpsTtl: const Duration(minutes: 2),
        forceRefresh: true,
      );

      expect(currentCalls, 1);
      expect(result?.lat, -34.7);
      expect(result?.lon, -58.5);
    });
  });
}
