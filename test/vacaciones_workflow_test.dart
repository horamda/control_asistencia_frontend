import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/vacaciones_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, dynamic> requestData({bool team = false, bool cancelled = false}) =>
    {
      'id': 12,
      'empleado': {'nombre': 'Empleado de prueba con apellido extenso'},
      'estado': 'aprobada',
      'dias': 7,
      'puede_cancelar': !team && !cancelled,
      'puede_resolver': team,
      'puede_resolver_cancelacion': false,
      'tandas': [
        {
          'movimiento_id': 18,
          'fecha_desde': '2026-11-24',
          'fecha_hasta': '2026-11-30',
          'dias': 7,
          'estado': 'aprobado',
          'inicio_corrido': true,
          'cancelacion_pedida': cancelled,
          'empezo': false,
        },
      ],
    };
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  bool dark = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    bool found = false;
    try {
      found = finder.evaluate().isNotEmpty;
    } catch (_) {}
    if (found) break;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Mi equipo: pendientes, calendario y saldos consultan sus rutas',
    (tester) async {
      final paths = <String>[];
      final api = MobileApiClient(
        baseUrl: 'https://test.invalid',
        httpClient: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('/calendario')) {
            return response({
              'alcance': 'equipo',
              'items': [
                {
                  ...((requestData()['tandas'] as List).first as Map),
                  'solicitud_id': 12,
                  'empleado': {'nombre': 'Empleado de prueba'},
                },
              ],
            });
          }
          if (r.url.path.endsWith('/saldos')) {
            return response({
              'alcance': 'equipo',
              'items': [
                {
                  'empleado': {'nombre': 'Empleado de prueba'},
                  'dias_disponibles': 14,
                  'semanas_disponibles': 2,
                  'dias_tomados': 7,
                  'dias_pendientes': 0,
                },
              ],
            });
          }
          return response({
            'alcance': 'equipo',
            'por_resolver': 1,
            'items': [requestData(team: true)],
          });
        }),
      );
      addTearDown(api.dispose);
      await pumpPage(
        tester,
        VacacionesPage(apiClient: api, token: 'test', team: true),
      );
      for (final view in ['Calendario', 'Saldos', 'Pendientes']) {
        await tapVisible(tester, find.text(view));
        expect(tester.takeException(), isNull);
      }
      expect(paths, contains('/api/v1/mobile/me/equipo/vacaciones/calendario'));
      expect(paths, contains('/api/v1/mobile/me/equipo/vacaciones/saldos'));
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'semanas: saldo, feriado, seleccion, rotacion y envio dark=$dark',
      (tester) async {
        Map? body;
        final api = MobileApiClient(
          baseUrl: 'https://test.invalid',
          httpClient: MockClient((r) async {
            expect(r.headers['Authorization'], 'Bearer test');
            if (r.method == 'POST') {
              body = jsonDecode(r.body) as Map;
              return response(requestData(), 201);
            }
            final year = r.url.queryParameters['anio'];
            return response({
              'anio': int.parse(year!),
              'saldo': {'semanas_disponibles': 1},
              'feriados_cargados': false,
              'semanas': [
                {
                  'lunes': '$year-11-23',
                  'inicio': '$year-11-24',
                  'fin': '$year-11-30',
                  'feriado_lunes': 'Feriado de prueba',
                  'estado': 'disponible',
                },
                {
                  'lunes': '$year-12-07',
                  'inicio': '$year-12-07',
                  'fin': '$year-12-13',
                  'estado': 'disponible',
                },
              ],
            });
          }),
        );
        addTearDown(api.dispose);
        await pumpPage(
          tester,
          VacationWeekPicker(api: api, token: 'test'),
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.byType(CheckboxListTile).first);
        await tester.binding.setSurfaceSize(const Size(800, 1024));
        await tester.pumpAndSettle();
        final second = tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile).at(1),
        );
        expect(second.onChanged, isNull);
        for (final size in [const Size(740, 360), const Size(800, 1024)]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
                .value,
            isTrue,
          );
        }
        await tapVisible(tester, find.text('Solicitar 1 semanas'));
        await tapVisible(tester, find.text('Enviar'));
        expect(body?['semanas'], ['${DateTime.now().year}-11-23']);
        expect(body!.containsKey('fecha_desde'), isFalse);
      },
    );
    testWidgets('aprobadas piden cancelacion sin desaparecer dark=$dark', (
      tester,
    ) async {
      var cancelled = false;
      final api = MobileApiClient(
        baseUrl: 'https://test.invalid',
        httpClient: MockClient((r) async {
          if (r.method == 'POST') {
            expect(
              r.url.path,
              '/api/v1/mobile/me/vacaciones/solicitudes/12/cancelar',
            );
            expect((jsonDecode(r.body) as Map)['movimiento_id'], 18);
            cancelled = true;
            return response({'cancelacion_pedida': 1, 'canceladas': 0});
          }
          return response(requestData(cancelled: cancelled));
        }),
      );
      addTearDown(api.dispose);
      await pumpPage(
        tester,
        VacationRequestPage(api: api, token: 'test', id: 12),
        dark: dark,
      );
      await tapVisible(tester, find.text('Pedir cancelación'));
      await tapVisible(tester, find.text('Confirmar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(find.text('Cancelación pendiente de aprobación'), findsOneWidget);
      expect(find.text('Pedir cancelación'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('jefe: motivo obligatorio y permiso validado por servidor', (
    tester,
  ) async {
    var posts = 0;
    final api = MobileApiClient(
      baseUrl: 'https://test.invalid',
      httpClient: MockClient((r) async {
        if (r.method == 'POST') {
          posts++;
          expect(r.url.path.endsWith('/rechazar'), isTrue);
          expect((jsonDecode(r.body) as Map)['motivo'], 'Sin cobertura');
          return response({'error': 'No es su jefe directo'}, 403);
        }
        return response(requestData(team: true));
      }),
    );
    addTearDown(api.dispose);
    await pumpPage(
      tester,
      VacationRequestPage(api: api, token: 'test', id: 12, team: true),
    );
    await tapVisible(tester, find.text('Rechazar'));
    await tapVisible(tester, find.text('Confirmar'));
    expect(posts, 0);
    expect(find.text('Ingresá el motivo'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Sin cobertura');
    await tapVisible(tester, find.text('Confirmar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(posts, 1);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(find.text('No es su jefe directo'), findsOneWidget);
  });
  testWidgets('cadena indirecta consulta sin botones de aprobacion', (
    tester,
  ) async {
    final d = requestData(team: true)..['puede_resolver'] = false;
    final api = MobileApiClient(
      baseUrl: 'https://test.invalid',
      httpClient: MockClient((r) async => response(d)),
    );
    addTearDown(api.dispose);
    await pumpPage(
      tester,
      VacationRequestPage(api: api, token: 'test', id: 12, team: true),
    );
    expect(find.text('Aprobar'), findsNothing);
    expect(find.text('Rechazar'), findsNothing);
    expect(find.text('Pedir cancelación'), findsNothing);
  });
}
