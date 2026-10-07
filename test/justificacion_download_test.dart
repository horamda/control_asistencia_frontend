import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';

void main() {
  test('descarga binaria con Bearer y renovación ante 401', () async {
    var requests = 0;
    final bytes = [37, 80, 68, 70, 0, 128, 255];
    final api = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        requests++;
        expect(
          request.url.path,
          '/api/v1/mobile/me/justificaciones/10/adjuntos/88',
        );
        expect(request.url.query, isEmpty);
        expect(
          request.headers['Authorization'],
          requests == 1 ? 'Bearer old' : 'Bearer new',
        );
        return requests == 1
            ? http.Response('{"error":"Sesión vencida"}', 401)
            : http.Response.bytes(bytes, 200);
      }),
    );
    addTearDown(api.dispose);
    api.configureAuth(
      onUnauthorizedRefresh: (token) async {
        expect(token, 'old');
        return 'new';
      },
    );
    expect(
      await api.downloadJustificacionAdjunto(
        token: 'old',
        id: 10,
        adjuntoId: 88,
      ),
      bytes,
    );
    expect(requests, 2);
  });

  for (final status in [403, 404, 500]) {
    test('propaga error $status sin tratarlo como archivo', () async {
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => http.Response('{"error":"No disponible"}', status),
        ),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.downloadJustificacionAdjunto(token: 'token', id: 10, adjuntoId: 88),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', status)
              .having((e) => e.message, 'mensaje', 'No disponible'),
        ),
      );
    });
  }
}
