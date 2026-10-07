import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/cargas_page.dart';

void main() {
  for (final status in [200, 201]) {
    testWidgets('alta $status, historial, detalle y foto autenticada', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var posts = 0;
      var photos = 0;
      var details = 0;
      final row = {
        'id': 41,
        'registrado_at': '2026-09-29T07:58:21-03:00',
        'empleado_nombre': 'Ana',
        'legajo': '0010',
        'sucursal_empleado_nombre': 'Central histórica',
        'puesto_nombre': 'Chofer',
        'camion_numero': '01',
        'camion_patente': 'AAA',
        'sucursal_camion_nombre': 'Depósito histórico',
        'consolidado': '000123',
        'tipo': 'inicial',
        'valida': 0,
        'en_horario': 0,
        'observaciones': 'Faltante',
        'horario_nombre': 'Inicial histórica',
        'desde_minuto': 0,
        'hasta_minuto': 485,
        'fotos': [
          {'id': 9},
        ],
      };
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          final path = request.url.path;
          Object data;
          if (request.method == 'POST') {
            posts++;
            expect(path, '/api/v1/mobile/cargas');
            expect(request.body, contains('000123'));
            expect(request.body, contains('Faltante'));
            expect(request.body, contains('name="envio_id"'));
            expect(request.body, contains('false'));
            data = {'registro': row, 'repetido': status == 200};
          } else if (path.endsWith('/config')) {
            data = {
              'habilitado': true,
              'tiene_historial': posts > 0,
              'max_fotos': 2,
              'max_foto_bytes': 1024,
              'camiones': [
                {
                  'id': 1,
                  'numero': '01',
                  'patente': 'AAA',
                  'sucursal_id': 2,
                  'tiene_inicial': posts > 0 ? 1 : 0,
                },
              ],
              'horarios': [],
            };
          } else if (path.endsWith('/fotos/9')) {
            photos++;
            return http.Response.bytes(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
              ),
              200,
            );
          } else if (path.endsWith('/41')) {
            details++;
            data = row;
          } else {
            expect(request.url.queryParameters['page'], '1');
            data = {
              'items': posts > 0 ? [row] : [],
              'total': posts > 0 ? 1 : 0,
              'per_page': 30,
            };
          }
          return http.Response(
            jsonEncode(data),
            request.method == 'POST' ? status : 200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CargasPage(apiClient: api, token: 'token'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('01 · AAA').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '000123');
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'Faltante');
      await tester.tap(find.text('Registrar validación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(
        find.text(
          status == 200 ? 'Registro #41 ya recibido' : 'Registro #41 guardado',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Fuera de horario'), findsOneWidget);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.text('Mi historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camión 01 · 000123'));
      await tester.pumpAndSettle();
      expect(details, 1);
      expect(photos, 1);
      expect(
        find.textContaining('Sucursal del camión: Depósito histórico'),
        findsOneWidget,
      );
      expect(find.textContaining('Horario: Inicial histórica'), findsOneWidget);
      expect(find.textContaining('29/09/2026 07:58 (AR)'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
