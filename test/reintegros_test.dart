import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/reintegros/reintegros_helpers.dart';
import 'package:ficharqr/src/presentation/attendance/reintegros_page.dart';

const config = <String, dynamic>{
  'mensual': {
    'habilitado': true,
    'fecha_actual': '2026-10-08',
    'periodos_habilitados': ['2026-09', '2026-10'],
    'reaperturas': [],
  },
  'conceptos': [
    {'id': 1, 'nombre': 'Peajes'},
  ],
  'limites': {'gastos': 50},
  'recordatorios': [],
};
Map<String, dynamic> detail({int revision = 1}) => {
  'id': 45,
  'revision': revision,
  'periodo': '2026-09',
  'estado': 'borrador',
  'kilometros': null,
  'puede_editar_empleado': true,
  'fecha_cierre': '2026-10-15',
  'gastos': [],
  'historial': [],
  'advertencias': [],
  'total_solicitado': '0.00',
  'total_aprobado': '0.00',
};

void main() {
  testWidgets(
    'refresh rejects deactivated concept even in draft and preserves local data',
    (tester) async {
      final api = _Api();
      addTearDown(api.dispose);
      final original = detail()
        ..['gastos'] = [
          {
            'categoria_id': 1,
            'categoria_nombre': 'Peajes históricos',
            'concepto': 'Texto que no debe perderse',
            'importe': '25.00',
            'fotos': [],
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: ReintegroEditor(
            api: api,
            token: 'token',
            config: config,
            period: '2026-09',
            initial: original,
          ),
        ),
      );
      await tester.pumpAndSettle();
      api.catalogItems = [];
      await tester.scrollUntilVisible(
        find.text('Guardar borrador'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ReintegroEditor),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(api.saved, isEmpty);
      expect(
        find.textContaining('El concepto del gasto 1 ya no está disponible'),
        findsOneWidget,
      );
      expect(find.text('Texto que no debe perderse'), findsOneWidget);
      expect(find.text('Concepto: Peajes históricos'), findsOneWidget);
    },
  );
  testWidgets(
    'concept search uses compatible catalog alias and saves selected ID',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _Api()
        ..aliasCatalog = true
        ..catalogItems = [
          {'id': 2, 'nombre': 'Combustible', 'activo': 1},
          {'id': 3, 'nombre': 'Concepto inactivo', 'activo': 0},
        ];
      addTearDown(api.dispose);
      final original = detail()
        ..['gastos'] = [
          {'concepto': 'Prueba', 'fotos': []},
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReintegroEditor(
            api: api,
            token: 'token',
            config: config,
            period: '2026-09',
            initial: original,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Concepto: Seleccionar'));
      await tester.tap(find.text('Concepto: Seleccionar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Elegir concepto'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar concepto'),
        'comb',
      );
      await tester.pumpAndSettle();
      expect(find.text('Concepto inactivo'), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.text('Combustible')),
      );
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Cancelar')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.tap(find.text('Combustible'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Concepto: Combustible'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Guardar borrador'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ReintegroEditor),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(api.saved.single['gastos'][0]['categoria_id'], 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty concept dialog remains visible and can be cancelled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(499, 714));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _Api()..catalogItems = [];
    addTearDown(api.dispose);
    final original = detail()
      ..['gastos'] = [
        {'concepto': 'Prueba', 'fotos': []},
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ReintegroEditor(
          api: api,
          token: 'token',
          config: config,
          period: '2026-10',
          initial: original,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Concepto: Seleccionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concepto: Seleccionar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(
          'No hay conceptos disponibles. Contactá a Administración.',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Guardar borrador').hitTestable(), findsOneWidget);
    expect(find.text('Guardar borrador'), findsOneWidget);
  });

  test(
    'missing backend is distinguished from a CORS connection failure',
    () async {
      var calls = 0;
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          calls++;
          if (request.headers.containsKey('Authorization')) {
            throw http.ClientException('Failed to fetch');
          }
          expect(request.headers.containsKey('Content-Type'), isFalse);
          return http.Response('Not found', 404);
        }),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.getReintegros(token: 'token'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 404)
              .having(
                (e) => e.message,
                'message',
                contains('todavía no está disponible'),
              ),
        ),
      );
      expect(calls, 2);
    },
  );
  test('normalizes Argentina amounts exactly and rejects invalid amounts', () {
    expect(reintegroAmount('1.250,50'), '1250.50');
    expect(reintegroAmount('0,01'), '0.01');
    expect(reintegroAmount('1250.5'), '1250.50');
    expect(reintegroAmount(''), isNull);
    for (final input in [
      '0',
      '-1',
      '1e2',
      '1.234',
      '1000000000',
      '1,234',
      '1.25,00',
    ]) {
      expect(() => reintegroAmount(input), throwsFormatException);
    }
  });
  test('compresses JPEG and PNG receipts and rejects non-images', () {
    for (final input in [
      img.encodeJpg(img.Image(width: 2000, height: 10)),
      img.encodePng(img.Image(width: 12, height: 10)),
    ]) {
      final result = compressReintegroPhoto(input);
      expect(img.decodeJpg(result)!.width, lessThanOrEqualTo(1800));
      expect(result.length, lessThanOrEqualTo(2 * 1024 * 1024));
    }
    expect(
      () => compressReintegroPhoto(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
  test(
    'multipart retries preserve UUID, retained IDs and indexed JPEG fields',
    () async {
      final requests = <http.Request>[];
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          requests.add(r);
          return requests.length == 1
              ? http.Response('{"error":"expired"}', 401)
              : http.Response(jsonEncode(detail()), 200);
        }),
      );
      addTearDown(api.dispose);
      api.configureAuth(onUnauthorizedRefresh: (_) async => 'new');
      await api.saveReintegro(
        token: 'old',
        id: 45,
        data: {
          'envio_id': 'stable',
          'revision': 2,
          'periodo': '2026-09',
          'kilometros': null,
          'gastos': [
            {
              'importe': '1250.50',
              'fotos_existentes': [123],
            },
          ],
        },
        photos: {
          'fotos_0': [
            Uint8List.fromList([1, 2, 3]),
          ],
          'odometro': [
            Uint8List.fromList([4, 5]),
          ],
        },
      );
      expect(requests.map((r) => r.headers['Authorization']), [
        'Bearer old',
        'Bearer new',
      ]);
      for (final r in requests) {
        expect(r.method, 'PUT');
        expect(r.body, contains('stable'));
        expect(r.body, contains('fotos_existentes'));
        expect(r.body, contains('name="fotos_0"'));
        expect(r.body, contains('name="odometro"'));
        expect(r.body, contains('image/jpeg'));
      }
    },
  );
  test(
    'JSON keeps money as strings and private photos send bearer, never a query token',
    () async {
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer token');
          expect(r.url.query, isEmpty);
          if (r.method == 'POST') {
            expect((jsonDecode(r.body)['gastos'][0]['importe']), '0.01');
            return http.Response(jsonEncode({'solicitud': detail()}), 201);
          }
          expect(r.url.path, '/api/v1/mobile/reintegros/odometro/9');
          return http.Response('denied', 403);
        }),
      );
      addTearDown(api.dispose);
      await api.saveReintegro(
        token: 'token',
        data: {
          'gastos': [
            {'importe': '0.01'},
          ],
        },
      );
      await expectLater(
        api.getReintegroPhoto(token: 'token', id: 9, odometer: true),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    },
  );
  for (final size in [
    const Size(320, 640),
    const Size(740, 360),
    const Size(800, 1024),
    const Size(1280, 900),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'monthly list and editor fit $size $brightness with enlarged text',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final api = _Api();
          addTearDown(api.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: ReintegrosPage(api: api, token: 'token'),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cargar gastos'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Abrir 2026-09'),
            160,
            scrollable: find
                .descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Abrir 2026-09'));
          await tester.pumpAndSettle();
          expect(api.periodQueries, contains('2026-09'));
          await tester.ensureVisible(find.text('Agregar gasto (0/50)'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Agregar gasto (0/50)'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Guardar borrador'),
            300,
            scrollable: find
                .descendant(
                  of: find.byType(ReintegroEditor),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Guardar borrador'));
          await tester.pumpAndSettle();
          expect(api.saved.single['gastos'], [containsPair('importe', null)]);
          expect(find.text('Borrador'), findsOneWidget);
        },
      );
    }
  }
  testWidgets('sector disabled keeps history but offers no creation', (
    tester,
  ) async {
    final api = _Api()..disabled = true;
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReintegrosPage(api: api, token: 'token'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Abrir 2026-09'), findsNothing);
    expect(find.textContaining('Tu sector no está habilitado'), findsOneWidget);
    expect(find.text('Mis rendiciones'), findsOneWidget);
  });
  testWidgets('creation timeout retains UUID for identical retries', (
    tester,
  ) async {
    final api = _Api()..failSave = true;
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReintegroEditor(
          api: api,
          token: 'token',
          config: config,
          period: '2026-09',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guardar borrador'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ReintegroEditor),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    api.failSave = false;
    await tester.scrollUntilVisible(
      find.text('Guardar borrador'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ReintegroEditor),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    expect(api.saved[0]['envio_id'], api.saved[1]['envio_id']);
  });
  testWidgets(
    'PUT preserves photos and null kilometers; conflict blocks overwriting',
    (tester) async {
      final api = _Api()
        ..failSave = true
        ..revision = 2;
      addTearDown(api.dispose);
      final original = detail()
        ..['gastos'] = [
          {
            'fecha': '2026-09-01',
            'categoria_id': 1,
            'concepto': 'Peaje',
            'importe': '10.00',
            'fotos': [
              {'id': 123},
            ],
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: ReintegroEditor(
            api: api,
            token: 'token',
            config: config,
            period: '2026-09',
            initial: original,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Guardar borrador'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ReintegroEditor),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(api.saved.single['gastos'][0]['fotos_existentes'], [123]);
      expect(api.saved.single['kilometros'], isNull);
      expect(find.text('Consultar versión del servidor'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Guardar borrador'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ReintegroEditor),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Guardar borrador'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('existing month opens same request instead of creating another', (
    tester,
  ) async {
    final api = _Api()..existing = true;
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReintegrosPage(api: api, token: 'token'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cargar gastos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir 2026-09'));
    await tester.pumpAndSettle();
    expect(find.text('Editar rendición'), findsOneWidget);
    expect(find.byType(ReintegroEditor), findsNothing);
    expect(api.saved, isEmpty);
  });
  testWidgets('zero expenses can be sent after explicit confirmation', (
    tester,
  ) async {
    final api = _Api();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReintegroEditor(
          api: api,
          token: 'token',
          config: config,
          period: '2026-09',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kilómetros (opcional)'),
      '0',
    );
    await tester.scrollUntilVisible(
      find.text('Enviar rendición'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enviar rendición'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar rendición'));
    await tester.pumpAndSettle();
    expect(api.saved, isEmpty);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(api.saved.single['gastos'], isEmpty);
    expect(api.saved.single['kilometros'], 0);
    expect(api.saved.single['accion'], 'enviar');
  });
  testWidgets(
    'reminder read and cancellation use authenticated actions and revision',
    (tester) async {
      final api = _Api()
        ..existing = true
        ..withReminder = true;
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ReintegrosPage(api: api, token: 'token'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Marcar como leído'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Marcar como leído'));
      await tester.pumpAndSettle();
      expect(api.actions.first['path'], '/recordatorios/8/leido');
      await tester.tap(find.text('Cargar gastos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir 2026-09'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar rendición'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(api.actions.last['data'], {'accion': 'cancelar', 'revision': 1});
      expect(find.text('Cancelada'), findsOneWidget);
    },
  );
}

class _Api extends MobileApiClient {
  List<Map<String, dynamic>>? catalogItems;
  bool aliasCatalog = false;
  _Api() : super(baseUrl: 'https://example.test');
  bool disabled = false,
      failSave = false,
      existing = false,
      withReminder = false;
  int revision = 1;
  final saved = <Map<String, dynamic>>[];
  final periodQueries = <String>[];
  final actions = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> reintegroAction({
    required String token,
    required String path,
    required Map<String, dynamic> data,
  }) async {
    expect(token, 'token');
    actions.add({'path': path, 'data': data});
    return path.contains('recordatorios')
        ? {'ok': true}
        : (detail()
            ..['estado'] = 'cancelada'
            ..['puede_editar_empleado'] = false);
  }

  @override
  Future<Map<String, dynamic>> getReintegros({
    required String token,
    String path = '/config',
    Map<String, String>? query,
  }) async {
    if (path == '/config') {
      return {
        ...config,
        if (catalogItems != null)
          'conceptos': aliasCatalog ? null : catalogItems,
        if (aliasCatalog) 'categorias': catalogItems,
        if (withReminder)
          'recordatorios': [
            {'id': 8, 'periodo': '2026-09', 'mensaje': 'Completá tu rendición'},
          ],
        if (disabled)
          'mensual': {...config['mensual'] as Map, 'habilitado': false},
      };
    }
    if (path.startsWith('/solicitudes/')) return detail(revision: revision);
    if (query?['periodo'] != null) periodQueries.add(query!['periodo']!);
    return {
      'items': existing ? [detail()] : [],
      'total': existing ? 1 : 0,
      'per_page': 30,
      'total_solicitado': '0.00',
      'total_aprobado': '0.00',
    };
  }

  @override
  Future<Map<String, dynamic>> saveReintegro({
    required String token,
    int? id,
    required Map<String, dynamic> data,
    Map<String, List<Uint8List>> photos = const {},
  }) async {
    saved.add(jsonDecode(jsonEncode(data)) as Map<String, dynamic>);
    if (failSave) throw ApiException(message: 'Sin conexión');
    return id == null ? {'solicitud': detail()} : detail();
  }

  @override
  Future<Uint8List> getReintegroPhoto({
    required String token,
    required int id,
    bool odometer = false,
  }) async => img.encodeJpg(img.Image(width: 10, height: 10));
}
