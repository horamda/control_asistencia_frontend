import 'package:ficharqr/src/presentation/attendance/widgets/attendance_dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('attendance_dashboard_widgets', () {
    testWidgets('pending banner ejecuta acciones configuradas', (tester) async {
      var primaryCalls = 0;
      var secondaryCalls = 0;

      await tester.pumpWidget(
        _wrap(
          AttendancePendingBanner(
            hasErrors: true,
            pendingCleanCount: 2,
            failedCount: 1,
            lastSyncText: '09:45',
            statusMessage: 'Hay una ficha rechazada.',
            primaryAction: AttendanceActionButtonData(
              label: 'Abrir bandeja',
              icon: Icons.inbox_outlined,
              onPressed: () {
                primaryCalls += 1;
              },
            ),
            secondaryAction: AttendanceActionButtonData(
              label: 'Intentar sincronizar',
              icon: Icons.sync_alt_outlined,
              onPressed: () {
                secondaryCalls += 1;
              },
            ),
          ),
        ),
      );

      expect(find.text('Pendientes: 2 | Con error: 1'), findsOneWidget);
      expect(find.text('Ultima sincronizacion: 09:45'), findsOneWidget);
      expect(find.text('Hay una ficha rechazada.'), findsOneWidget);

      await tester.tap(find.text('Abrir bandeja'));
      await tester.pump();
      await tester.tap(find.text('Intentar sincronizar'));
      await tester.pump();

      expect(primaryCalls, 1);
      expect(secondaryCalls, 1);
    });

    testWidgets('clock panel muestra fase y dispara acciones', (tester) async {
      var mainCalls = 0;
      var gpsCalls = 0;
      var queueCalls = 0;

      await tester.pumpWidget(
        _wrap(
          AttendanceClockPanel(
            warming: true,
            readinessBadges: const [
              AttendanceReadinessBadgeData(text: 'Config lista', ready: true),
              AttendanceReadinessBadgeData(text: 'GPS fresco', ready: true),
            ],
            readinessSummary: 'Listo para fichar.',
            readinessCheckText: 'hace 30s',
            phaseText: 'Enviando fichada...',
            mainAction: AttendanceActionButtonData(
              label: 'Escanear QR y fichar',
              icon: Icons.qr_code_scanner_rounded,
              onPressed: () {
                mainCalls += 1;
              },
            ),
            secondaryActions: [
              AttendanceActionButtonData(
                label: 'Actualizar GPS',
                icon: Icons.my_location_outlined,
                onPressed: () {
                  gpsCalls += 1;
                },
              ),
              AttendanceActionButtonData(
                label: 'Bandeja offline',
                icon: Icons.inbox_outlined,
                onPressed: () {
                  queueCalls += 1;
                },
              ),
            ],
            gpsText: '-34.60370, -58.38160',
            lastQrText: 'qr-demo',
          ),
        ),
      );

      expect(find.text('Preparacion de fichada'), findsOneWidget);
      expect(find.text('Enviando fichada...'), findsOneWidget);
      expect(find.text('GPS: -34.60370, -58.38160'), findsOneWidget);
      expect(find.text('Ultimo QR: qr-demo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.tap(find.text('Escanear QR y fichar'));
      await tester.pump();
      await tester.tap(find.text('Actualizar GPS'));
      await tester.pump();
      await tester.tap(find.text('Bandeja offline'));
      await tester.pump();

      expect(mainCalls, 1);
      expect(gpsCalls, 1);
      expect(queueCalls, 1);
    });

    testWidgets('quick actions y diagnostico renderizan y responden', (
      tester,
    ) async {
      var enabledTapCalls = 0;

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              AttendanceQuickActionsCard(
                columns: 2,
                ratio: 2.5,
                items: [
                  AttendanceQuickActionItem(
                    icon: Icons.timeline_outlined,
                    label: 'Marcas',
                    onTap: () {
                      enabledTapCalls += 1;
                    },
                  ),
                  const AttendanceQuickActionItem(
                    icon: Icons.person_outline,
                    label: 'Mi perfil',
                  ),
                ],
              ),
              AttendanceDiagnosticsCard(
                ruleBadges: const [
                  AttendanceRuleChip(label: 'QR', enabled: true),
                  AttendanceInfoChip('Cooldown: 30s'),
                ],
                hasMetrics: true,
                sampleCount: 4,
                lastClockText: '09:50',
                lastTotalText: '7s',
                lastApiText: '3s',
                lastGpsText: '1s',
                lastPhotoText: '2s',
                averageTotalText: '6s',
                averageApiText: '2s',
                lastQrText: 'qr-demo',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Marcas'));
      await tester.pump();
      expect(enabledTapCalls, 1);

      await tester.tap(find.text('Diagnostico y reglas'));
      await tester.pumpAndSettle();

      expect(find.text('Rendimiento de fichada'), findsOneWidget);
      expect(find.text('Promedio total: 6s'), findsOneWidget);
      expect(find.text('Promedio API: 2s'), findsOneWidget);
      expect(find.text('Ultimo QR: qr-demo'), findsOneWidget);
      expect(find.text('QR: requerido'), findsOneWidget);
      expect(find.text('Cooldown: 30s'), findsOneWidget);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
