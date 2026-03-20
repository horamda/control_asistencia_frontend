import 'dart:convert';
import 'dart:io';

import 'package:ficharqr/src/core/image/clock_photo_cache.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';
import 'package:ficharqr/src/core/offline/pending_clock_sync_service.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingClockSyncService', () {
    late Map<String, String> data;
    late Directory sourceRoot;
    late Directory persistentRoot;
    late ClockPhotoCache photoCache;
    late OfflineClockQueue queue;

    setUp(() async {
      data = <String, String>{};
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        data,
      );
      sourceRoot = await Directory.systemTemp.createTemp(
        'pending-clock-sync-source-',
      );
      persistentRoot = await Directory.systemTemp.createTemp(
        'pending-clock-sync-persistent-',
      );
      photoCache = ClockPhotoCache(
        rootDirectoryProvider: () async => persistentRoot,
      );
      queue = OfflineClockQueue();
    });

    tearDown(() async {
      if (await sourceRoot.exists()) {
        await sourceRoot.delete(recursive: true);
      }
      if (await persistentRoot.exists()) {
        await persistentRoot.delete(recursive: true);
      }
    });

    test('syncAll elimina el pendiente sincronizado y su foto cacheada', () async {
      final sourceFile = File(
        '${sourceRoot.path}${Platform.pathSeparator}clock.jpg',
      );
      await sourceFile.writeAsBytes(const <int>[1, 2, 3, 4]);
      final fotoPath = await photoCache.saveFromPath(
        employeeId: 7,
        sourcePath: sourceFile.path,
      );
      final now = DateTime(2026, 3, 15, 10, 0, 0);

      await queue.enqueue(
        employeeId: 7,
        qrToken: 'qr-1',
        eventAt: now,
        lat: -34.6,
        lon: -58.4,
        fotoPath: fotoPath,
      );

      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: _QueuedClient([
          _QueuedReply(
            statusCode: 200,
            body: const <String, dynamic>{'id': 11},
            inspect: (request) {
              expect(request.method, 'POST');
              expect(request.url.path, '/api/v1/mobile/me/fichadas/scan');
            },
          ),
        ]),
      );
      final service = PendingClockSyncService(
        offlineClockQueue: queue,
        clockPhotoCache: photoCache,
        apiClient: apiClient,
      );

      final result = await service.syncAll(employeeId: 7, token: 'abc');

      expect(result.hadPending, isTrue);
      expect(result.syncedCount, 1);
      expect(result.failedCount, 0);
      expect(result.snapshot.total, 0);
      expect(await queue.readForEmployee(7), isEmpty);
      expect(await File(fotoPath!).exists(), isFalse);
      apiClient.dispose();
    });

    test('retryRecord mantiene el item pendiente cuando no hay conectividad', () async {
      final now = DateTime(2026, 3, 15, 10, 0, 0);
      await queue.enqueue(
        employeeId: 7,
        qrToken: 'qr-2',
        eventAt: now,
        lat: -34.6,
        lon: -58.4,
      );
      final record = (await queue.readForEmployee(7)).single;

      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: _ThrowingClient(
          const SocketException('sin red'),
        ),
      );
      final service = PendingClockSyncService(
        offlineClockQueue: queue,
        clockPhotoCache: photoCache,
        apiClient: apiClient,
      );

      final result = await service.retryRecord(
        employeeId: 7,
        token: 'abc',
        record: record,
      );

      expect(result.synced, isFalse);
      expect(result.message, 'Sin internet. El item sigue pendiente.');
      expect(result.snapshot.total, 1);
      expect(result.snapshot.failed, 0);

      final saved = (await queue.readForEmployee(7)).single;
      expect(saved.status, OfflineClockStatus.pending);
      expect(saved.attempts, 1);
      expect(saved.lastError, contains('conexion'));
      apiClient.dispose();
    });
  });
}

class _QueuedClient extends http.BaseClient {
  _QueuedClient(this.replies);

  final List<_QueuedReply> replies;
  int callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (callCount >= replies.length) {
      throw StateError(
        'No hay respuesta preparada para ${request.method} ${request.url}',
      );
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

class _ThrowingClient extends http.BaseClient {
  _ThrowingClient(this.error);

  final Exception error;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw error;
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
