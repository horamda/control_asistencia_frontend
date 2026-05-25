import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ficharqr/src/core/feedback/app_rating_service.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'FichaYa',
      packageName: 'com.controlasistencia.ficharqr',
      version: '1.20.4',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('AppRatingService.shouldShowDialog', () {
    test('retorna false antes de alcanzar minSessions', () async {
      final storage = _InMemoryStorage();
      final service = AppRatingService(
        apiClient: _StubApiClient(),
        token: 'tok',
        storage: storage,
        minSessions: 3,
        maxDismissals: 2,
      );

      expect(await service.shouldShowDialog(), isFalse);
      expect(await service.shouldShowDialog(), isFalse);
    });

    test('retorna true al alcanzar minSessions', () async {
      final storage = _InMemoryStorage();
      final service = AppRatingService(
        apiClient: _StubApiClient(),
        token: 'tok',
        storage: storage,
        minSessions: 3,
        maxDismissals: 2,
      );

      await service.shouldShowDialog();
      await service.shouldShowDialog();
      expect(await service.shouldShowDialog(), isTrue);
    });

    test('retorna false cuando ya fue calificada', () async {
      final storage = _InMemoryStorage();
      final service = AppRatingService(
        apiClient: _StubApiClient(),
        token: 'tok',
        storage: storage,
        minSessions: 1,
        maxDismissals: 2,
      );

      await storage.write('rating_rated_1.20.4', '1');
      expect(await service.shouldShowDialog(), isFalse);
    });

    test('retorna false cuando se alcanza maxDismissals', () async {
      final storage = _InMemoryStorage();
      final service = AppRatingService(
        apiClient: _StubApiClient(),
        token: 'tok',
        storage: storage,
        minSessions: 1,
        maxDismissals: 2,
      );

      await service.shouldShowDialog();
      await service.markDismissed();
      await service.markDismissed();
      expect(await service.shouldShowDialog(), isFalse);
    });
  });

  group('AppRatingService.submitRating', () {
    test('marca como rated y devuelve true cuando la API responde 201', () async {
      final storage = _InMemoryStorage();
      final apiClient = _FakeRatingApiClient(statusCode: 201);
      final service = AppRatingService(
        apiClient: apiClient,
        token: 'tok',
        storage: storage,
        minSessions: 1,
      );

      final ok = await service.submitRating(puntuacion: 5, pantalla: 'mas_opciones');

      expect(ok, isTrue);
      expect(await storage.read('rating_rated_1.20.4'), '1');
    });

    test('no marca rated cuando la API falla', () async {
      final storage = _InMemoryStorage();
      final apiClient = _FakeRatingApiClient(statusCode: 500);
      final service = AppRatingService(
        apiClient: apiClient,
        token: 'tok',
        storage: storage,
        minSessions: 1,
      );

      final ok = await service.submitRating(puntuacion: 3);

      expect(ok, isFalse);
      expect(await storage.read('rating_rated_1.20.4'), isNull);
    });

    test('acepta calificacion 409 (ya calificada) como ok', () async {
      final storage = _InMemoryStorage();
      final apiClient = _FakeRatingApiClient(statusCode: 409);
      final service = AppRatingService(
        apiClient: apiClient,
        token: 'tok',
        storage: storage,
        minSessions: 1,
      );

      final ok = await service.submitRating(puntuacion: 4);

      expect(ok, isTrue);
      expect(await storage.read('rating_rated_1.20.4'), '1');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _InMemoryStorage implements AppRatingStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

class _StubApiClient extends MobileApiClient {
  _StubApiClient() : super(baseUrl: 'https://example.com');

  @override
  void dispose() {}
}

class _FakeRatingApiClient extends MobileApiClient {
  _FakeRatingApiClient({required this.statusCode})
      : super(
          baseUrl: 'https://example.com',
          httpClient: _FixedStatusClient(statusCode),
        );

  final int statusCode;

  @override
  void dispose() {}
}

class _FixedStatusClient extends http.BaseClient {
  _FixedStatusClient(this.statusCode);
  final int statusCode;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode(<String, dynamic>{'ok': true}));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
  }
}
