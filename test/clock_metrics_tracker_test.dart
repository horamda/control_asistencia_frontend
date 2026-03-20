import 'package:ficharqr/src/core/attendance/clock_metrics_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClockMetricsTracker', () {
    test('record guarda ultima muestra y acumula promedios', () {
      final tracker = ClockMetricsTracker(
        nowProvider: () => DateTime(2026, 3, 17, 10, 0, 0),
      );

      final first = tracker.record(
        current: const ClockMetricsSnapshot(),
        total: const Duration(seconds: 6),
        api: const Duration(seconds: 2),
        gps: const Duration(seconds: 1),
      );
      final second = tracker.record(
        current: first,
        total: const Duration(seconds: 4),
        photo: const Duration(milliseconds: 800),
      );

      expect(second.sampleCount, 2);
      expect(second.lastClockAt, DateTime(2026, 3, 17, 10, 0, 0));
      expect(second.lastClockTotalDuration, const Duration(seconds: 4));
      expect(second.lastClockPhotoDuration, const Duration(milliseconds: 800));
      expect(second.averageTotalDuration, const Duration(seconds: 5));
      expect(second.averageApiDuration, const Duration(seconds: 2));
    });
  });
}
