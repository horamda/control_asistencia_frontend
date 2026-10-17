import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/reuniones/reunion_navigation.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/reuniones_dashboard.dart';
import 'package:ficharqr/src/presentation/attendance/reuniones_page.dart';

void main() {
  test(
    'push registration and logout use Bearer and JSON DELETE body',
    () async {
      final requests = <http.Request>[];
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({'activo': true, 'registrado': true, 'quitado': true}),
            200,
          );
        }),
      );
      expect((await api.getPushConfig(token: 'jwt'))['activo'], true);
      await api.registerPushDevice(
        token: 'jwt',
        deviceToken: 'fcm-device-token',
        platform: 'android',
        appVersion: '1.23.0+31',
      );
      await api.removePushDevice(token: 'jwt', deviceToken: 'fcm-device-token');
      expect(requests.map((r) => r.method), ['GET', 'POST', 'DELETE']);
      expect(
        requests.every((r) => r.headers['Authorization'] == 'Bearer jwt'),
        true,
      );
      expect(requests[0].url.path, '/api/v1/mobile/push/config');
      expect(jsonDecode(requests[1].body), {
        'token': 'fcm-device-token',
        'plataforma': 'android',
        'app_version': '1.23.0+31',
      });
      expect(jsonDecode(requests[2].body), {'token': 'fcm-device-token'});
    },
  );

  test(
    'notification routes reject external URLs and local payloads from other employees',
    () {
      expect(meetingIdFromRoute('/reuniones/42'), 42);
      for (final route in [
        'https://evil.test/reuniones/42',
        '/reuniones/0',
        '/reuniones/-1',
        '/reuniones/42/../../perfil',
        '/perfil',
        '/reuniones/abc',
      ]) {
        expect(meetingIdFromRoute(route), isNull);
      }
      ReunionNavigation.pending.value = null;
      ReunionNavigation.fromLocal('reunion:7:42:2026-10-16', 8);
      expect(ReunionNavigation.pending.value, isNull);
      ReunionNavigation.fromLocal('reunion:7:42:2026-10-16', 7);
      expect(ReunionNavigation.pending.value, 42);
      ReunionNavigation.pending.value = null;
    },
  );

  testWidgets('week and statistics show server totals on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const ReunionWeekSummary(
                  data: {'reuniones': 4, 'horas': 3.5, 'superpuestas': 2},
                ),
                const ReunionStats(
                  data: {'horas_asistidas': 14.0, 'minutos_asistidos': 840},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Horas: 3.5'), findsOneWidget);
    expect(find.text('Superpuestas: 2'), findsOneWidget);
    expect(find.text('Horas asistidas: 14.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
