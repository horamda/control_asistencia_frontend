import 'dart:convert';

import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/horarios_page.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/horario_semanal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets('horarios por fecha, partidos y errores a $width px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dates = <String>[];
      var fail = true;
      final api = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          expect(request.url.path, '/api/v1/mobile/me/horario-esperado');
          final date = request.url.queryParameters['fecha']!;
          dates.add(date);
          switch (DateTime.parse(date).weekday) {
            case 1:
              return _json({
                'bloques': [
                  {'entrada': '08:00:00', 'salida': '16:00'},
                ],
              });
            case 2:
              return _json({
                'tiene_excepcion': true,
                'bloques': [
                  {'entrada': '09:00', 'salida': '12:00'},
                  {'entrada': '14:00', 'salida': '18:00'},
                ],
              });
            case 4:
              if (fail) return _json({'error': 'Servicio no disponible'}, 500);
              return _json({
                'bloques': [
                  {'entrada': '10:00', 'salida': '17:00'},
                ],
              });
            default:
              return _json({'error': 'sin horario esperado'}, 404);
          }
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HorarioSemanal(
                apiClient: api,
                token: 'token',
                initialDate: DateTime(2026, 9, 23),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(dates, [for (var i = 21; i <= 27; i++) '2026-09-$i']);
      expect(find.text('Entrada 08:00'), findsOneWidget);
      expect(find.text('Salida 16:00'), findsOneWidget);
      expect(find.text('Entrada 09:00'), findsOneWidget);
      expect(find.text('Entrada 14:00'), findsOneWidget);
      expect(find.text('Horario con excepción'), findsOneWidget);
      expect(find.text('Servicio no disponible'), findsOneWidget);
      expect(
        find.text('Sin horario previsto para esta fecha'),
        findsNWidgets(4),
      );
      expect(tester.takeException(), isNull);
      fail = false;
      await tester.ensureVisible(find.text('Reintentar horarios'));
      await tester.tap(find.text('Reintentar horarios'));
      await tester.pumpAndSettle();
      expect(find.text('Entrada 10:00'), findsOneWidget);
      expect(find.text('Servicio no disponible'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Semana siguiente'));
      await tester.tap(find.byTooltip('Semana siguiente'));
      await tester.pumpAndSettle();
      expect(dates.skip(14).first, '2026-09-28');
      expect(dates.last, '2026-10-04');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'la pantalla integra las horas y reconoce vigente con fecha de fin',
    (tester) async {
      final assignment = {
        'id': 1,
        'horario_id': 2,
        'horario_nombre': 'Entrega',
        'fecha_desde': '2026-07-17',
        'fecha_hasta': '2026-11-30',
      };
      final api = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/actual')) {
            return _json({
              'asignacion': assignment,
              'dias': [
                {'dia_semana': 1},
              ],
            });
          }
          if (request.url.path.endsWith('/horarios-asignaciones')) {
            return _json([assignment]);
          }
          return _json({
            'bloques': [
              {'entrada': '07:30', 'salida': '15:30'},
            ],
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HorariosPage(apiClient: api, token: 'token'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Entrada 07:30'), findsNWidgets(7));
      await tester.scrollUntilVisible(find.text('Vigente'), 400);
      expect(find.text('Vigente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
