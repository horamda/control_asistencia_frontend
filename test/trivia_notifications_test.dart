import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/trivia/trivia_home_screen.dart';

void main() {
  testWidgets('lectura individual y total, errores y polling', (tester) async {
    var ids = [7, 8];
    var fail = true;
    var gets = 0;
    final posts = <String>[];
    final api = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        final path = request.url.path;
        if (path.endsWith('/estado')) {
          return http.Response(
            jsonEncode({
              'data': {'hay_trivia_activa': false},
            }),
            200,
          );
        }
        if (request.method == 'POST') {
          posts.add(path);
          if (fail) return http.Response('{"error":"Error de lectura"}', 500);
          if (path.endsWith('/leer-todas')) {
            ids = [];
          } else {
            ids.remove(7);
          }
          return http.Response('{"success":true}', 200);
        }
        gets++;
        return http.Response(
          jsonEncode({
            'data': [
              for (final id in ids) {'id': id, 'mensaje': 'Aviso $id'},
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TriviaHomeScreen(
          apiClient: api,
          token: 'token',
          empleadoDni: '123',
          empleadoId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aviso 7'), findsOneWidget);
    expect(find.text('Aviso 8'), findsOneWidget);
    await tester.tap(find.byTooltip('Marcar como leída').first);
    await tester.pumpAndSettle();
    expect(find.text('Error de lectura'), findsOneWidget);
    expect(find.text('Aviso 7'), findsOneWidget);
    fail = false;
    await tester.tap(find.byTooltip('Marcar como leída').first);
    await tester.pumpAndSettle();
    expect(find.text('Aviso 7'), findsNothing);
    expect(posts.last, '/api/v1/trivia/notificaciones/7/leer');
    ids.add(9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 9'), findsOneWidget);
    await tester.tap(find.text('Marcar todas como leídas'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 8'), findsNothing);
    expect(posts.last, '/api/v1/trivia/notificaciones/leer-todas');
    final previous = gets;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(gets, previous);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(gets, previous);
  });

  test('fallos HTTP se propagan al consultar y marcar todas', () async {
    final api = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => http.Response('{"error":"No disponible"}', 503),
      ),
    );
    addTearDown(api.dispose);
    await expectLater(
      api.getTriviaNotificaciones(token: 'token'),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      api.marcarTodasNotificacionesTriviaLeidas(token: 'token'),
      throwsA(isA<ApiException>()),
    );
  });
}
