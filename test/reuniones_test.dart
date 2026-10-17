import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/network/reuniones_models.dart';
import 'package:ficharqr/src/core/reuniones/reunion_reminders.dart';
import 'package:ficharqr/src/presentation/attendance/reuniones_page.dart';
import 'package:ficharqr/src/presentation/attendance/qr_scan_page.dart';

Map<String, dynamic> occurrence({
  String state = 'pendiente',
  bool cancelled = false,
  String date = '2026-10-21',
  String start = '2026-10-21T09:00:00-03:00',
}) => {
  'reunion_id': 3,
  'nombre': 'Seguridad semanal',
  'fecha': date,
  'inicio': start,
  'fin': '${date}T09:45:00-03:00',
  'ventana_desde': '${date}T08:45:00-03:00',
  'estado': state,
  'cancelada': cancelled,
  'sucursal_nombre': 'Casa central',
  'lugar': 'Sala 1',
  'fecha_original': '2026-10-20',
  'motivo_cambio': 'Pospuesta del martes 20/10 por día no laborable.',
};

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'meetings never send synthetic offline credentials to the server',
    () async {
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) async {
          fail(
            'An offline session must not make authenticated meeting requests',
          );
        }),
      );
      await expectLater(
        api.getReuniones(token: 'offline_1'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.registrarReunion(token: 'offline_1', qr: 'fichaya://reunion?t=abc'),
        throwsA(isA<ApiException>()),
      );
    },
  );
  testWidgets(
    'meeting history fits narrow screens with enlarged text and long branch names',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/reuniones')) {
            return jsonResponse({
              'items': [
                {
                  'id': 3,
                  'nombre':
                      'Reunión de seguridad semanal en Casa Central de la empresa',
                },
              ],
            });
          }
          if (r.url.path.endsWith('/historial')) {
            return jsonResponse({
              'items': [
                {
                  ...occurrence(state: 'justificado'),
                  'inicio': '09:00',
                  'fin': '09:45',
                  'observaciones': 'Vacaciones autorizadas por RR. HH.',
                  'metodo': 'sistema',
                },
              ],
              'page': 1,
              'per_page': 20,
              'total': 1,
            });
          }
          return jsonResponse({'items': []});
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ReunionesPage(
            api: api,
            token: 'jwt',
            onClockQr: (_) async {},
            onChanged: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Historial'));
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('Justificado'), findsOneWidget);
    },
  );

  testWidgets(
    'duplicate registration dialog shows successful state and branch',
    (tester) async {
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => jsonResponse({
            'ya_registrado': true,
            'estado': 'tarde',
            'reunion': 'Seguridad',
            'sucursal_nombre': 'Norte',
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => registerReunionQr(
                  context,
                  api,
                  'jwt',
                  'fichaya://reunion?t=ok',
                ),
                child: const Text('Registrar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(find.text('Ya estabas registrado'), findsOneWidget);
      expect(find.textContaining('Norte'), findsOneWidget);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  test('meeting QR remains opaque; clock QR normalization is unchanged', () {
    const qr = 'fichaya://reunion?t=aaa.bbb.ccc&token=keep%2Bthis';
    expect(isReunionQr(qr), isTrue);
    expect(normalizeQrScanValue(qr), qr);
    expect(isReunionQr('fichaya://reunion-maliciosa?t=abc'), isFalse);
    expect(
      normalizeQrScanValue('https://example.test/?qr_token=aaa.bbb.ccc'),
      'aaa.bbb.ccc',
    );
  });

  test(
    'all six meeting routes use Bearer, filters and full QR without clock fields',
    () async {
      final requests = <http.Request>[];
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          requests.add(r);
          expect(r.headers['Authorization'], 'Bearer jwt');
          return jsonResponse(
            r.method == 'POST'
                ? {'estado': 'presente', 'ya_registrado': false}
                : {'items': []},
            r.method == 'POST' ? 201 : 200,
          );
        }),
      );
      await api.getReuniones(token: 'jwt');
      await api.getReuniones(
        token: 'jwt',
        path: '/proximas',
        query: {'dias': '7'},
      );
      await api.getReuniones(
        token: 'jwt',
        path: '/historial',
        query: {
          'desde': '2026-10-01',
          'hasta': '2026-10-21',
          'reunion_id': '3',
          'page': '2',
          'per': '20',
        },
      );
      await api.getReuniones(
        token: 'jwt',
        path: '/estadisticas',
        query: {'desde': '2026-10-01', 'hasta': '2026-10-21'},
      );
      await api.getReuniones(token: 'jwt', path: '/3');
      await api.registrarReunion(token: 'jwt', qr: 'fichaya://reunion?t=a%2Bb');
      expect(requests.map((r) => r.url.path), [
        '/api/v1/mobile/reuniones',
        '/api/v1/mobile/reuniones/proximas',
        '/api/v1/mobile/reuniones/historial',
        '/api/v1/mobile/reuniones/estadisticas',
        '/api/v1/mobile/reuniones/3',
        '/api/v1/mobile/reuniones/registrar',
      ]);
      expect(requests[2].url.queryParameters['page'], '2');
      expect(requests[2].url.queryParameters['reunion_id'], '3');
      expect(jsonDecode(requests.last.body), {
        'qr': 'fichaya://reunion?t=a%2Bb',
      });
    },
  );

  for (final status in [400, 403, 404, 409]) {
    test('registration preserves server error $status', () async {
      const message = 'Este QR es de la reunión en Norte. La tuya es en Sur.';
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => jsonResponse({'error': message}, status),
        ),
      );
      await expectLater(
        api.registrarReunion(token: 'jwt', qr: 'fichaya://reunion?t=expired'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', message)
              .having((e) => e.statusCode, 'status', status),
        ),
      );
    });
  }
  test('duplicate registration is successful', () async {
    final api = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => jsonResponse({'ya_registrado': true, 'estado': 'tarde'}),
      ),
    );
    expect(
      (await api.registrarReunion(
        token: 'jwt',
        qr: 'fichaya://reunion?t=ok',
      ))['ya_registrado'],
      true,
    );
  });

  test(
    'reminders use effective offset date, remove cancelled/registered/past and deduplicate',
    () {
      final item = ReunionOccurrence(occurrence());
      final planned = planReunionReminders([
        item,
        item,
        ReunionOccurrence(occurrence(state: 'presente')),
        ReunionOccurrence(occurrence(cancelled: true)),
        ReunionOccurrence(occurrence(state: 'abierta')),
        ReunionOccurrence(occurrence(start: '2026-10-19T09:00:00-03:00')),
      ], DateTime.utc(2026, 10, 20));
      expect(planned, hasLength(1));
      expect(planned.single.at.toUtc(), DateTime.utc(2026, 10, 21, 11, 30));
      expect(planned.single.id, ReunionReminder(item, DateTime.now()).id);
      expect(
        planReunionReminders([
          ReunionOccurrence(occurrence(state: 'cancelada')),
        ], DateTime.utc(2026, 10, 20)),
        isEmpty,
      );
      expect(reunionDateTime('2026-10-21T09:00:00-03:00'), '21/10/2026 09:00');
    },
  );

  test('automatic exits retain false default and null effectiveness', () {
    expect(AsistenciaItem.fromJson({'id': 1}).egresoAutomatico, false);
    expect(
      AsistenciaItem.fromJson({
        'id': 1,
        'egreso_automatico': true,
        'metodo_salida': 'automatico',
      }).egresoAutomatico,
      true,
    );
    expect(
      MarcaItem.fromJson({'id': 1, 'es_automatica': true}).esAutomatica,
      true,
    );
    expect(MarcaItem.fromJson({'id': 1}).esAutomatica, false);
    expect(
      FichajeEfectividad.fromJson({
        'jornadas': 0,
        'olvidos': 0,
        'efectividad_pct': null,
      }).efectividadPct,
      isNull,
    );
    expect(
      FichajeEfectividad.fromJson({
        'jornadas': 21,
        'olvidos': 2,
        'efectividad_pct': 90.5,
      }).efectividadPct,
      90.5,
    );
  });

  testWidgets(
    'upcoming card shows branch and postponement; cancelled date cannot scan',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReunionOccurrenceCard(
              item: ReunionOccurrence(
                occurrence(state: 'cancelada', cancelled: true),
              ),
              onScan: () {},
            ),
          ),
        ),
      );
      expect(find.text('Casa central · Sala 1'), findsOneWidget);
      expect(
        find.text('Pospuesta del martes 20/10 por día no laborable.'),
        findsOneWidget,
      );
      expect(find.text('Fecha original: 20/10/2026'), findsOneWidget);
      expect(find.text('Escanear QR'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'meeting page empty, error retry, history pagination and null stats',
    (tester) async {
      var fail = true;
      final historyPages = <String?>[];
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/proximas')) {
            if (fail) {
              return jsonResponse({'error': 'Reintentá más tarde'}, 409);
            }
            return jsonResponse({'items': []});
          }
          if (r.url.path.endsWith('/historial')) {
            historyPages.add(r.url.queryParameters['page']);
            return jsonResponse({
              'items': [],
              'page': int.parse(r.url.queryParameters['page']!),
              'per_page': 20,
              'total': 21,
            });
          }
          if (r.url.path.endsWith('/estadisticas')) {
            return jsonResponse({
              'totales': {'asistencia_pct': null, 'puntualidad_pct': null},
            });
          }
          return jsonResponse({'items': []});
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReunionesPage(
            api: api,
            token: 'jwt',
            onClockQr: (_) async {},
            onChanged: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reintentá más tarde'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('No hay reuniones para mostrar.'), findsOneWidget);
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(historyPages, ['1', '2']);
      await tester.tap(find.text('Estadísticas'));
      await tester.pumpAndSettle();
      expect(find.text('Sin datos'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
