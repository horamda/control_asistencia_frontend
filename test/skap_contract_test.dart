import 'dart:convert';

import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/skap_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response success(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets(
    'histórico sin evaluación explica las escalas y vuelve a matrices',
    (tester) async {
      final api = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: MockClient((request) async {
          expect(
            request.url.queryParameters.containsKey('empleado_id'),
            isFalse,
          );
          expect(request.url.queryParameters.containsKey('sector_id'), isFalse);
          if (request.url.path.endsWith('/mi_desarrollo')) {
            return success({
              'empleado': {'id': 1, 'nombre': 'Empleado'},
              'anio_evaluado': DateTime.now().year,
              'evaluacion': null,
              'categoria_cards': [],
              'historial': [],
              'plan': null,
            });
          }
          return success({'items': []});
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SkapPage(apiClient: api, token: 'token'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Histórico SKAP (escala 1–5)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sin evaluación histórica en ${DateTime.now().year}'),
        findsOneWidget,
      );
      expect(find.text('Evaluacion actual'), findsNothing);
      expect(find.text('No hay promedios disponibles.'), findsNothing);
      await tester.ensureVisible(find.text('Ver mis matrices operativas'));
      await tester.tap(find.text('Ver mis matrices operativas'));
      await tester.pumpAndSettle();
      expect(find.text('Mis evaluaciones por rol'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('matrices permite filtrar por año sin seleccionar empleado', () async {
    final api = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/skap/matrices');
        expect(request.url.queryParameters, {'anio': '2025'});
        expect(request.headers['Authorization'], 'Bearer token');
        return success({'items': []});
      }),
    );
    expect(await api.getSkapMatrices(token: 'token', anio: 2025), isEmpty);
  });

  testWidgets('conserva parciales, cero y brechas sin acciones', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final summary = {
      'cumplimiento_pct': null,
      'parcial_pct': 50,
      'evaluadas': 1,
      'faltantes': 1,
      'brechas': 1,
      'no_aplica': 0,
      'acreditado': 2,
      'esperado': 4,
      'criticidad_sin_definir': 1,
      'criticas': {'cumplimiento_pct': null, 'parcial_pct': 0},
      'bloques': {
        'Operación': {'cumplimiento_pct': 0, 'evaluadas': 1},
      },
    };
    final api = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: MockClient((request) async {
        final row = {
          'id': 1,
          'rol': 'Operario',
          'anio': 2025,
          'resumen': summary,
        };
        return success(
          request.url.path.endsWith('/matrices')
              ? {
                  'items': [row],
                }
              : {
                  ...row,
                  'respuestas': [
                    {
                      'bloque': 'Operación',
                      'competencia': 'Carga',
                      'estado': 'sin_evaluar',
                      'estandar': 4,
                    },
                  ],
                  'acciones': [],
                },
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SkapPage(apiClient: api, token: 'token'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Resultado incompleto · Parcial: 50.00 %'),
      findsOneWidget,
    );
    await tester.tap(find.text('Operario · 2025'));
    await tester.pumpAndSettle();
    expect(
      find.text('Resultado incompleto · Parcial: 50.00 %'),
      findsOneWidget,
    );
    expect(find.text('Resultado incompleto · Parcial: 0.00 %'), findsOneWidget);
    expect(find.text('Cumplimiento: 0.00 %'), findsOneWidget);
    expect(find.text('Puntaje acreditado: 2 / 4'), findsOneWidget);
    expect(find.textContaining('Puntaje: Sin evaluar'), findsOneWidget);
    expect(
      find.text('Todavía no hay acciones de desarrollo cargadas.'),
      findsOneWidget,
    );
    expect(find.textContaining('No se detectaron brechas'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
