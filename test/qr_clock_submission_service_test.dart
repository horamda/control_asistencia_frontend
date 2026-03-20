import 'dart:convert';
import 'dart:io';

import 'package:ficharqr/src/core/attendance/qr_clock_submission_service.dart';
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

  group('QrClockSubmissionService', () {
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
        'qr-clock-submit-source-',
      );
      persistentRoot = await Directory.systemTemp.createTemp(
        'qr-clock-submit-persistent-',
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

    test('submit registra online y limpia la foto temporal', () async {
      final sourceFile = File(
        '${sourceRoot.path}${Platform.pathSeparator}clock.jpg',
      );
      await sourceFile.writeAsBytes(const <int>[1, 2, 3, 4]);

      final client = _QueuedClient([
        _QueuedReply(
          statusCode: 201,
          body: const <String, dynamic>{
            'id': 55,
            'accion': 'ingreso',
            'estado': 'ok',
          },
          inspect: (request) {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/mobile/me/fichadas/scan');
          },
        ),
      ]);
      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: client,
      );
      final pendingSyncService = PendingClockSyncService(
        offlineClockQueue: queue,
        clockPhotoCache: photoCache,
        apiClient: apiClient,
      );
      final submissionService = QrClockSubmissionService(
        apiClient: apiClient,
        pendingClockSyncService: pendingSyncService,
        clockPhotoCache: photoCache,
      );

      String? savedPath;
      final phases = <String>[];
      final result = await submissionService.submit(
        employeeId: 7,
        token: 'abc',
        qrToken: 'qr-1',
        eventAt: DateTime(2026, 3, 17, 10, 0, 0),
        requiresPhoto: true,
        capturePhotoToCache: () async {
          savedPath = await photoCache.saveFromPath(
            employeeId: 7,
            sourcePath: sourceFile.path,
          );
          return savedPath;
        },
        captureGps: () async => const ClockGpsPoint(lat: -34.6, lon: -58.4),
        onPhase: phases.add,
      );

      expect(result.status, QrClockSubmissionStatus.success);
      expect(result.response?.id, 55);
      expect(result.photoDuration, isNotNull);
      expect(result.gpsDuration, isNotNull);
      expect(result.apiDuration, isNotNull);
      expect(phases, ['Capturando foto...', 'Validando GPS...', 'Enviando fichada...']);
      expect(await queue.readForEmployee(7), isEmpty);
      expect(savedPath, isNotNull);
      expect(await File(savedPath!).exists(), isFalse);
      apiClient.dispose();
    });

    test('submit encola offline cuando falla la conectividad', () async {
      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: _ThrowingClient(const SocketException('sin red')),
      );
      final pendingSyncService = PendingClockSyncService(
        offlineClockQueue: queue,
        clockPhotoCache: photoCache,
        apiClient: apiClient,
      );
      final submissionService = QrClockSubmissionService(
        apiClient: apiClient,
        pendingClockSyncService: pendingSyncService,
        clockPhotoCache: photoCache,
      );

      final result = await submissionService.submit(
        employeeId: 7,
        token: 'abc',
        qrToken: 'qr-2',
        eventAt: DateTime(2026, 3, 17, 10, 0, 0),
        requiresPhoto: false,
        capturePhotoToCache: () async => null,
        captureGps: () async => const ClockGpsPoint(lat: -34.6, lon: -58.4),
      );

      expect(result.status, QrClockSubmissionStatus.offlineQueued);
      expect(result.pendingSnapshot?.total, 1);
      final items = await queue.readForEmployee(7);
      expect(items, hasLength(1));
      expect(items.single.qrToken, 'qr-2');
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
