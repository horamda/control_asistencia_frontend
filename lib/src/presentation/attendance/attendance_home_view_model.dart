import 'package:flutter/material.dart';

import '../../core/attendance/clock_metrics_tracker.dart';
import '../../core/attendance/clock_readiness_service.dart';
import '../../core/offline/pending_queue_controller.dart';

class AttendanceHomeViewDataBuilder {
  const AttendanceHomeViewDataBuilder();

  AttendanceHomeViewData build({
    required DateTime now,
    required double screenWidth,
    required String syncText,
    required String sessionBaseText,
    required String? sessionMessage,
    required Color sessionColor,
    required ClockReadinessSnapshot readiness,
    required ClockMetricsSnapshot clockMetrics,
    required PendingQueueState pendingQueue,
    required bool loadingConfig,
    required bool hasFreshConfig,
    required bool hasFreshGps,
    required String Function(DateTime dateTime) formatTimeOfDay,
    required String Function(DateTime dateTime) formatRelative,
    required String Function(Duration duration) formatDuration,
    required bool Function(DateTime a, DateTime b) isSameDay,
  }) {
    final avgTotal = clockMetrics.averageTotalDuration == null
        ? '-'
        : formatDuration(clockMetrics.averageTotalDuration!);
    final avgApi = clockMetrics.averageApiDuration == null
        ? '-'
        : formatDuration(clockMetrics.averageApiDuration!);
    final sessionText = sessionMessage == null
        ? sessionBaseText
        : '$sessionBaseText | $sessionMessage';
    final sessionForeground =
        ThemeData.estimateBrightnessForColor(sessionColor) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1B2838);
    final gps = readiness.gps;
    final gpsText = gps == null
        ? 'Sin GPS reciente'
        : '${gps.lat.toStringAsFixed(5)}, ${gps.lon.toStringAsFixed(5)}';
    final pendingClean = pendingQueue.cleanCount;
    final lastSyncText = pendingQueue.lastSyncAt == null
        ? 'Sin sincronizar'
        : formatTimeOfDay(pendingQueue.lastSyncAt!);
    final lastSyncStatText = pendingQueue.lastSyncAt == null
        ? '-'
        : formatTimeOfDay(pendingQueue.lastSyncAt!);
    final hasPendingUrgency = pendingQueue.hasUrgency;
    final hasPendingErrors = pendingQueue.hasErrors;
    final hasPendingSync = pendingQueue.hasPending;
    final hasClockToday =
        clockMetrics.lastClockAt != null &&
        isSameDay(clockMetrics.lastClockAt!, now);
    final gpsAgeText = gps?.capturedAt == null
        ? null
        : formatRelative(gps!.capturedAt!);
    final gpsStatusText = gps == null
        ? 'GPS sin validar'
        : gpsAgeText == null
        ? 'GPS validado'
        : 'GPS validado $gpsAgeText';
    final configReady = hasFreshConfig;
    final cameraReady = readiness.cameraReady;
    final locationReady = readiness.locationReady;
    final locationServiceReady = readiness.locationServiceReady;
    final readinessCheckText = readiness.checkedAt == null
        ? 'sin chequeo reciente'
        : formatRelative(readiness.checkedAt!);
    final configPrepText = loadingConfig
        ? 'Config actualizando'
        : configReady
        ? 'Config lista'
        : 'Config pendiente';
    final cameraPrepText = readiness.cameraGranted == null
        ? 'Camara sin chequear'
        : cameraReady
        ? 'Camara OK'
        : 'Camara pendiente';
    final locationPrepText = readiness.locationGranted == null
        ? 'Ubicacion sin chequear'
        : !locationReady
        ? 'Ubicacion pendiente'
        : locationServiceReady
        ? 'Ubicacion OK'
        : 'GPS apagado';
    final gpsPrepText = gps == null
        ? 'GPS sin muestra'
        : hasFreshGps
        ? 'GPS fresco'
        : 'GPS vencido';
    final clockReadyForScan =
        configReady &&
        cameraReady &&
        locationReady &&
        locationServiceReady &&
        hasFreshGps;
    final readinessSummary = clockReadyForScan
        ? 'Listo para fichar sin esperas largas.'
        : readiness.warming
        ? 'Preparando ficha en segundo plano.'
        : 'Faltan validaciones para agilizar la fichada.';
    final lastClockText = clockMetrics.lastClockAt == null
        ? 'Aun no hay fichadas en esta sesion'
        : '${formatTimeOfDay(clockMetrics.lastClockAt!)} (${formatRelative(clockMetrics.lastClockAt!)})';
    final lastClockStatText = clockMetrics.lastClockAt == null
        ? '-'
        : formatTimeOfDay(clockMetrics.lastClockAt!);
    final lastClockTotalText = clockMetrics.lastClockTotalDuration == null
        ? null
        : formatDuration(clockMetrics.lastClockTotalDuration!);
    final lastClockApiText = clockMetrics.lastClockApiDuration == null
        ? null
        : formatDuration(clockMetrics.lastClockApiDuration!);
    final lastClockGpsText = clockMetrics.lastClockGpsDuration == null
        ? null
        : formatDuration(clockMetrics.lastClockGpsDuration!);
    final lastClockPhotoText = clockMetrics.lastClockPhotoDuration == null
        ? null
        : formatDuration(clockMetrics.lastClockPhotoDuration!);
    final nextStepTitle = pendingQueue.failed > 0
        ? 'Corregir fichadas con error'
        : pendingQueue.total > 0
        ? 'Enviar fichadas pendientes'
        : !hasFreshGps
        ? 'Validar GPS'
        : !hasClockToday
        ? 'Hacer primera fichada'
        : 'Jornada en curso';
    final nextStepBody = pendingQueue.failed > 0
        ? 'Hay ${pendingQueue.failed} marcas con error. Abre la bandeja y corrige cada item.'
        : pendingQueue.total > 0
        ? 'Hay ${pendingQueue.total} fichadas guardadas localmente. Sincroniza para evitar diferencias.'
        : !hasFreshGps
        ? 'Actualiza tu ubicacion para reducir rechazos al escanear.'
        : !hasClockToday
        ? 'Cuando llegues al punto de control, escanea el QR para iniciar la jornada.'
        : 'Ultima actividad: $lastClockText.';
    final nextStepPriorityLabel = hasPendingErrors
        ? 'Prioridad alta'
        : hasPendingSync || !hasFreshGps
        ? 'Prioridad media'
        : 'Prioridad normal';
    final nextStepPriorityBackground = hasPendingErrors
        ? const Color(0xFFFFE7E7)
        : hasPendingSync || !hasFreshGps
        ? const Color(0xFFFFF3DF)
        : const Color(0xFFE6F4EA);
    final nextStepPriorityForeground = hasPendingErrors
        ? const Color(0xFF9A2E2E)
        : hasPendingSync || !hasFreshGps
        ? const Color(0xFF8A4F14)
        : const Color(0xFF1F5A35);
    final contentMaxWidth = screenWidth >= 1400
        ? 1180.0
        : screenWidth >= 1024
        ? 960.0
        : screenWidth >= 760
        ? 720.0
        : 460.0;
    final horizontalPadding = screenWidth < 600 ? 12.0 : 20.0;
    final quickActionColumns = screenWidth >= 900
        ? 3
        : screenWidth >= 560
        ? 2
        : 1;
    final quickActionRatio = quickActionColumns == 1
        ? 3.3
        : quickActionColumns == 2
        ? 2.5
        : 2.2;

    return AttendanceHomeViewData(
      syncText: syncText,
      avgTotal: avgTotal,
      avgApi: avgApi,
      sessionText: sessionText,
      sessionForeground: sessionForeground,
      gpsText: gpsText,
      pendingClean: pendingClean,
      lastSyncText: lastSyncText,
      lastSyncStatText: lastSyncStatText,
      hasPendingUrgency: hasPendingUrgency,
      hasPendingErrors: hasPendingErrors,
      hasPendingSync: hasPendingSync,
      hasClockToday: hasClockToday,
      hasFreshGps: hasFreshGps,
      gpsStatusText: gpsStatusText,
      configReady: configReady,
      cameraReady: cameraReady,
      locationReady: locationReady,
      locationServiceReady: locationServiceReady,
      readinessCheckText: readinessCheckText,
      configPrepText: configPrepText,
      cameraPrepText: cameraPrepText,
      locationPrepText: locationPrepText,
      gpsPrepText: gpsPrepText,
      readinessSummary: readinessSummary,
      lastClockText: lastClockText,
      lastClockStatText: lastClockStatText,
      lastClockTotalText: lastClockTotalText,
      lastClockApiText: lastClockApiText,
      lastClockGpsText: lastClockGpsText,
      lastClockPhotoText: lastClockPhotoText,
      nextStepTitle: nextStepTitle,
      nextStepBody: nextStepBody,
      nextStepPriorityLabel: nextStepPriorityLabel,
      nextStepPriorityBackground: nextStepPriorityBackground,
      nextStepPriorityForeground: nextStepPriorityForeground,
      contentMaxWidth: contentMaxWidth,
      horizontalPadding: horizontalPadding,
      quickActionColumns: quickActionColumns,
      quickActionRatio: quickActionRatio,
    );
  }
}

class AttendanceHomeViewData {
  const AttendanceHomeViewData({
    required this.syncText,
    required this.avgTotal,
    required this.avgApi,
    required this.sessionText,
    required this.sessionForeground,
    required this.gpsText,
    required this.pendingClean,
    required this.lastSyncText,
    required this.lastSyncStatText,
    required this.hasPendingUrgency,
    required this.hasPendingErrors,
    required this.hasPendingSync,
    required this.hasClockToday,
    required this.hasFreshGps,
    required this.gpsStatusText,
    required this.configReady,
    required this.cameraReady,
    required this.locationReady,
    required this.locationServiceReady,
    required this.readinessCheckText,
    required this.configPrepText,
    required this.cameraPrepText,
    required this.locationPrepText,
    required this.gpsPrepText,
    required this.readinessSummary,
    required this.lastClockText,
    required this.lastClockStatText,
    required this.lastClockTotalText,
    required this.lastClockApiText,
    required this.lastClockGpsText,
    required this.lastClockPhotoText,
    required this.nextStepTitle,
    required this.nextStepBody,
    required this.nextStepPriorityLabel,
    required this.nextStepPriorityBackground,
    required this.nextStepPriorityForeground,
    required this.contentMaxWidth,
    required this.horizontalPadding,
    required this.quickActionColumns,
    required this.quickActionRatio,
  });

  final String syncText;
  final String avgTotal;
  final String avgApi;
  final String sessionText;
  final Color sessionForeground;
  final String gpsText;
  final int pendingClean;
  final String lastSyncText;
  final String lastSyncStatText;
  final bool hasPendingUrgency;
  final bool hasPendingErrors;
  final bool hasPendingSync;
  final bool hasClockToday;
  final bool hasFreshGps;
  final String gpsStatusText;
  final bool configReady;
  final bool cameraReady;
  final bool locationReady;
  final bool locationServiceReady;
  final String readinessCheckText;
  final String configPrepText;
  final String cameraPrepText;
  final String locationPrepText;
  final String gpsPrepText;
  final String readinessSummary;
  final String lastClockText;
  final String lastClockStatText;
  final String? lastClockTotalText;
  final String? lastClockApiText;
  final String? lastClockGpsText;
  final String? lastClockPhotoText;
  final String nextStepTitle;
  final String nextStepBody;
  final String nextStepPriorityLabel;
  final Color nextStepPriorityBackground;
  final Color nextStepPriorityForeground;
  final double contentMaxWidth;
  final double horizontalPadding;
  final int quickActionColumns;
  final double quickActionRatio;
}
