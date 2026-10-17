import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/reuniones/comunicados_navigation.dart';
import 'package:ficharqr/src/core/reuniones/reunion_navigation.dart';
import 'package:ficharqr/src/presentation/attendance/comunicados_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

Map<String, dynamic> item(int id, {bool read = false}) => {
  'id': id,
  'titulo': 'Comunicado $id para todos los empleados de la sucursal',
  'mensaje':
      'Primer párrafo del comunicado.\nSegundo párrafo con instrucciones completas.',
  'fecha': '2026-10-16T09:30:00',
  'leido': read,
  'imagen_url': null,
};

void main() {
  setUp(() {
    ComunicadosNavigation.pending.value = null;
    ReunionNavigation.pending.value = null;
  });
  test(
    'Only internal communications routes and the current owner are accepted',
    () {
      for (final route in [
        '/comunicados/-1',
        '/comunicados/0',
        '/comunicados/1/imagen',
        'https://evil.test/comunicados/1',
      ]) {
        ReunionNavigation.open(route);
        expect(ComunicadosNavigation.pending.value, isNull);
      }
      ReunionNavigation.open('/comunicados/12');
      expect(ComunicadosNavigation.pending.value, 12);
      ComunicadosNavigation.pending.value = null;
      ReunionNavigation.fromLocal('comunicado:7:12:push', 8);
      expect(ComunicadosNavigation.pending.value, isNull);
      ReunionNavigation.fromLocal('comunicado:7:12:push', 7);
      expect(ComunicadosNavigation.pending.value, 12);
    },
  );

  test(
    'API list, detail, read-all and authenticated image follow the contract',
    () async {
      final calls = <http.Request>[];
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          calls.add(request);
          expect(request.headers['authorization'], 'Bearer jwt');
          if (request.url.path.endsWith('/imagen')) {
            return http.Response.bytes([1, 2, 3], 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await api.getComunicados(token: 'jwt', page: 2);
      await api.getComunicado(token: 'jwt', id: 12);
      await api.leerTodosComunicados(token: 'jwt');
      expect(await api.getComunicadoImagen(token: 'jwt', id: 12), [1, 2, 3]);
      expect(calls.map((r) => '${r.method} ${r.url.path}').toList(), [
        'GET /api/v1/mobile/comunicados',
        'GET /api/v1/mobile/comunicados/12',
        'POST /api/v1/mobile/comunicados/leer-todos',
        'GET /api/v1/mobile/comunicados/12/imagen',
      ]);
      expect(calls.first.url.queryParameters['page'], '2');
    },
  );

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 412.0, 800.0]) {
      testWidgets('Inbox and detail at $width with large text in $brightness', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var read = false;
        final api = MobileApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((request) async {
            Object data;
            if (request.url.path.endsWith('/12')) {
              read = true;
              data = item(12, read: true);
            } else {
              data = {
                'items': [item(12, read: read)],
                'no_leidos': read ? 0 : 1,
                'page': 1,
                'pages': 1,
              };
            }
            return http.Response(
              jsonEncode(data),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: ComunicadosPage(api: api, token: 'jwt'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Notificaciones'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Notificaciones'));
        await tester.pumpAndSettle();
        final title = find.text(item(12)['titulo'] as String);
        await tester.scrollUntilVisible(title, 250);
        await tester.pumpAndSettle();
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(read, isTrue);
        expect(find.byType(SelectableText), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 1500));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('0 sin leer'), 200);
        await tester.pumpAndSettle();
        expect(find.text('0 sin leer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Pagination and read-all preserve messages', (tester) async {
    var allRead = false;
    final pages = <String>[];
    final api = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          allRead = true;
          return http.Response('{"marcados":2}', 200);
        }
        final page = request.url.queryParameters['page'] ?? '1';
        pages.add(page);
        return http.Response(
          jsonEncode({
            'items': [item(page == '1' ? 12 : 13, read: allRead)],
            'no_leidos': allRead ? 0 : 2,
            'page': int.parse(page),
            'pages': 2,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ComunicadosPage(api: api, token: 'jwt'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cargar más'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();
    expect(pages, contains('2'));
    await tester.scrollUntilVisible(
      find.text(item(13)['titulo'] as String),
      250,
    );
    await tester.pumpAndSettle();
    expect(find.text(item(13)['titulo'] as String), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Marcar todos como leídos'),
      -250,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar todos como leídos'));
    await tester.pumpAndSettle();
    expect(allRead, isTrue);
    expect(find.text('0 sin leer'), findsOneWidget);
    expect(find.text(item(12)['titulo'] as String), findsOneWidget);
  });

  testWidgets('Missing detail reports removal and offers retry', (
    tester,
  ) async {
    final api = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async => http.Response('{}', 404)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ComunicadoDetailPage(api: api, token: 'jwt', id: 99),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ya no está disponible'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
