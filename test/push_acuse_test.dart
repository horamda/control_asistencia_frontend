import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/reuniones/push_service.dart';

MobileApiClient _api(List<http.Request> requests, {int status = 200}) =>
    MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          jsonEncode(status == 200 ? {'ok': true} : {'error': 'Acuse inválido.'}),
          status,
        );
      }),
    );

void main() {
  test('el acuse va sin JWT con el envio, la firma y el evento', () async {
    final requests = <http.Request>[];
    await acknowledgePush(
      const RemoteMessage(
        data: {'tipo': 'comunicado', 'envio_id': '41', 'acuse': 'firma-41'},
      ),
      'recibido',
      api: _api(requests),
    );
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/mobile/push/acuse');
    expect(requests.single.headers.containsKey('Authorization'), false);
    expect(jsonDecode(requests.single.body), {
      'envio_id': '41',
      'acuse': 'firma-41',
      'evento': 'recibido',
    });
  });

  test('un push sin envio o sin firma no manda nada', () async {
    final requests = <http.Request>[];
    final api = _api(requests);
    await acknowledgePush(
      const RemoteMessage(data: {'tipo': 'reunion_nueva'}),
      'recibido',
      api: api,
    );
    await acknowledgePush(
      const RemoteMessage(data: {'envio_id': '41'}),
      'abierto',
      api: api,
    );
    expect(requests, isEmpty);
  });

  test('un acuse rechazado no rompe la app', () async {
    final requests = <http.Request>[];
    await acknowledgePush(
      const RemoteMessage(data: {'envio_id': '41', 'acuse': 'falsa'}),
      'abierto',
      api: _api(requests, status: 403),
    );
    expect(requests, hasLength(1));
  });
}
