import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/skap_page.dart';

void main() {
  testWidgets('muestra roles propios y detalle sin editar ni ranking', (
    tester,
  ) async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      expect(request.headers['Authorization'], 'Bearer own-token');
      expect(request.url.queryParameters.containsKey('empleado_id'), isFalse);
      final Object data;
      if (request.url.path.endsWith('/matrices')) {
        data = {
          'items': [
            {
              'id': 1,
              'rol': 'Operario',
              'anio': 2026,
              'sucursal_nombre': 'Casa Central',
              'resumen': {'cumplimiento_pct': 80},
            },
            {
              'id': 2,
              'rol': 'Autoelevadorista',
              'anio': 2026,
              'sucursal_nombre': 'Casa Central',
              'resumen': {'cumplimiento_pct': null},
            },
          ],
        };
      } else {
        data = {
          'id': 1,
          'rol': 'Operario',
          'anio': 2026,
          'sucursal': 'Casa Central',
          'resumen': {
            'cumplimiento_pct': 80,
            'criticas': {'cumplimiento_pct': 75},
            'brechas': 1,
            'no_aplica': 1,
            'faltantes': 0,
          },
          'respuestas': [
            {
              'bloque': 'Seguridad',
              'competencia': 'Carga segura',
              'criticidad': 'A',
              'estandar': 3,
              'puntaje': 0,
              'estado': 'evaluado',
            },
            {
              'bloque': 'Seguridad',
              'competencia': 'Equipo especial',
              'criticidad': 'B',
              'estandar': 3,
              'puntaje': null,
              'estado': 'no_aplica',
            },
          ],
          'acciones': [],
        };
      }
      return http.Response(
        jsonEncode({'success': true, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: client,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SkapPage(apiClient: api, token: 'own-token'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Operario · 2026'), findsOneWidget);
    expect(find.text('Autoelevadorista · 2026'), findsOneWidget);
    expect(find.text('Ranking'), findsNothing);
    expect(requests, ['/api/skap/matrices']);
    await tester.tap(find.text('Operario · 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Carga segura'), findsOneWidget);
    expect(find.textContaining('Puntaje: 0'), findsOneWidget);
    expect(find.textContaining('Puntaje: No aplica'), findsOneWidget);
    expect(find.text('Editar acciones'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite reintentar un error sin revelar contenido ajeno', (
    tester,
  ) async {
    var calls = 0;
    final api = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: MockClient((request) async {
        calls++;
        return calls == 1
            ? http.Response('{"error":"Forbidden"}', 403)
            : http.Response('{"data":{"items":[]}}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SkapPage(apiClient: api, token: 'own-token'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Todavía no tenés evaluaciones cargadas.'),
      findsOneWidget,
    );
  });
}
