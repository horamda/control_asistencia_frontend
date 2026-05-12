import 'dart:convert';
import 'dart:io';

import 'package:ficharqr/src/core/image/clock_photo_cache.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';
import 'package:ficharqr/src/core/offline/pending_clock_sync_service.dart';
import 'package:ficharqr/src/core/offline/pending_queue_controller.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingQueueController', () {
    late Map<String, String> data;
    late Directory persistentRoot;
    late ClockPhotoCache photoCache;
    late OfflineClockQueue queue;

    setUp(() async {
      data = <String, String>{};
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        data,
      );
      persistentRoot = await Directory.systemTemp.createTemp(
        'pending-queue-controller-',
      );
      photoCache = ClockPhotoCache(
        rootDirectoryProvider: () async => persistentRoot,
      );
      queue = OfflineClockQueue();
    });

    tearDown(() async {
      if (await persistentRoot.exists()) {
        await persistentRoot.delete(recursive: true);
      }
    });

    test('syncAll actualiza snapshot y fecha de ultima sync', () async {
      await queue.enqueue(
        employeeId: 7,
        qrToken: 'qr-1',
        eventAt: DateTime(2026, 3, 17, 10, 0, 0),
        lat: -34.6,
        lon: -58.4,
      );
      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: _QueuedClient([
          const _QueuedReply(statusCode: 201, body: <String, dynamic>{'id': 55}),
        ]),
      );
      final syncService = PendingClockSyncService(
        offlineClockQueue: queue,
        clockPhotoCache: photoCache,
        apiClient: apiClient,
      );
      final controller = PendingQueueController(syncService: syncService);

      final started = controller.startSync(
        current: const PendingQueueState(),
        isBackground: false,
      );
      final next = await controller.syncAll(
        employeeId: 7,
        token: 'abc',
        current: started,
      );

      expect(next.syncing, isFalse);
      expect(next.total, 0);
      expect(next.failed, 0);
      expect(next.lastSyncAt, isNotNull);
      expect(next.lastMessage, contains('Sincronizadas 1'));
      apiClient.dispose();
    });

    test('syncAll silencioso conserva el ultimo mensaje si no hay alerta', () async {
      final apiClient = MobileApiClient(baseUrl: 'https://example.com');
      final syncService = PendingClockSyncService(
        offlineClockQueue: queue,
        clockPhotoCache: photoCache,
        apiClient: apiClient,
      );
      final controller = PendingQueueController(syncService: syncService);

      final started = controller.startSync(
        current: const PendingQueueState(lastMessage: 'Estado previo'),
        isBackground: true,
      );
      final next = await controller.syncAll(
        employeeId: 7,
        token: 'abc',
        current: started,
        isBackground: true,
      );

      expect(next.syncing, isFalse);
      expect(next.lastMessage, 'Estado previo');
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
    final bytes = utf8.encode(jsonEncode(reply.body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      reply.statusCode,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

class _QueuedReply {
  const _QueuedReply({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;
}
