import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/network/reuniones_models.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/home_reuniones_card.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Compact home meetings at 360px, scale $scale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var scans = 0, opens = 0;
      int? detail;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: HomeReunionesCard(
                  items: [
                    for (var id = 1; id <= 3; id++)
                      ReunionOccurrence({
                        'reunion_id': id,
                        'fecha': '2026-10-16',
                        'inicio': '2026-10-16T10:00:00',
                        'nombre': 'Reunión $id',
                        'estado': id == 3 ? 'abierta' : 'pendiente',
                      }),
                  ],
                  summary: const {
                    'reuniones': 3,
                    'pendientes': 2,
                    'registradas': 0,
                  },
                  onOpen: () => opens++,
                  onRetry: () {},
                  onDetail: (id) => detail = id,
                  onScan: () => scans++,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Reunión 3'), findsOneWidget);
      expect(find.text('Reunión 2'), findsNothing);
      if (scale == 1) {
        expect(
          tester.getSize(find.byType(HomeReunionesCard)).height,
          lessThan(300),
        );
      }
      await tester.tap(find.text('Reunión 3'));
      expect(detail, 3);
      await tester.tap(find.byTooltip('Escanear QR de reunión'));
      expect(scans, 1);
      await tester.tap(find.text('Ver agenda completa'));
      expect(opens, 1);
    });
  }
}
