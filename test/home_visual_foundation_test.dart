import 'package:ficharqr/src/presentation/attendance/widgets/attendance_dashboard_widgets.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(360, 800),
      const Size(740, 360),
      const Size(800, 1024),
    ]) {
      testWidgets('home foundation $brightness $size scaled and actionable', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: brightness),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const AttendanceHeroCard(
                        photoUrl: '',
                        token: '',
                        greeting: 'Buenas tardes',
                        employeeName: 'Alejandra',
                        employeeDni: '12345678',
                      ),
                      const SizedBox(height: 12),
                      AttendanceStatusBanner(
                        pendingTotal: 3,
                        pendingFailed: 1,
                        lastClockText: '08:00',
                        hasClockToday: true,
                        hasFreshGps: true,
                        onTap: () => taps++,
                      ),
                      AttendanceQuickActionsCard(
                        items: [
                          AttendanceQuickActionItem(
                            icon: Icons.receipt_long,
                            label: 'Viaticos y reintegros',
                            onTap: () => taps++,
                          ),
                          AttendanceQuickActionItem(
                            icon: Icons.shield,
                            label: 'Seguridad e Higiene',
                            onTap: () => taps++,
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
        await tester.ensureVisible(find.text('Fichadas con error'));
        await tester.tap(find.text('Fichadas con error'));
        await tester.ensureVisible(find.text('Seguridad e Higiene'));
        await tester.tap(find.text('Seguridad e Higiene'));
        expect(taps, 2);
        expect(tester.takeException(), isNull);
        final tiles = find.descendant(
          of: find.byType(AttendanceQuickActionsCard),
          matching: find.byType(InkWell),
        );
        for (final element in tiles.evaluate()) {
          expect(
            tester.getSize(find.byWidget(element.widget)).height,
            greaterThanOrEqualTo(48),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
