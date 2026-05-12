import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';
import 'package:ficharqr/src/core/offline/pending_clock_sync_service.dart';
import 'package:ficharqr/src/core/offline/pending_queue_controller.dart';
import 'package:ficharqr/src/presentation/attendance/attendance_home_action_presenter.dart';
import 'package:ficharqr/src/presentation/attendance/attendance_home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceHomeActionPresenter', () {
    const presenter = AttendanceHomeActionPresenter();

    test('prioriza bandeja cuando hay errores pendientes', () {
      final data = presenter.build(
        viewData: _viewData(
          hasPendingErrors: true,
          hasPendingSync: true,
          hasFreshGps: false,
        ),
        pendingQueue: PendingQueueState(
          snapshot: PendingClockSnapshot.fromRecords([
            OfflineClockRecord(
              id: 'failed-1',
              employeeId: 7,
              qrToken: 'qr',
              eventAt: DateTime(2026, 3, 17, 8),
              createdAt: DateTime(2026, 3, 17, 8),
              status: OfflineClockStatus.failed,
            ),
          ]),
        ),
        submitting: false,
        locatingGps: false,
        isBusy: false,
      );

      expect(
        data.bannerPrimary.intent,
        AttendanceHomeActionIntent.openPendingQueue,
      );
      expect(data.bannerPrimary.label, 'Abrir bandeja');
      expect(data.bannerSecondary.intent, AttendanceHomeActionIntent.syncPending);
      expect(
        data.nextStepPrimary.intent,
        AttendanceHomeActionIntent.openPendingQueue,
      );
      expect(
        data.nextStepSecondary.intent,
        AttendanceHomeActionIntent.syncPending,
      );
    });

    test('muestra sincronizacion en curso como accion bloqueada', () {
      final data = presenter.build(
        viewData: _viewData(hasPendingSync: true),
        pendingQueue: const PendingQueueState(
          snapshot: PendingClockSnapshot(
            records: <OfflineClockRecord>[],
            total: 2,
            failed: 0,
          ),
          syncing: true,
        ),
        submitting: false,
        locatingGps: false,
        isBusy: false,
      );

      expect(data.bannerPrimary.label, 'Sincronizando...');
      expect(data.bannerPrimary.loading, isTrue);
      expect(data.bannerPrimary.enabled, isFalse);
      expect(data.nextStepPrimary.intent, AttendanceHomeActionIntent.syncPending);
      expect(data.nextStepPrimary.loading, isTrue);
      expect(data.clockSecondary.last.enabled, isFalse);
    });

    test('habilita fichada y deshabilita accesos rapidos durante submit', () {
      final data = presenter.build(
        viewData: _viewData(
          hasClockToday: true,
          hasFreshGps: true,
        ),
        pendingQueue: const PendingQueueState(),
        submitting: true,
        locatingGps: false,
        isBusy: true,
      );

      expect(data.nextStepPrimary.intent, AttendanceHomeActionIntent.startClock);
      expect(data.nextStepPrimary.label, 'Nueva fichada');
      expect(data.nextStepPrimary.enabled, isFalse);
      expect(data.clockMain.loading, isTrue);
      expect(data.clockMain.enabled, isFalse);
      expect(
        data.nextStepSecondary.intent,
        AttendanceHomeActionIntent.openMarksHistory,
      );
      expect(data.nextStepSecondary.enabled, isFalse);
      expect(data.quickActions.every((item) => !item.enabled), isTrue);
    });
  });
}

AttendanceHomeViewData _viewData({
  bool hasPendingUrgency = false,
  bool hasPendingErrors = false,
  bool hasPendingSync = false,
  bool hasClockToday = false,
  bool hasFreshGps = false,
}) {
  return AttendanceHomeViewData(
    syncText: 'Sincronizado',
    avgTotal: '5s',
    avgApi: '2s',
    sessionText: 'Sesion activa',
    sessionForeground: Colors.white,
    gpsText: '-34.60, -58.38',
    pendingClean: 0,
    lastSyncText: '09:00',
    lastSyncStatText: '09:00',
    hasPendingUrgency: hasPendingUrgency,
    hasPendingErrors: hasPendingErrors,
    hasPendingSync: hasPendingSync,
    hasClockToday: hasClockToday,
    hasFreshGps: hasFreshGps,
    gpsStatusText: 'GPS validado',
    configReady: true,
    cameraReady: true,
    locationReady: true,
    locationServiceReady: true,
    readinessCheckText: 'hace 1m',
    configPrepText: 'Config lista',
    cameraPrepText: 'Camara OK',
    locationPrepText: 'Ubicacion OK',
    gpsPrepText: hasFreshGps ? 'GPS fresco' : 'GPS vencido',
    readinessSummary: 'Listo',
    lastClockText: '09:50 (hace 10m)',
    lastClockStatText: '09:50',
    lastClockTotalText: '5s',
    lastClockApiText: '2s',
    lastClockGpsText: '1s',
    lastClockPhotoText: null,
    nextStepTitle: 'Siguiente',
    nextStepBody: 'Detalle',
    nextStepPriorityLabel: 'Normal',
    nextStepPriorityBackground: const Color(0xFFE6F4EA),
    nextStepPriorityForeground: const Color(0xFF1F5A35),
    contentMaxWidth: 960,
    horizontalPadding: 20,
  );
}
