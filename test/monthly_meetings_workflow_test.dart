import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/reuniones/reunion_navigation.dart';
import 'package:ficharqr/src/core/reuniones/notifications_navigation.dart';
import 'package:ficharqr/src/core/reuniones/push_service.dart';
import 'package:ficharqr/src/presentation/attendance/reuniones_monthly_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

void main() {
  test('push nuevo y ruta local conservan destino y propietario', () {
    expect(pushTypes, containsAll(['vacaciones_inicio', 'vacaciones_equipo']));
    NotificationsNavigation.route.value = null;
    final payload = jsonEncode({
      'owner': 7,
      'data': {'ruta': '/equipo/vacaciones/12'},
    });
    ReunionNavigation.fromLocal(payload, 8);
    expect(NotificationsNavigation.route.value, isNull);
    ReunionNavigation.fromLocal(payload, 7);
    expect(NotificationsNavigation.route.value, '/equipo/vacaciones/12');
    expect(NotificationsNavigation.openRoute('https://externo.test'), isFalse);
    NotificationsNavigation.route.value = null;
  });
  for (final dark in [false, true]) {
    testWidgets('mes y evolucion usan servidor, null no es cero dark=$dark', (
      tester,
    ) async {
      final queries = <Uri>[];
      final api = MobileApiClient(
        baseUrl: 'https://test.invalid',
        httpClient: MockClient((r) async {
          queries.add(r.url);
          final month = r.url.queryParameters['mes'] ?? '2026-10';
          final totals = {
            'planificadas': 3,
            'realizadas': 1,
            'asistidas': 1,
            'proximas': 2,
            'ausentes': 0,
            'ausentes_provisionales': 0,
            'justificados': 0,
            'canceladas': 0,
            'asistencia_pct': null,
            'puntualidad_pct': null,
            'minutos_planificados': 180,
            'minutos_realizados': 60,
            'minutos_asistidos': 60,
          };
          final body = r.url.path.endsWith('/calendario')
              ? {
                  'items': [
                    {
                      'id': 'stable-id',
                      'reunion_id': 7,
                      'nombre': 'Una reunión de coordinación con nombre largo',
                      'fecha': '$month-15',
                      'inicio': '$month-15T10:00:00-03:00',
                      'duracion_min': 60,
                      'estado': 'pendiente',
                      'definitivo': false,
                    },
                  ],
                }
              : r.url.path.endsWith('/evolucion')
              ? {
                  'meses': [
                    {'mes': month, ...totals},
                  ],
                }
              : {'totales': totals, 'provisional': true};
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.dispose);
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
          home: ReunionesMonthlyPage(api: api, token: 'test', onOpen: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(
        queries
            .where((q) => q.path.endsWith('/calendario'))
            .map((q) => q.queryParameters['mes'])
            .toSet()
            .length,
        2,
      );
      for (final size in [
        const Size(320, 640),
        const Size(740, 360),
        const Size(800, 1024),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        for (var n = 0; n < 14; n++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
      expect(
        queries.any(
          (q) =>
              q.path.endsWith('/estadisticas/evolucion') &&
              q.queryParameters.containsKey('desde_mes'),
        ),
        isTrue,
      );
    });
  }
}
