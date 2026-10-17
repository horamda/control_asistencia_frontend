import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/epp_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

Map<String, dynamic> config({bool active = true}) => {
  'max_items': 50,
  'conceptos_reposicion': [
    {'id': 3, 'nombre': 'Desgaste', 'activo': 1},
  ],
  'articulos': [
    if (active)
      {
        'id': 1,
        'nombre': 'Campera impermeable para trabajo exterior',
        'categoria': 'Vestimenta',
        'descripcion': 'Medí el contorno de pecho.',
        'activo': 1,
        'talles': ['M', 'XL'],
        'tiene_imagen': 0,
        'aviso_anual': 2,
      },
  ],
  'talles': [
    {'articulo_id': 1, 'talle': 'XL', 'medidas': 'Pecho: 110 cm'},
  ],
};
Map<String, dynamic> order({String state = 'pendiente'}) => {
  'id': 12,
  'revision': 3,
  'concepto_reposicion_id': 9,
  'concepto_reposicion': 'Concepto histórico',
  'estado': state,
  'motivo': 'Reposición por desgaste',
  'creado_at': '2026-10-08T23:30:05-03:00',
  'items': [
    {
      'articulo_id': 1,
      'nombre': 'Campera impermeable para trabajo exterior',
      'talle': 'XL',
      'cantidad': 3,
      'aprobada': 2,
      'entregada': 1,
      'medidas': 'Pecho: 110 cm',
    },
  ],
  'entregas': [
    {'id': 4, 'fecha': '2026-10-08', 'firmada': 0, 'anulada': 1},
  ],
  'historial': [
    {'accion': 'crear', 'creado_at': '2026-10-08'},
  ],
};

class Server {
  bool active = true, failCreate = false, conflict = false;
  String state = 'pendiente';
  bool omitCatalogSizes = false;
  bool failSizes = false;
  final requests = <http.Request>[];
  late final MobileApiClient api = MobileApiClient(
    baseUrl: 'https://example.test',
    httpClient: MockClient((r) async {
      requests.add(r);
      expect(r.headers['authorization'], 'Bearer test');
      final path = r.url.path;
      Object response = {};
      var status = 200;
      if (path.endsWith('/config')) {
        response = config(active: active);
        if (omitCatalogSizes) (response as Map).remove('talles');
      } else if (path.endsWith('/talles')) {
        status = failSizes ? 503 : 200;
        response = failSizes
            ? {'error': 'No se pudieron consultar tus talles'}
            : {'items': config()['talles']};
      } else if (path.endsWith('/acciones')) {
        response = order(state: 'cancelado');
      } else if (path.endsWith('/pedidos') && r.method == 'GET') {
        response = {
          'items': [order(state: state)],
          'page': 1,
          'per_page': 30,
          'total': 1,
        };
      } else if (path.endsWith('/pedidos') && r.method == 'POST') {
        status = failCreate ? 503 : 201;
        response = failCreate
            ? {'error': 'Servicio temporalmente no disponible'}
            : {'pedido': order(), 'repetido': false};
      } else if (path.endsWith('/pedidos/12')) {
        status = r.method == 'PUT' && conflict ? 409 : 200;
        response = status == 409
            ? {'error': 'Revisión desactualizada'}
            : order(state: state);
      } else if (path.endsWith('/resumen')) {
        response = {
          'anio': 2026,
          'items': [
            {'nombre': 'Campera', 'talle': 'XL', 'medidas': '', 'cantidad': 1},
          ],
        };
      } else if (path.contains('/imagenes/') || path.endsWith('/pdf')) {
        return http.Response.bytes([1, 2, 3], 200);
      }
      return http.Response(
        jsonEncode(response),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

Future<void> pump(
  WidgetTester t,
  Server s, {
  Size size = const Size(800, 1100),
  double scale = 1,
}) async {
  await t.binding.setSurfaceSize(size);
  addTearDown(() => t.binding.setSurfaceSize(null));
  addTearDown(s.api.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: EppPage(api: s.api, token: 'test'),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String label) async {
  await t.pumpAndSettle();
  final finder = find.text(label);
  if (finder.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      finder,
      240,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 40,
    );
  }
  await Scrollable.ensureVisible(t.element(finder.last), alignment: .5);
  await t.pumpAndSettle();
  await t.tap(finder.last);
  await t.pumpAndSettle();
}

Future<void> editor(WidgetTester t) async {
  await tap(t, 'Solicitar EPP');
  await t.scrollUntilVisible(
    find.widgetWithText(TextField, 'Motivo del pedido'),
    150,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.enterText(find.byType(TextField).first, 'Reposición por desgaste');
  await tap(t, 'Agregar artículo');
  await tap(t, 'Campera impermeable para trabajo exterior');
}

void main() {
  for (final clear in [false, true]) {
    testWidgets(
      'editing keeps historical concept unless explicitly cleared: $clear',
      (t) async {
        final s = Server();
        await pump(t, s);
        await tap(t, 'Mis pedidos');
        await tap(t, 'Pedido #12');
        expect(
          find.text('Concepto de reposición: Concepto histórico'),
          findsOneWidget,
        );
        await tap(t, 'Editar pedido');
        expect(find.text('Concepto histórico (inactivo)'), findsOneWidget);
        if (clear) {
          await t.ensureVisible(find.byType(DropdownButtonFormField<int>));
          await t.tap(find.byType(DropdownButtonFormField<int>));
          await t.pumpAndSettle();
          await t.tap(find.text('Sin concepto').last);
          await t.pumpAndSettle();
        }
        await tap(t, 'Confirmo que este es mi talle');
        await tap(t, 'Enviar solicitud');
        final body =
            jsonDecode(s.requests.lastWhere((r) => r.method == 'PUT').body)
                as Map;
        expect(body.containsKey('concepto_reposicion_id'), clear);
        if (clear) expect(body['concepto_reposicion_id'], isNull);
      },
    );
  }
  testWidgets('selected replacement concept is included in draft', (t) async {
    final s = Server();
    await pump(t, s);
    await editor(t);
    await t.scrollUntilVisible(
      find.byType(DropdownButtonFormField<int>),
      -200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.tap(find.byType(DropdownButtonFormField<int>));
    await t.pumpAndSettle();
    await t.tap(find.text('Desgaste').last);
    await t.pumpAndSettle();
    await tap(t, 'Guardar borrador');
    final payload = jsonDecode(
      s.requests.lastWhere((r) => r.method == 'POST').body,
    );
    expect(payload['concepto_reposicion_id'], 3);
  });
  testWidgets('size lookup failure is shown as an error and can be retried', (
    t,
  ) async {
    final s = Server()..failSizes = true;
    await pump(t, s);
    expect(find.text('No se pudieron consultar tus talles'), findsOneWidget);
    expect(find.textContaining('No tenés un talle habitual'), findsNothing);
    s.failSizes = false;
    await t.tap(find.byTooltip('Actualizar'));
    await t.pumpAndSettle();
    await editor(t);
    expect(find.text('Tu talle guardado: XL'), findsOneWidget);
  });
  testWidgets('editor retrieves saved size even when catalog omits sizes', (
    t,
  ) async {
    final s = Server()..omitCatalogSizes = true;
    await pump(t, s);
    await editor(t);
    expect(find.text('Tu talle guardado: XL'), findsOneWidget);
    expect(find.text('Talle para este pedido: XL'), findsOneWidget);
    expect(
      s.requests.any(
        (r) => r.method == 'GET' && r.url.path.endsWith('/talles'),
      ),
      isTrue,
    );
  });
  testWidgets(
    'saved size is visible and changing it only updates usual size explicitly',
    (t) async {
      final s = Server();
      await pump(t, s);
      await editor(t);
      expect(find.text('Tu talle guardado: XL'), findsOneWidget);
      expect(find.text('Talle para este pedido: XL'), findsOneWidget);
      await tap(t, 'Cambiar talle');
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('M').last);
      await t.pumpAndSettle();
      expect(s.requests.where((r) => r.method == 'PUT'), isEmpty);
      await tap(t, 'Guardar como mi talle habitual');
      final request = s.requests.lastWhere((r) => r.method == 'PUT');
      expect(request.url.path, endsWith('/talles'));
      expect(jsonDecode(request.body), {
        'articulo_id': 1,
        'talle': 'M',
        'medidas': 'Pecho: 110 cm',
      });
      expect(find.text('Tu talle guardado: M'), findsOneWidget);
      expect(find.text('Talle habitual y medidas guardados.'), findsOneWidget);
    },
  );
  testWidgets('orders show readable dates and hide unnecessary pagination', (
    t,
  ) async {
    final s = Server();
    await pump(t, s, size: const Size(498, 706));
    await tap(t, 'Mis pedidos');
    expect(find.text('Tus pedidos'), findsOneWidget);
    expect(find.text('Pedido #12'), findsOneWidget);
    expect(find.text('Pendiente de aprobación'), findsOneWidget);
    expect(find.text('Solicitado el 08/10/2026'), findsOneWidget);
    expect(find.text('1 pedido'), findsOneWidget);
    expect(find.text('Anterior'), findsNothing);
    expect(find.text('Siguiente'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'quantity validation applies to drafts and valid draft is sent explicitly',
    (t) async {
      final s = Server();
      await pump(t, s);
      await editor(t);
      final quantity = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Cantidad (1 a 1000)',
      );
      await t.enterText(quantity, '1001');
      await tap(t, 'Guardar borrador');
      expect(s.requests.where((r) => r.method == 'POST'), isEmpty);
      expect(find.textContaining('debe ser un entero'), findsOneWidget);
      await t.ensureVisible(quantity);
      await t.enterText(quantity, '2');
      await tap(t, 'Guardar borrador');
      final payload = jsonDecode(
        s.requests.lastWhere((r) => r.method == 'POST').body,
      );
      expect(payload['accion'], 'borrador');
      expect(payload['items'][0]['cantidad'], 2);
    },
  );
  test('API sends Bearer and revision, and downloads private bytes', () async {
    final s = Server();
    addTearDown(s.api.dispose);
    await s.api.getEpp(
      token: 'test',
      path: '/pedidos',
      query: {'page': '2', 'estado': 'parcial'},
    );
    expect(s.requests.last.url.queryParameters, {
      'page': '2',
      'estado': 'parcial',
    });
    await s.api.writeEpp(
      token: 'test',
      path: '/pedidos/12',
      put: true,
      data: {'revision': 3, 'items': [], 'motivo': 'Test'},
    );
    expect(s.requests.last.method, 'PUT');
    expect(jsonDecode(s.requests.last.body)['revision'], 3);
    expect(await s.api.getEppFile(token: 'test', path: '/entregas/4/pdf'), [
      1,
      2,
      3,
    ]);
    expect(s.requests.last.url.query, isEmpty);
    await s.api.getEppFile(token: 'test', path: '/imagenes/articulos/1');
    await s.api.getEppFile(token: 'test', path: '/imagenes/firmas/4');
  });

  testWidgets(
    'saved size requires confirmation; retry preserves UUID and body',
    (t) async {
      final s = Server()..failCreate = true;
      await pump(t, s);
      await editor(t);
      await tap(t, 'Enviar solicitud');
      expect(
        find.text(
          'Confirmá el talle de Campera impermeable para trabajo exterior.',
        ),
        findsOneWidget,
      );
      expect(s.requests.where((r) => r.method == 'POST'), isEmpty);
      await tap(t, 'Confirmo que este es mi talle');
      await tap(t, 'Enviar solicitud');
      final first = s.requests.lastWhere((r) => r.method == 'POST').body;
      final payload = jsonDecode(first);
      expect(payload['items'][0]['talle'], 'XL');
      expect(payload['envio_id'], matches(RegExp(r'^[a-f0-9-]{36}$')));
      s.failCreate = false;
      await tap(t, 'Reintentar mismo envío');
      expect(s.requests.lastWhere((r) => r.method == 'POST').body, first);
      expect(find.text('Elegí tus talles'), findsOneWidget);
    },
  );

  testWidgets('catalog refresh rejects unavailable article and retains form', (
    t,
  ) async {
    final s = Server();
    await pump(t, s);
    await editor(t);
    await tap(t, 'Confirmo que este es mi talle');
    s.active = false;
    await tap(t, 'Guardar borrador');
    expect(find.textContaining('ya no está habilitado'), findsOneWidget);
    expect(s.requests.where((r) => r.method == 'POST'), isEmpty);
    expect(
      find.widgetWithText(TextField, 'Reposición por desgaste'),
      findsOneWidget,
    );
  });

  testWidgets(
    'edit sends complete lines and revision; conflict blocks overwrite',
    (t) async {
      final s = Server()..conflict = true;
      await pump(t, s);
      await tap(t, 'Mis pedidos');
      await tap(t, 'Pedido #12');
      await tap(t, 'Editar pedido');
      await tap(t, 'Confirmo que este es mi talle');
      await tap(t, 'Enviar solicitud');
      final data = jsonDecode(
        s.requests.lastWhere((r) => r.method == 'PUT').body,
      );
      expect(data['revision'], 3);
      expect(data['items'], hasLength(1));
      expect(data['items'][0]['cantidad'], 3);
      expect(find.text('Consultar estado actual'), findsOneWidget);
      expect(find.text('Enviar solicitud'), findsNothing);
    },
  );

  testWidgets(
    'approved order is read-only and exposes delivery and separate totals',
    (t) async {
      final s = Server()..state = 'aprobado';
      await pump(t, s);
      await tap(t, 'Mis pedidos');
      await tap(t, 'Pedido #12');
      expect(find.text('Editar pedido'), findsNothing);
      expect(find.text('Cancelar pedido'), findsNothing);
      expect(find.text('Solicitadas'), findsOneWidget);
      expect(find.text('Aprobadas'), findsOneWidget);
      expect(find.text('Entregadas'), findsOneWidget);
      await tap(t, 'Entregas y constancias');
      expect(find.text('Anulada · No suma en los totales'), findsOneWidget);
    },
  );

  testWidgets('cancellation requires reason and current revision', (t) async {
    final s = Server();
    await pump(t, s);
    await tap(t, 'Mis pedidos');
    await tap(t, 'Pedido #12');
    await tap(t, 'Cancelar pedido');
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar cancelación'),
          )
          .onPressed,
      isNull,
    );
    await t.enterText(find.byType(TextField), 'Ya no lo necesito');
    await tap(t, 'Confirmar cancelación');
    final data = jsonDecode(
      s.requests.lastWhere((r) => r.url.path.endsWith('/acciones')).body,
    );
    expect(data, {
      'accion': 'cancelar',
      'revision': 3,
      'motivo': 'Ya no lo necesito',
    });
    expect(find.text('Cancelado'), findsOneWidget);
  });

  testWidgets('save and remove personal size', (t) async {
    final s = Server();
    await pump(t, s);
    await tap(t, 'Configurar talle');
    await tap(t, 'Guardar');
    expect(jsonDecode(s.requests.lastWhere((r) => r.method == 'PUT').body), {
      'articulo_id': 1,
      'talle': 'XL',
      'medidas': 'Pecho: 110 cm',
    });
    await tap(t, 'Configurar talle');
    await tap(t, 'Quitar talle');
    expect(jsonDecode(s.requests.lastWhere((r) => r.method == 'PUT').body), {
      'articulo_id': 1,
      'eliminar': true,
    });
  });

  for (final size in [
    const Size(320, 740),
    const Size(740, 360),
    const Size(800, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'catalog, order editor, detail and summary fit $size with large text',
      (t) async {
        final s = Server();
        await pump(t, s, size: size, scale: 1.8);
        expect(t.takeException(), isNull);
        await editor(t);
        expect(t.takeException(), isNull);
        await tap(t, 'Guardar borrador');
        expect(t.takeException(), isNull);
        expect(find.text('Elegí tus talles'), findsOneWidget);
        await tap(t, 'Mis pedidos');
        await tap(t, 'Pedido #12');
        await t.drag(find.byType(Scrollable).last, const Offset(0, -500));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pageBack();
        await t.pumpAndSettle();
        await tap(t, 'Resumen anual');
        expect(t.takeException(), isNull);
        await t.scrollUntilVisible(
          find.text('1 entregadas'),
          160,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(t.takeException(), isNull);
        expect(find.text('1 entregadas'), findsOneWidget);
      },
    );
  }
}
