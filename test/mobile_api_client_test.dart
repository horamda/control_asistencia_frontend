import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ficharqr/src/core/network/mobile_api_client.dart';

void main() {
  test('updatePerfilConFotoFile refresca token y reintenta upload multipart', () async {
    final sourceRoot = await Directory.systemTemp.createTemp(
      'mobile-api-client-upload-',
    );

    try {
      final file = File('${sourceRoot.path}${Platform.pathSeparator}profile.jpg');
      await file.writeAsBytes(const <int>[1, 2, 3, 4]);

      final client = _QueuedClient([
        _QueuedReply(
          statusCode: 401,
          body: const <String, dynamic>{'error': 'Sesion vencida.'},
          inspect: (request) {
            expect(request.method, 'PUT');
            expect(request.url.path, '/api/v1/mobile/me/perfil');
            expect(request.headers['Authorization'], 'Bearer expired-token');
          },
        ),
        _QueuedReply(
          statusCode: 200,
          body: const <String, dynamic>{
            'id': 7,
            'telefono': '1234',
            'direccion': 'Calle 1',
          },
          inspect: (request) {
            expect(request.method, 'PUT');
            expect(request.url.path, '/api/v1/mobile/me/perfil');
            expect(request.headers['Authorization'], 'Bearer fresh-token');
          },
        ),
      ]);

      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: client,
      );
      String? refreshedToken;
      apiClient.configureAuth(
        onUnauthorizedRefresh: (expiredToken) async {
          refreshedToken = expiredToken;
          return 'fresh-token';
        },
      );

      final result = await apiClient.updatePerfilConFotoFile(
        token: 'expired-token',
        fotoPath: file.path,
        telefono: '1234',
        direccion: 'Calle 1',
      );

      expect(refreshedToken, 'expired-token');
      expect(result.id, 7);
      expect(result.telefono, '1234');
      expect(client.callCount, 2);
      apiClient.dispose();
    } finally {
      if (await sourceRoot.exists()) {
        await sourceRoot.delete(recursive: true);
      }
    }
  });

  test('usa el prefijo movil configurable para construir endpoints', () async {
    final client = _QueuedClient([
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{'id': 1},
        inspect: (request) {
          expect(request.method, 'GET');
          expect(request.url.path, '/custom/mobile/me');
        },
      ),
    ]);

    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com',
      mobileApiPrefix: '/custom/mobile',
      httpClient: client,
    );

    final profile = await apiClient.getMe(token: 'abc');

    expect(profile.id, 1);
    expect(client.callCount, 1);
    apiClient.dispose();
  });

  test('buildEmpleadoImagenUrl elimina el prefijo movil del baseUrl', () {
    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com/custom/mobile',
      mobileApiPrefix: '/custom/mobile',
      httpClient: _QueuedClient(const <_QueuedReply>[]),
    );

    final imageUrl = apiClient.buildEmpleadoImagenUrl(dni: '30111222', version: 3);

    expect(
      imageUrl,
      'https://example.com/empleados/imagen/30111222?v=3',
    );
    apiClient.dispose();
  });
}

class _QueuedClient extends http.BaseClient {
  _QueuedClient(this.replies);

  final List<_QueuedReply> replies;
  int callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (callCount >= replies.length) {
      throw StateError('No hay respuesta preparada para ${request.method} ${request.url}');
    }
    final reply = replies[callCount];
    callCount += 1;
    reply.inspect?.call(request);
    final bytes = utf8.encode(jsonEncode(reply.body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      reply.statusCode,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

class _QueuedReply {
  const _QueuedReply({
    required this.statusCode,
    required this.body,
    this.inspect,
  });

  final int statusCode;
  final Map<String, dynamic> body;
  final void Function(http.BaseRequest request)? inspect;
}
