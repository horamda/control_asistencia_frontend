import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/notifications_page.dart';
import 'package:ficharqr/src/core/reuniones/reunion_navigation.dart';
import 'package:ficharqr/src/core/reuniones/notifications_navigation.dart';

void main() {
  test('local notification requires matching owner', () {
    NotificationsNavigation.pending.value = null;
    ReunionNavigation.fromLocal('notificacion:7:812:push', 8);
    expect(NotificationsNavigation.pending.value, isNull);
    ReunionNavigation.fromLocal('notificacion:7:812:push', 7);
    expect(NotificationsNavigation.pending.value, 812);
    NotificationsNavigation.pending.value = null;
  });
  for (final size in [
    const Size(320, 640),
    const Size(740, 360),
    const Size(800, 1024),
  ]) {
    testWidgets('server read cutoff preserves newer messages $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var read = false;
      final requests = <http.Request>[];
      final api = MobileApiClient(
        baseUrl: 'https://test.invalid',
        httpClient: MockClient((r) async {
          requests.add(r);
          expect(r.headers['Authorization'], 'Bearer test');
          if (r.method == 'POST') {
            expect(jsonDecode(r.body), {'hasta_id': 812});
            read = true;
            return http.Response('{"marcadas":1,"no_leidas":1}', 200);
          }
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': read ? 813 : 812,
                  'titulo': read ? 'Nueva novedad' : 'Pedido aprobado',
                  'mensaje': 'Mensaje',
                  'leida': false,
                },
              ],
              'no_leidas': 1,
              'corte': read ? 813 : 812,
              'siguiente': null,
            }),
            200,
          );
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: NotificationsPage(
            api: api,
            token: 'test',
            onDestination: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      final mark = find.text('Marcar todas como leídas');
      await tester.ensureVisible(mark);
      await tester.pumpAndSettle();
      await tester.tap(mark);
      await tester.pumpAndSettle();
      expect(find.text('Nueva novedad'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
      await tester.pumpAndSettle();
      expect(find.text('1 sin leer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('read state persists after reopening $brightness', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var read = false;
      final api = MobileApiClient(
        baseUrl: 'https://test.invalid',
        httpClient: MockClient((r) async {
          if (r.method == 'POST') {
            read = true;
            return http.Response('{"no_leidas":0}', 200);
          }
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'titulo': 'Mensaje conservado',
                  'mensaje':
                      'Descripcion suficientemente larga para revisar la lectura en pantallas pequenas con texto ampliado.',
                  'modulo': 'comunicados',
                  'leida': read,
                  'creado_at': '2026-10-18T15:30:00-03:00',
                },
              ],
              'no_leidas': read ? 0 : 1,
              'corte': 1,
            }),
            200,
          );
        }),
      );
      addTearDown(api.dispose);
      Widget app() => MaterialApp(
        theme: buildAppTheme(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: NotificationsPage(
          api: api,
          token: 'test',
          onDestination: (_) async {},
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Permisos de avisos'), findsOneWidget);
      final mark = find.widgetWithIcon(TextButton, Icons.done_all);
      await tester.ensureVisible(mark);
      await tester.tap(mark);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('0 sin leer'), findsOneWidget);
      await tester.ensureVisible(find.text('Mensaje conservado'));
      expect(find.text('18/10/2026'), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unavailable reference stays readable without navigation', (
    tester,
  ) async {
    var marked = false;
    final api = MobileApiClient(
      baseUrl: 'https://test.invalid',
      httpClient: MockClient((r) async {
        if (r.method == 'POST') marked = true;
        final item = {
          'id': 1,
          'titulo': 'Aviso',
          'mensaje': 'Contenido conservado',
          'referencia': {'disponible': false},
          'destino': {'ruta': '/adelantos'},
        };
        return http.Response(
          jsonEncode(
            r.url.path.endsWith('/notificaciones')
                ? {
                    'items': [item],
                    'no_leidas': 1,
                    'corte': 1,
                  }
                : item,
          ),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsPage(
          api: api,
          token: 'test',
          onDestination: (_) async {
            fail('Must not navigate');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aviso'));
    await tester.pumpAndSettle();
    expect(marked, isTrue);
    expect(
      find.textContaining('Este trámite ya no está disponible.'),
      findsOneWidget,
    );
    expect(find.text('Ver detalle'), findsNothing);
  });
}
