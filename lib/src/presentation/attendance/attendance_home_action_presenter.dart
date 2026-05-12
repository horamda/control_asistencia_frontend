import 'package:flutter/material.dart';

import '../../core/offline/pending_queue_controller.dart';
import 'attendance_home_view_model.dart';

class AttendanceHomeActionPresenter {
  const AttendanceHomeActionPresenter();

  AttendanceHomeActionViewData build({
    required AttendanceHomeViewData viewData,
    required PendingQueueState pendingQueue,
    required bool submitting,
    required bool locatingGps,
    required bool isBusy,
  }) {
    final syncEnabled = !(pendingQueue.syncing || submitting);
    final gpsEnabled = !(isBusy || locatingGps);
    final clockEnabled = !isBusy;
    final historyEnabled = !submitting;

    final bannerPrimary = viewData.hasPendingErrors
        ? AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.openPendingQueue,
            label: 'Abrir bandeja',
            icon: Icons.inbox_outlined,
            enabled: syncEnabled,
          )
        : AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.syncPending,
            label: pendingQueue.syncing
                ? 'Sincronizando...'
                : 'Sincronizar ahora',
            icon: Icons.sync_alt_outlined,
            enabled: syncEnabled,
            loading: pendingQueue.syncing,
          );

    final bannerSecondary = viewData.hasPendingErrors
        ? AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.syncPending,
            label: 'Intentar sincronizar',
            icon: Icons.sync_alt_outlined,
            enabled: syncEnabled,
          )
        : AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.openPendingQueue,
            label: 'Ver bandeja offline',
            icon: Icons.inbox_outlined,
            enabled: syncEnabled,
          );

    final nextStepPrimary = pendingQueue.failed > 0
        ? AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.openPendingQueue,
            label: 'Abrir bandeja',
            icon: Icons.inbox_outlined,
            enabled: syncEnabled,
          )
        : pendingQueue.total > 0
        ? AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.syncPending,
            label: pendingQueue.syncing
                ? 'Sincronizando...'
                : 'Sincronizar pendientes',
            icon: Icons.sync_alt_outlined,
            enabled: syncEnabled,
            loading: pendingQueue.syncing,
          )
        : !viewData.hasFreshGps
        ? AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.captureGps,
            label: locatingGps ? 'Obteniendo GPS...' : 'Validar GPS',
            icon: Icons.my_location_outlined,
            enabled: gpsEnabled,
            loading: locatingGps,
          )
        : AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.startClock,
            label: viewData.hasClockToday ? 'Nueva fichada' : 'Fichar ahora',
            icon: Icons.qr_code_scanner_rounded,
            enabled: clockEnabled,
          );

    final nextStepSecondary = viewData.hasPendingErrors
        ? AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.syncPending,
            label: 'Intentar sincronizar',
            icon: Icons.sync_alt_outlined,
            enabled: syncEnabled,
          )
        : viewData.hasPendingSync
        ? AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.openPendingQueue,
            label: 'Ver bandeja offline',
            icon: Icons.inbox_outlined,
            enabled: syncEnabled,
          )
        : AttendanceHomeActionSpec(
            intent: AttendanceHomeActionIntent.openMarksHistory,
            label: viewData.hasFreshGps
                ? 'Ver marcas del dia'
                : 'Ver marcas de hoy',
            icon: Icons.timeline_outlined,
            enabled: historyEnabled,
          );

    return AttendanceHomeActionViewData(
      bannerPrimary: bannerPrimary,
      bannerSecondary: bannerSecondary,
      nextStepPrimary: nextStepPrimary,
      nextStepSecondary: nextStepSecondary,
      clockMain: AttendanceHomeActionSpec(
        intent: AttendanceHomeActionIntent.startClock,
        label: 'Escanear QR y fichar',
        icon: Icons.qr_code_scanner_rounded,
        enabled: clockEnabled,
        loading: submitting,
        color: const Color(0xFF0E5A8A),
      ),
      clockSecondary: [
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.captureGps,
          label: locatingGps ? 'Obteniendo GPS...' : 'Actualizar GPS',
          icon: Icons.my_location_outlined,
          enabled: gpsEnabled,
          loading: locatingGps,
        ),
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.openPendingQueue,
          label: 'Bandeja offline',
          icon: Icons.inbox_outlined,
          enabled: syncEnabled,
        ),
      ],
      quickActions: [
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.openAttendanceHistory,
          label: 'Asistencias',
          icon: Icons.calendar_month_outlined,
          enabled: historyEnabled,
        ),
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.openJustificaciones,
          label: 'Justificaciones',
          icon: Icons.fact_check_outlined,
          enabled: historyEnabled,
        ),
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.openAdelantos,
          label: 'Adelantos',
          icon: Icons.payments_outlined,
          enabled: historyEnabled,
        ),
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.openVacaciones,
          label: 'Vacaciones',
          icon: Icons.beach_access_outlined,
          enabled: historyEnabled,
        ),
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.openFrancos,
          label: 'Francos',
          icon: Icons.free_cancellation_outlined,
          enabled: historyEnabled,
        ),
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.openLegajo,
          label: 'Legajo',
          icon: Icons.folder_open_outlined,
          enabled: historyEnabled,
        ),
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.openPedidosMercaderia,
          label: 'Mercadería',
          icon: Icons.inventory_2_outlined,
          enabled: historyEnabled,
        ),
        AttendanceHomeActionSpec(
          intent: AttendanceHomeActionIntent.openKpisSector,
          label: 'KPIs',
          icon: Icons.bar_chart_outlined,
          enabled: historyEnabled,
        ),
      ],
    );
  }
}

class AttendanceHomeActionViewData {
  const AttendanceHomeActionViewData({
    required this.bannerPrimary,
    required this.bannerSecondary,
    required this.nextStepPrimary,
    required this.nextStepSecondary,
    required this.clockMain,
    required this.clockSecondary,
    required this.quickActions,
  });

  final AttendanceHomeActionSpec bannerPrimary;
  final AttendanceHomeActionSpec bannerSecondary;
  final AttendanceHomeActionSpec nextStepPrimary;
  final AttendanceHomeActionSpec nextStepSecondary;
  final AttendanceHomeActionSpec clockMain;
  final List<AttendanceHomeActionSpec> clockSecondary;
  final List<AttendanceHomeActionSpec> quickActions;
}

class AttendanceHomeActionSpec {
  const AttendanceHomeActionSpec({
    required this.intent,
    required this.label,
    required this.icon,
    required this.enabled,
    this.loading = false,
    this.color,
  });

  final AttendanceHomeActionIntent intent;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool loading;
  final Color? color;
}

enum AttendanceHomeActionIntent {
  openPendingQueue,
  syncPending,
  captureGps,
  startClock,
  openMarksHistory,
  openAttendanceHistory,
  openProfile,
  openBiometricSettings,
  openStats,
  openSecurityEvents,
  openJustificaciones,
  openAdelantos,
  openVacaciones,
  openFrancos,
  openLegajo,
  openPedidosMercaderia,
  openKpisSector,
}
