import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/branch_safety_card.dart';

Map<String, dynamic> data({
  int? days = 128,
  bool available = true,
  String? reason,
  String? date,
}) => {
  'hasta': date ?? DateTime.now().toIso8601String().substring(0, 10),
  'sucursal_id': 7,
  'sucursal_nombre': 'Sucursal Central',
  'alcances': {
    'empresa': {'disponible': true, 'dias_sin_accidentes': 999},
    'propio': {'disponible': true, 'dias_sin_accidentes': 777},
    'sucursal': {
      'disponible': available,
      'dias_sin_accidentes': days,
      'motivo': reason,
    },
  },
};

void main() {
  testWidgets('deduplicates requests, caches briefly and isolates sessions', (
    t,
  ) async {
    var calls = 0;
    var response = Completer<http.Response>();
    final key = GlobalKey<BranchSafetyCardState>();
    final api = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) {
        calls++;
        return response.future;
      }),
    );
    addTearDown(api.dispose);
    Widget screen(String token) => MaterialApp(
      home: Scaffold(
        body: BranchSafetyCard(key: key, api: api, token: token, onOpen: () {}),
      ),
    );
    await t.pumpWidget(screen('employee'));
    final first = key.currentState!.refresh();
    final second = key.currentState!.refresh();
    response.complete(http.Response(jsonEncode(data()), 200));
    await t.pumpAndSettle();
    await Future.wait([first, second]);
    expect(calls, 1);
    await key.currentState!.refresh(force: false);
    expect(calls, 1);
    response = Completer<http.Response>();
    final manual = key.currentState!.refresh();
    response.complete(http.Response(jsonEncode(data()), 200));
    await t.pumpAndSettle();
    await manual;
    expect(calls, 2);
    response = Completer<http.Response>();
    await t.pumpWidget(screen('other_employee'));
    expect(find.textContaining('128'), findsNothing);
    response.complete(http.Response(jsonEncode(data(days: 7)), 200));
    await t.pumpAndSettle();
    expect(calls, 3);
    expect(find.textContaining('7 '), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(740, 360),
    const Size(1440, 900),
  ]) {
    testWidgets('only branch data displayed and detail opens at $size', (
      t,
    ) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      var opened = false;
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          expect(request.url.path, endsWith('/seguridad/indicadores'));
          expect(request.url.query, isEmpty);
          expect(request.headers['authorization'], 'Bearer employee');
          return http.Response(jsonEncode(data()), 200);
        }),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(2),
            ),
            child: Scaffold(
              body: ListView(
                children: [
                  BranchSafetyCard(
                    api: api,
                    token: 'employee',
                    onOpen: () => opened = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('128 días sin accidentes'), findsOneWidget);
      expect(
        find.textContaining('Sucursal Central · Datos al'),
        findsOneWidget,
      );
      expect(find.textContaining('999'), findsNothing);
      expect(find.textContaining('777'), findsNothing);
      await t.tap(find.text('Seguridad en tu sucursal'));
      expect(opened, isTrue);
      expect(t.takeException(), isNull);
    });
  }
  for (final reason in ['sin_sucursal', 'sin_inicio_configurado']) {
    testWidgets('unavailable $reason does not invent zero', (t) async {
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode(data(days: null, available: false, reason: reason)),
            200,
          ),
        ),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchSafetyCard(api: api, token: 'employee', onOpen: () {}),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('0 días sin accidentes'), findsNothing);
      expect(
        find.text(
          reason == 'sin_sucursal'
              ? 'No tenés una sucursal asignada.'
              : 'Falta configurar el inicio del registro.',
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets(
    'refresh failure keeps dated data; successful refresh displays zero',
    (t) async {
      var fail = false;
      var days = 12;
      final key = GlobalKey<BranchSafetyCardState>();
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode(
              fail
                  ? {'error': 'No disponible'}
                  : data(days: days, date: '2026-01-01'),
            ),
            fail ? 503 : 200,
          ),
        ),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchSafetyCard(
              key: key,
              api: api,
              token: 'employee',
              onOpen: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Datos al 01/01/2026'), findsOneWidget);
      fail = true;
      await key.currentState!.refresh();
      await t.pumpAndSettle();
      expect(find.text('12 días sin accidentes'), findsOneWidget);
      expect(
        find.text('No se pudo actualizar. Se muestra la última consulta.'),
        findsOneWidget,
      );
      fail = false;
      days = 0;
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(find.text('0 días sin accidentes'), findsOneWidget);
    },
  );
  testWidgets('offline does not send a synthetic token to the server', (
    t,
  ) async {
    var calls = 0;
    final api = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BranchSafetyCard(
            api: api,
            token: 'offline_1',
            offline: true,
            onOpen: () {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(calls, 0);
    expect(
      find.text('Conectate para actualizar el indicador.'),
      findsOneWidget,
    );
  });
}
