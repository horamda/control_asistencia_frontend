import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/presentation/widgets/app_menu_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 568),
      const Size(740, 320),
      const Size(800, 1024),
    ]) {
      testWidgets('grouped menu returns selection $brightness $size', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Abrir'),
                  onPressed: () async {
                    selected = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const AppMenuPage<String>(
                          sections: {
                            'Mi actividad': [
                              AppMenuEntry(
                                'meetings',
                                Icons.groups,
                                'Mis reuniones',
                              ),
                            ],
                            'Configuracion': [
                              AppMenuEntry(
                                'camera',
                                Icons.camera,
                                'Camara y permisos del dispositivo',
                              ),
                            ],
                            'Sesion': [
                              AppMenuEntry(
                                'lock',
                                Icons.lock,
                                'Bloquear sesion',
                              ),
                            ],
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Bloquear sesion'), 150);
        await tester.ensureVisible(find.text('Bloquear sesion'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bloquear sesion'));
        await tester.pumpAndSettle();
        expect(selected, 'lock');
        expect(find.text('Abrir'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
