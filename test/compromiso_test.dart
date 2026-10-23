import 'dart:convert';

import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/compromiso_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _respuesta({int anio = 2026}) => {
  'anio': anio,
  'anios_disponibles': [2026, 2025],
  'area': {
    'nombre': 'Entrega',
    'indice': anio == 2026 ? 72.0 : 60.0,
    'calculado': false,
    'anterior': 60.0,
    'variacion': 12.0,
  },
  'sucursal': {
    'nombre': 'Casa Central',
    'indice': 76.0,
    'calculado': true,
    'anterior': 79.5,
    'variacion': -3.5,
  },
  'empresa': {
    'nombre': 'Empresa',
    'indice': 67.3,
    'calculado': true,
    'anterior': null,
    'variacion': null,
  },
};

const _sinDatos = {
  'anio': 2026,
  'anios_disponibles': <int>[],
  'area': {'nombre': 'Entrega', 'indice': null},
  'sucursal': {'nombre': 'Casa Central', 'indice': null},
  'empresa': {'nombre': 'Empresa', 'indice': null},
};

MobileApiClient _api(
  List<http.Request> pedidos,
  http.Response Function(http.Request) responder,
) => MobileApiClient(
  baseUrl: 'https://example.com',
  httpClient: MockClient((request) async {
    pedidos.add(request);
    return responder(request);
  }),
);

Future<void> _abrir(WidgetTester tester, MobileApiClient api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: CompromisoPage(apiClient: api, token: 'jwt'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CompromisoResponse', () {
    test('lee los tres niveles y tolera datos faltantes', () {
      final r = CompromisoResponse.fromJson(_respuesta());
      expect(r.anio, 2026);
      expect(r.aniosDisponibles, [2026, 2025]);
      expect(r.area.indice, 72.0);
      expect(r.sucursal.calculado, isTrue);
      expect(r.sucursal.variacion, -3.5);
      expect(r.empresa.anterior, isNull);
      expect(r.sinDatos, isFalse);
      final vacio = CompromisoResponse.fromJson({'area': 'basura'});
      expect(vacio.area.nombre, 'Mi área');
      expect(vacio.sinDatos, isTrue);
      expect(vacio.aniosDisponibles, isEmpty);
    });
  });

  test('getCompromiso pide /me/compromiso con el año y el token', () async {
    final pedidos = <http.Request>[];
    final api = _api(
      pedidos,
      (_) => http.Response(jsonEncode(_respuesta()), 200),
    );
    await api.getCompromiso(token: 'jwt');
    await api.getCompromiso(token: 'jwt', anio: 2025);
    expect(pedidos.map((p) => p.url.path), [
      '/api/v1/mobile/me/compromiso',
      '/api/v1/mobile/me/compromiso',
    ]);
    expect(pedidos[0].url.queryParameters, isEmpty);
    expect(pedidos[1].url.queryParameters, {'anio': '2025'});
    expect(pedidos[0].headers['Authorization'], 'Bearer jwt');
    final error = _api(
      pedidos,
      (_) => http.Response(jsonEncode({'error': 'Ano invalido.'}), 400),
    );
    expect(
      () => error.getCompromiso(token: 'jwt', anio: 1),
      throwsA(isA<ApiException>()),
    );
  });

  testWidgets('muestra área, sucursal y empresa con la variación', (
    tester,
  ) async {
    final pedidos = <http.Request>[];
    await _abrir(
      tester,
      _api(pedidos, (_) => http.Response(jsonEncode(_respuesta()), 200)),
    );
    expect(find.text('Mi área'), findsOneWidget);
    expect(find.text('Entrega'), findsOneWidget);
    expect(find.text('72.0%'), findsOneWidget);
    expect(find.text('76.0%'), findsOneWidget);
    expect(find.text('67.3%'), findsOneWidget);
    expect(find.textContaining('+12.0 puntos'), findsOneWidget);
    expect(find.textContaining('-3.5 puntos'), findsOneWidget);
    expect(find.text('Promedio de las áreas'), findsNWidgets(2));
    expect(find.text('Sin dato del año anterior'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
  });

  testWidgets('elegir otro año vuelve a pedir con ese año', (tester) async {
    final pedidos = <http.Request>[];
    await _abrir(
      tester,
      _api(pedidos, (request) {
        final anio = int.tryParse(request.url.queryParameters['anio'] ?? '');
        return http.Response(jsonEncode(_respuesta(anio: anio ?? 2026)), 200);
      }),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '2025'));
    await tester.pumpAndSettle();
    expect(pedidos.last.url.queryParameters, {'anio': '2025'});
    expect(find.text('60.0%'), findsWidgets);
  });

  testWidgets('sin datos lo dice en vez de mostrar ceros', (tester) async {
    await _abrir(
      tester,
      _api([], (_) => http.Response(jsonEncode(_sinDatos), 200)),
    );
    expect(find.text('Todavía no hay datos'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('error con reintento', (tester) async {
    await _abrir(
      tester,
      _api([], (_) => http.Response(jsonEncode({'error': 'No se pudo.'}), 500)),
    );
    expect(find.text('No se pudo.'), findsOneWidget);
  });

  testWidgets('entra en un celular angosto con letra grande', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: MaterialApp(
          theme: buildAppTheme(),
          home: CompromisoPage(
            apiClient: _api(
              [],
              (_) => http.Response(jsonEncode(_respuesta()), 200),
            ),
            token: 'jwt',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('72.0%'), findsOneWidget);
  });
}
