import 'dart:convert';
import 'dart:typed_data';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'multipart preserves submission UUID and photos on JWT refresh',
    () async {
      final bodies = <String>[];
      final auth = <String?>[];
      final client = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/mobile/cargas');
          bodies.add(request.body);
          auth.add(request.headers['Authorization']);
          return bodies.length == 1
              ? http.Response('{"error":"expired"}', 401)
              : http.Response('{"registro":{"id":7},"repetido":false}', 201);
        }),
      );
      client.configureAuth(onUnauthorizedRefresh: (_) async => 'new-token');
      final result = await client.createCarga(
        token: 'old-token',
        fields: {
          'envio_id': '08271a75-ff73-479e-9304-5e9f949330f7',
          'valida': 'false',
          'observaciones': 'Faltante',
        },
        fotos: [
          Uint8List.fromList([1, 2, 3]),
        ],
      );
      expect(result['registro']['id'], 7);
      expect(auth, ['Bearer old-token', 'Bearer new-token']);
      expect(bodies.length, 2);
      for (final body in bodies) {
        expect(body, contains('08271a75-ff73-479e-9304-5e9f949330f7'));
        expect(body, contains('name="fotos"'));
        expect(body, contains('Faltante'));
      }
    },
  );

  test('conflict explains duplicate without hiding server error', () async {
    final client = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'Este camión ya tiene una carga inicial hoy.'}),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await expectLater(
      client.createCarga(token: 'token', fields: {}, fotos: []),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.message, 'message', contains('carga inicial')),
      ),
    );
  });

  test(
    'private photos use authenticated request, including Flutter web',
    () async {
      final client = MobileApiClient(
        baseUrl: 'https://example.test/api/v1/mobile',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/mobile/cargas/fotos/3');
          expect(request.headers['Authorization'], 'Bearer token');
          return http.Response.bytes([255, 216, 255], 200);
        }),
      );
      expect(await client.getCargaFoto(token: 'token', id: 3), [255, 216, 255]);
    },
  );
}
