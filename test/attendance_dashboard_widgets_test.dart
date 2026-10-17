import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/attendance_dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quick actions in the same row have equal height', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(468, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        AttendanceQuickActionsCard(
          items: [
            AttendanceQuickActionItem(
              icon: Icons.checkroom,
              label: 'EPP y vestimenta',
              onTap: () {},
            ),
            AttendanceQuickActionItem(
              icon: Icons.receipt,
              label: 'Viáticos y reintegros',
              onTap: () {},
            ),
            AttendanceQuickActionItem(
              icon: Icons.calendar_month,
              label: 'Asistencias',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    final tiles = find.descendant(
      of: find.byType(AttendanceQuickActionsCard),
      matching: find.byType(InkWell),
    );
    expect(tiles, findsNWidgets(3));
    final rects = [for (var i = 0; i < 3; i++) tester.getRect(tiles.at(i))];
    for (final rect in rects.skip(1)) {
      expect(rect.top, rects.first.top);
      expect(rect.height, rects.first.height);
    }
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 440.0, 1024.0]) {
    testWidgets('home cards fit $width with enlarged text', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const AttendanceHeroCard(
                      photoUrl: '',
                      token: 'test',
                      greeting: 'Buenos días',
                      employeeName: 'María Alejandra',
                      employeeDni: '12345678',
                      syncText: 'Datos actualizados',
                      sessionText: 'Sesión activa',
                      sessionColor: Colors.green,
                      sessionForeground: Colors.white,
                      gpsStatusText: 'Ubicación pendiente de validar',
                    ),
                    AttendanceQuickActionsCard(
                      items: [
                        AttendanceQuickActionItem(
                          icon: Icons.health_and_safety_rounded,
                          label: 'Seguridad e Higiene',
                          onTap: () => tapped = true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Seguridad e Higiene'));
      await tester.tap(find.text('Seguridad e Higiene'));
      await tester.pump();
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
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
              icon: Icons.inbox_rounded,
              onPressed: () {
                primaryCalls += 1;
              },
            ),
            secondaryAction: AttendanceActionButtonData(
              label: 'Intentar sincronizar',
              icon: Icons.sync_alt_rounded,
              onPressed: () {
                secondaryCalls += 1;
              },
            ),
          ),
        ),
      );

      expect(find.text('Pendientes: 2 | Con error: 1'), findsOneWidget);
      expect(find.text('Última sincronización: 09:45'), findsOneWidget);
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
                icon: Icons.my_location_rounded,
                onPressed: () {
                  gpsCalls += 1;
                },
              ),
              AttendanceActionButtonData(
                label: 'Bandeja offline',
                icon: Icons.inbox_rounded,
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

      expect(find.text('Preparación de fichada'), findsOneWidget);
      expect(find.text('Enviando fichada...'), findsOneWidget);
      expect(find.text('GPS: -34.60370, -58.38160'), findsOneWidget);
      expect(find.text('Último QR: qr-demo'), findsOneWidget);
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
                items: [
                  AttendanceQuickActionItem(
                    icon: Icons.timeline_rounded,
                    label: 'Marcas',
                    onTap: () {
                      enabledTapCalls += 1;
                    },
                  ),
                  const AttendanceQuickActionItem(
                    icon: Icons.person_rounded,
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

      await tester.tap(find.text('Diagnóstico y reglas'));
      await tester.pumpAndSettle();

      expect(find.text('Rendimiento de fichada'), findsOneWidget);
      expect(find.text('Promedio total: 6s'), findsOneWidget);
      expect(find.text('Promedio API: 2s'), findsOneWidget);
      expect(find.text('Último QR: qr-demo'), findsOneWidget);
      expect(find.text('QR: requerido'), findsOneWidget);
      expect(find.text('Cooldown: 30s'), findsOneWidget);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: child),
  );
}
