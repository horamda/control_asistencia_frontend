import 'package:ficharqr/src/core/attendance/clock_metrics_tracker.dart';
import 'package:ficharqr/src/core/attendance/clock_readiness_service.dart';
import 'package:ficharqr/src/core/attendance/qr_clock_submission_service.dart';
import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';
import 'package:ficharqr/src/core/offline/pending_clock_sync_service.dart';
import 'package:ficharqr/src/core/offline/pending_queue_controller.dart';
import 'package:ficharqr/src/presentation/attendance/attendance_home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceHomeViewDataBuilder', () {
    const builder = AttendanceHomeViewDataBuilder();

    test('prioriza pendientes con error y concentra textos derivados', () {
      final now = DateTime(2026, 3, 17, 10, 0);
      final data = builder.build(
        now: now,
        screenWidth: 1080,
        syncText: 'Sincronizado recien',
        sessionBaseText: 'Sesion activa',
        sessionMessage: 'Biometria OK',
        sessionColor: const Color(0xFF0D3B66),
        readiness: ClockReadinessSnapshot(
          cameraGranted: true,
          locationGranted: true,
          locationServiceEnabled: false,
          checkedAt: DateTime(2026, 3, 17, 9, 58),
          gps: ClockGpsPoint(
            lat: -34.6037,
            lon: -58.3816,
            capturedAt: DateTime(2026, 3, 17, 9, 55),
          ),
        ),
        clockMetrics: ClockMetricsSnapshot(
          lastClockAt: DateTime(2026, 3, 16, 18, 0),
          lastClockTotalDuration: Duration(seconds: 9),
          lastClockApiDuration: Duration(seconds: 3),
          lastClockGpsDuration: Duration(seconds: 2),
          sampleCount: 2,
          totalMs: 12000,
          apiMs: 4000,
          apiCount: 2,
        ),
        pendingQueue: PendingQueueState(
          snapshot: PendingClockSnapshot.fromRecords([
            OfflineClockRecord(
              id: 'ok-1',
              employeeId: 7,
              qrToken: 'qr-ok',
              eventAt: DateTime(2026, 3, 17, 8, 0),
              createdAt: DateTime(2026, 3, 17, 8, 0),
            ),
            OfflineClockRecord(
              id: 'failed-1',
              employeeId: 7,
              qrToken: 'qr-failed',
              eventAt: DateTime(2026, 3, 17, 8, 10),
              createdAt: DateTime(2026, 3, 17, 8, 10),
              status: OfflineClockStatus.failed,
            ),
          ]),
          lastSyncAt: DateTime(2026, 3, 17, 9, 45),
        ),
        loadingConfig: false,
        hasFreshConfig: false,
        hasFreshGps: false,
        formatTimeOfDay: _formatTimeOfDay,
        formatRelative: (dateTime) => _formatRelative(now, dateTime),
        formatDuration: _formatDuration,
        isSameDay: _isSameDay,
      );

      expect(data.syncText, 'Sincronizado recien');
      expect(data.sessionText, 'Sesion activa | Biometria OK');
      expect(data.pendingClean, 1);
      expect(data.lastSyncText, '09:45');
      expect(data.lastSyncStatText, '09:45');
      expect(data.gpsStatusText, 'GPS validado hace 5m');
      expect(data.locationPrepText, 'GPS apagado');
      expect(data.readinessSummary, 'Faltan validaciones para agilizar la fichada.');
      expect(data.nextStepTitle, 'Corregir fichadas con error');
      expect(data.nextStepPriorityLabel, 'Prioridad alta');
      expect(data.avgTotal, '6s');
      expect(data.avgApi, '2s');
      expect(data.lastClockStatText, '18:00');
      expect(data.lastClockTotalText, '9s');
      expect(data.lastClockApiText, '3s');
      expect(data.lastClockGpsText, '2s');
      expect(data.lastClockPhotoText, isNull);
      expect(data.quickActionColumns, 3);
    });

    test('marca jornada en curso cuando todo esta listo', () {
      final now = DateTime(2026, 3, 17, 10, 0);
      final data = builder.build(
        now: now,
        screenWidth: 420,
        syncText: 'Cola al dia',
        sessionBaseText: 'Sesion activa',
        sessionMessage: null,
        sessionColor: const Color(0xFFE6F4EA),
        readiness: ClockReadinessSnapshot(
          cameraGranted: true,
          locationGranted: true,
          locationServiceEnabled: true,
          checkedAt: DateTime(2026, 3, 17, 9, 59),
          gps: ClockGpsPoint(
            lat: -34.6037,
            lon: -58.3816,
            capturedAt: DateTime(2026, 3, 17, 9, 59),
          ),
        ),
        clockMetrics: ClockMetricsSnapshot(
          lastClockAt: DateTime(2026, 3, 17, 9, 50),
        ),
        pendingQueue: const PendingQueueState(),
        loadingConfig: false,
        hasFreshConfig: true,
        hasFreshGps: true,
        formatTimeOfDay: _formatTimeOfDay,
        formatRelative: (dateTime) => _formatRelative(now, dateTime),
        formatDuration: _formatDuration,
        isSameDay: _isSameDay,
      );

      expect(data.sessionText, 'Sesion activa');
      expect(data.configPrepText, 'Config lista');
      expect(data.cameraPrepText, 'Camara OK');
      expect(data.locationPrepText, 'Ubicacion OK');
      expect(data.gpsPrepText, 'GPS fresco');
      expect(data.readinessSummary, 'Listo para fichar sin esperas largas.');
      expect(data.nextStepTitle, 'Jornada en curso');
      expect(data.nextStepPriorityLabel, 'Prioridad normal');
      expect(data.lastClockText, '09:50 (hace 10m)');
      expect(data.contentMaxWidth, 460.0);
      expect(data.horizontalPadding, 12.0);
      expect(data.quickActionColumns, 1);
    });
  });
}

String _formatTimeOfDay(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatRelative(DateTime now, DateTime dateTime) {
  return 'hace ${now.difference(dateTime).inMinutes}m';
}

String _formatDuration(Duration duration) {
  return '${duration.inSeconds}s';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
