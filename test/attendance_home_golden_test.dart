import 'package:ficharqr/src/core/attendance/clock_metrics_tracker.dart';
import 'package:ficharqr/src/core/attendance/clock_readiness_service.dart';
import 'package:ficharqr/src/core/attendance/qr_clock_submission_service.dart';
import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';
import 'package:ficharqr/src/core/offline/pending_clock_sync_service.dart';
import 'package:ficharqr/src/core/offline/pending_queue_controller.dart';
import 'package:ficharqr/src/presentation/attendance/attendance_home_action_presenter.dart';
import 'package:ficharqr/src/presentation/attendance/attendance_home_view_model.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/attendance_dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('attendance_home_goldens', () {
    testWidgets('mobile ready', (tester) async {
      await _pumpScenario(
        tester,
        size: const Size(430, 1400),
        scenario: _buildReadyScenario(screenWidth: 430),
      );
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/attendance_home_mobile_ready.png'),
      );
    });

    testWidgets('mobile pending error', (tester) async {
      await _pumpScenario(
        tester,
        size: const Size(430, 1400),
        scenario: _buildPendingErrorScenario(screenWidth: 430),
      );
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/attendance_home_mobile_pending_error.png'),
      );
    });

    testWidgets('tablet ready', (tester) async {
      await _pumpScenario(
        tester,
        size: const Size(1100, 1400),
        scenario: _buildReadyScenario(screenWidth: 1100),
      );
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/attendance_home_tablet_ready.png'),
      );
    });

    testWidgets('tablet pending error', (tester) async {
      await _pumpScenario(
        tester,
        size: const Size(1100, 1400),
        scenario: _buildPendingErrorScenario(screenWidth: 1100),
      );
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/attendance_home_tablet_pending_error.png'),
      );
    });
  });
}

const _goldenKey = Key('attendance-home-golden');

Future<void> _pumpScenario(
  WidgetTester tester, {
  required Size size,
  required _GoldenScenario scenario,
}) async {
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: RepaintBoundary(
        key: _goldenKey,
        child: Scaffold(
          appBar: AppBar(title: const Text('Fichada por QR')),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: scenario.viewData.contentMaxWidth,
              ),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  scenario.viewData.horizontalPadding,
                  20,
                  scenario.viewData.horizontalPadding,
                  24,
                ),
                children: [
                  if (scenario.viewData.hasPendingUrgency)
                    AttendancePendingBanner(
                      hasErrors: scenario.viewData.hasPendingErrors,
                      pendingCleanCount: scenario.viewData.pendingClean,
                      failedCount: scenario.pendingQueue.failed,
                      lastSyncText: scenario.viewData.lastSyncText,
                      statusMessage: scenario.pendingQueue.lastMessage,
                      primaryAction: _buttonData(scenario.actions.bannerPrimary),
                      secondaryAction: _buttonData(
                        scenario.actions.bannerSecondary,
                      ),
                    ),
                  if (scenario.viewData.hasPendingUrgency)
                    const SizedBox(height: 12),
                  AttendanceHeroCard(
                    photoUrl: '',
                    token: '',
                    employeeName: 'Horacio Perez',
                    employeeDni: '30111222',
                    employeeCompany: 'Empresa: 17',
                    syncText: scenario.viewData.syncText,
                    sessionText: scenario.viewData.sessionText,
                    sessionColor: scenario.sessionColor,
                    sessionForeground: scenario.viewData.sessionForeground,
                    gpsStatusText: scenario.viewData.gpsStatusText,
                  ),
                  const SizedBox(height: 12),
                  AttendanceNextStepCard(
                    priorityLabel: scenario.viewData.nextStepPriorityLabel,
                    priorityBackground:
                        scenario.viewData.nextStepPriorityBackground,
                    priorityForeground:
                        scenario.viewData.nextStepPriorityForeground,
                    title: scenario.viewData.nextStepTitle,
                    body: scenario.viewData.nextStepBody,
                    primaryAction: _buttonData(scenario.actions.nextStepPrimary),
                    secondaryAction: _buttonData(
                      scenario.actions.nextStepSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AttendanceStatsGrid(
                    items: [
                      AttendanceStatItem(
                        title: 'Pendientes',
                        value: '${scenario.pendingQueue.total}',
                        icon: Icons.cloud_upload_outlined,
                        accent: const Color(0xFF2A789E),
                      ),
                      AttendanceStatItem(
                        title: 'Con error',
                        value: '${scenario.pendingQueue.failed}',
                        icon: Icons.warning_amber_rounded,
                        accent: const Color(0xFFC85F0F),
                      ),
                      AttendanceStatItem(
                        title: 'Ultima sync',
                        value: scenario.viewData.lastSyncStatText,
                        icon: Icons.schedule,
                        accent: const Color(0xFF3D4F6B),
                      ),
                      AttendanceStatItem(
                        title: 'Ultima fichada',
                        value: scenario.viewData.lastClockStatText,
                        icon: Icons.punch_clock_outlined,
                        accent: const Color(0xFF315D52),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.qr_code_2_outlined),
                              const SizedBox(width: 8),
                              const Text('Fichar'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Escanea el QR en el punto de control. Detectamos ingreso/egreso automaticamente.',
                          ),
                          const SizedBox(height: 12),
                          AttendanceClockPanel(
                            warming: scenario.readiness.warming,
                            readinessBadges: [
                              AttendanceReadinessBadgeData(
                                text: scenario.viewData.configPrepText,
                                ready: scenario.viewData.configReady,
                              ),
                              AttendanceReadinessBadgeData(
                                text: scenario.viewData.cameraPrepText,
                                ready: scenario.viewData.cameraReady,
                              ),
                              AttendanceReadinessBadgeData(
                                text: scenario.viewData.locationPrepText,
                                ready: scenario.viewData.locationReady &&
                                    scenario.viewData.locationServiceReady,
                              ),
                              AttendanceReadinessBadgeData(
                                text: scenario.viewData.gpsPrepText,
                                ready: scenario.viewData.hasFreshGps,
                              ),
                            ],
                            readinessSummary: scenario.viewData.readinessSummary,
                            readinessCheckText:
                                scenario.viewData.readinessCheckText,
                            phaseText: scenario.phaseText,
                            mainAction: _buttonData(scenario.actions.clockMain),
                            secondaryActions: scenario.actions.clockSecondary
                                .map(_buttonData)
                                .toList(growable: false),
                            gpsText: scenario.viewData.gpsText,
                            lastQrText: scenario.lastQrText,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AttendanceQuickActionsCard(
                    columns: scenario.viewData.quickActionColumns,
                    ratio: scenario.viewData.quickActionRatio,
                    items: scenario.actions.quickActions
                        .map(_quickActionItem)
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  AttendanceDiagnosticsCard(
                    ruleBadges: scenario.ruleBadges,
                    hasMetrics: scenario.clockMetrics.hasSamples,
                    sampleCount: scenario.clockMetrics.sampleCount,
                    lastClockText: scenario.viewData.lastClockStatText == '-'
                        ? null
                        : scenario.viewData.lastClockStatText,
                    lastTotalText: scenario.viewData.lastClockTotalText,
                    lastApiText: scenario.viewData.lastClockApiText,
                    lastGpsText: scenario.viewData.lastClockGpsText,
                    lastPhotoText: scenario.viewData.lastClockPhotoText,
                    averageTotalText: scenario.viewData.avgTotal,
                    averageApiText: scenario.viewData.avgApi,
                    lastQrText: scenario.lastQrText,
                  ),
                  const SizedBox(height: 12),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Para fichar con QR la ubicacion del dispositivo es obligatoria. '
                        'Si no hay internet, la marca queda en cola offline. '
                        'Desliza hacia abajo para refrescar.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

AttendanceActionButtonData _buttonData(AttendanceHomeActionSpec spec) {
  return AttendanceActionButtonData(
    label: spec.label,
    icon: spec.icon,
    loading: spec.loading,
    color: spec.color,
    onPressed: spec.enabled ? () {} : null,
  );
}

AttendanceQuickActionItem _quickActionItem(AttendanceHomeActionSpec spec) {
  return AttendanceQuickActionItem(
    icon: spec.icon,
    label: spec.label,
    onTap: spec.enabled ? () {} : null,
  );
}

_GoldenScenario _buildReadyScenario({required double screenWidth}) {
  final now = DateTime(2026, 3, 18, 9, 30);
  final sessionColor = const Color(0xFFE6F4EA);
  final readiness = ClockReadinessSnapshot(
    cameraGranted: true,
    locationGranted: true,
    locationServiceEnabled: true,
    checkedAt: DateTime(2026, 3, 18, 9, 29),
    gps: ClockGpsPoint(
      lat: -34.60370,
      lon: -58.38160,
      capturedAt: DateTime(2026, 3, 18, 9, 28),
    ),
  );
  final clockMetrics = ClockMetricsSnapshot(
    lastClockAt: DateTime(2026, 3, 18, 9, 5),
    lastClockTotalDuration: const Duration(seconds: 6),
    lastClockApiDuration: const Duration(seconds: 2),
    lastClockGpsDuration: const Duration(seconds: 1),
    lastClockPhotoDuration: const Duration(seconds: 1),
    sampleCount: 3,
    totalMs: 18000,
    apiMs: 6000,
    apiCount: 3,
  );
  final pendingQueue = PendingQueueState(
    lastSyncAt: DateTime(2026, 3, 18, 9, 25),
  );

  return _buildScenario(
    screenWidth: screenWidth,
    now: now,
    syncText: 'Datos sincronizados hace 5 min',
    sessionBaseText: 'Sesion: activa',
    sessionMessage: 'Biometria OK',
    sessionColor: sessionColor,
    readiness: readiness,
    clockMetrics: clockMetrics,
    pendingQueue: pendingQueue,
    loadingConfig: false,
    hasFreshConfig: true,
    hasFreshGps: true,
    submitting: false,
    locatingGps: false,
    isBusy: false,
    phaseText: null,
    lastQrText: 'ENTRADA-PLANTA-001',
    ruleBadges: const [
      AttendanceRuleChip(label: 'QR', enabled: true),
      AttendanceRuleChip(label: 'FOTO', enabled: true),
      AttendanceRuleChip(label: 'GPS', enabled: true),
      AttendanceInfoChip('Cooldown: 30s'),
      AttendanceInfoChip('Intervalo minimo: 5 min'),
      AttendanceInfoChip('Tolerancia: 10 min'),
      AttendanceInfoChip('Metodos: qr, gps'),
    ],
  );
}

_GoldenScenario _buildPendingErrorScenario({required double screenWidth}) {
  final now = DateTime(2026, 3, 18, 9, 30);
  final sessionColor = const Color(0xFFE8EEF7);
  final readiness = ClockReadinessSnapshot(
    warming: true,
    cameraGranted: true,
    locationGranted: true,
    locationServiceEnabled: false,
    checkedAt: DateTime(2026, 3, 18, 9, 18),
    gps: ClockGpsPoint(
      lat: -34.60370,
      lon: -58.38160,
      capturedAt: DateTime(2026, 3, 18, 9, 8),
    ),
  );
  final clockMetrics = ClockMetricsSnapshot(
    lastClockAt: DateTime(2026, 3, 17, 18, 40),
    lastClockTotalDuration: const Duration(seconds: 12),
    lastClockApiDuration: const Duration(seconds: 7),
    lastClockGpsDuration: const Duration(seconds: 3),
    sampleCount: 4,
    totalMs: 42000,
    apiMs: 22000,
    apiCount: 4,
  );
  final pendingQueue = PendingQueueState(
    snapshot: PendingClockSnapshot.fromRecords([
      OfflineClockRecord(
        id: 'ok-1',
        employeeId: 7,
        qrToken: 'qr-ok',
        eventAt: DateTime(2026, 3, 18, 8, 3),
        createdAt: DateTime(2026, 3, 18, 8, 3),
      ),
      OfflineClockRecord(
        id: 'failed-1',
        employeeId: 7,
        qrToken: 'qr-failed',
        eventAt: DateTime(2026, 3, 18, 8, 9),
        createdAt: DateTime(2026, 3, 18, 8, 9),
        status: OfflineClockStatus.failed,
        attempts: 2,
        lastError: 'Sin conectividad.',
      ),
    ]),
    lastSyncAt: DateTime(2026, 3, 18, 8, 55),
    lastMessage: 'Queda una fichada con error para revisar.',
  );

  return _buildScenario(
    screenWidth: screenWidth,
    now: now,
    syncText: 'Datos sincronizados hace 35 min',
    sessionBaseText: 'Sesion: renovando...',
    sessionMessage: 'Token en refresh',
    sessionColor: sessionColor,
    readiness: readiness,
    clockMetrics: clockMetrics,
    pendingQueue: pendingQueue,
    loadingConfig: true,
    hasFreshConfig: false,
    hasFreshGps: false,
    submitting: false,
    locatingGps: true,
    isBusy: true,
    phaseText: 'Guardando fichada offline...',
    lastQrText: 'EGRESO-PLANTA-017',
    ruleBadges: const [
      AttendanceRuleChip(label: 'QR', enabled: true),
      AttendanceRuleChip(label: 'FOTO', enabled: true),
      AttendanceRuleChip(label: 'GPS', enabled: true),
      AttendanceInfoChip('Cooldown: 30s'),
      AttendanceInfoChip('Intervalo minimo: 5 min'),
      AttendanceInfoChip('Tolerancia: 10 min'),
      AttendanceInfoChip('Metodos: qr, gps'),
    ],
  );
}

_GoldenScenario _buildScenario({
  required double screenWidth,
  required DateTime now,
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
  required bool submitting,
  required bool locatingGps,
  required bool isBusy,
  required String? phaseText,
  required String lastQrText,
  required List<Widget> ruleBadges,
}) {
  const viewDataBuilder = AttendanceHomeViewDataBuilder();
  const actionPresenter = AttendanceHomeActionPresenter();
  final viewData = viewDataBuilder.build(
    now: now,
    screenWidth: screenWidth,
    syncText: syncText,
    sessionBaseText: sessionBaseText,
    sessionMessage: sessionMessage,
    sessionColor: sessionColor,
    readiness: readiness,
    clockMetrics: clockMetrics,
    pendingQueue: pendingQueue,
    loadingConfig: loadingConfig,
    hasFreshConfig: hasFreshConfig,
    hasFreshGps: hasFreshGps,
    formatTimeOfDay: _formatTimeOfDay,
    formatRelative: (dateTime) => _formatRelative(now, dateTime),
    formatDuration: _formatDuration,
    isSameDay: _isSameDay,
  );
  final actions = actionPresenter.build(
    viewData: viewData,
    pendingQueue: pendingQueue,
    submitting: submitting,
    locatingGps: locatingGps,
    isBusy: isBusy,
  );
  return _GoldenScenario(
    viewData: viewData,
    actions: actions,
    pendingQueue: pendingQueue,
    clockMetrics: clockMetrics,
    readiness: readiness,
    sessionColor: sessionColor,
    phaseText: phaseText,
    lastQrText: lastQrText,
    ruleBadges: ruleBadges,
  );
}

class _GoldenScenario {
  const _GoldenScenario({
    required this.viewData,
    required this.actions,
    required this.pendingQueue,
    required this.clockMetrics,
    required this.readiness,
    required this.sessionColor,
    required this.phaseText,
    required this.lastQrText,
    required this.ruleBadges,
  });

  final AttendanceHomeViewData viewData;
  final AttendanceHomeActionViewData actions;
  final PendingQueueState pendingQueue;
  final ClockMetricsSnapshot clockMetrics;
  final ClockReadinessSnapshot readiness;
  final Color sessionColor;
  final String? phaseText;
  final String lastQrText;
  final List<Widget> ruleBadges;
}

String _formatTimeOfDay(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatRelative(DateTime now, DateTime dateTime) {
  final diff = now.difference(dateTime);
  if (diff.inMinutes < 60) {
    return 'hace ${diff.inMinutes} min';
  }
  return 'hace ${diff.inHours} h';
}

String _formatDuration(Duration duration) {
  return '${duration.inSeconds}s';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
