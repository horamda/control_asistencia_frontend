import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/legajo_evento_admin_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(740, 360),
    const Size(800, 1024),
    const Size(1366, 768),
    const Size(2560, 1440),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Legajo actions fit $size text $scale', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('permisos')
                  ? {'puede_cargar': true}
                  : request.url.path.endsWith('tipos')
                  ? {
                      'items': [
                        {
                          'id': 1,
                          'codigo': 'test',
                          'nombre': 'Evento de prueba',
                          'permite_adjuntos': true,
                        },
                      ],
                    }
                  : {'items': []},
            ),
            200,
          ),
        );
        addTearDown(client.close);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: LegajoEventoAdminPage(
              apiClient: MobileApiClient(
                baseUrl: 'https://example.test',
                httpClient: client,
              ),
              token: 'test',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Guardar evento');
        expect(save, findsOneWidget);
        expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        if (size.width >= 800) {
          expect(tester.getSize(save).width, lessThanOrEqualTo(320));
        }
        await tester.scrollUntilVisible(
          find.text('Agregar foto o archivo'),
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final attach = find.widgetWithText(
          OutlinedButton,
          'Agregar foto o archivo',
        );
        if (size.width >= 800) {
          expect(tester.getSize(attach).width, lessThanOrEqualTo(320));
        }
        // Framework reports any layout exceptions automatically.
      });
    }
  }
}
