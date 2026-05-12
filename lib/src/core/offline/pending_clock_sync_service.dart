import '../image/clock_photo_cache.dart';
import '../network/mobile_api_client.dart';
import 'offline_clock_queue.dart';

class PendingClockSyncService {
  PendingClockSyncService({
    required OfflineClockQueue offlineClockQueue,
    required ClockPhotoCache clockPhotoCache,
    required MobileApiClient apiClient,
  }) : _offlineClockQueue = offlineClockQueue,
       _clockPhotoCache = clockPhotoCache,
       _apiClient = apiClient;

  /// Máximo de intentos automáticos para un registro con error de validación.
  /// Despues de este limite el registro permanece en cola pero no se reintenta
  /// automaticamente; el usuario puede forzar un reintento manual desde la UI.
  static const int _maxAutoRetries = 10;

  final OfflineClockQueue _offlineClockQueue;
  final ClockPhotoCache _clockPhotoCache;
  final MobileApiClient _apiClient;

  Future<PendingClockSnapshot> readSnapshot({required int employeeId}) async {
    final records = await _offlineClockQueue.readForEmployee(employeeId);
    return PendingClockSnapshot.fromRecords(records);
  }

  Future<PendingClockSnapshot> enqueue({
    required int employeeId,
    required String qrToken,
    required DateTime eventAt,
    double? lat,
    double? lon,
    String? fotoPath,
  }) async {
    await _offlineClockQueue.enqueue(
      employeeId: employeeId,
      qrToken: qrToken,
      eventAt: eventAt,
      lat: lat,
      lon: lon,
      fotoPath: fotoPath,
    );
    final snapshot = await readSnapshot(employeeId: employeeId);
    await pruneEmployeePhotos(
      employeeId: employeeId,
      keepRecords: snapshot.records,
    );
    return snapshot;
  }

  Future<PendingClockSyncBatchResult> syncAll({
    required int employeeId,
    required String token,
    bool retryFailed = true,
  }) async {
    final pending = await _offlineClockQueue.readForEmployee(employeeId);
    if (pending.isEmpty) {
      return const PendingClockSyncBatchResult(
        snapshot: PendingClockSnapshot.empty(),
        message: 'No hay fichadas pendientes.',
        hadPending: false,
        syncedCount: 0,
        failedCount: 0,
        stoppedByConnectivity: false,
      );
    }

    final remaining = <OfflineClockRecord>[];
    var synced = 0;
    var failed = 0;
    var stoppedByConnectivity = false;

    syncLoop:
    for (var i = 0; i < pending.length; i++) {
      final record = pending[i];
      final shouldAttempt =
          record.status == OfflineClockStatus.pending ||
          (retryFailed &&
              record.status == OfflineClockStatus.failed &&
              record.attempts < _maxAutoRetries);
      if (!shouldAttempt) {
        remaining.add(record);
        continue;
      }

      final attempt = await _attemptRecordSync(
        token: token,
        record: record,
        missingPhotoError:
            'No se encontró la foto local para esta fichada pendiente.',
        connectivityError: 'Sin conexión al sincronizar.',
      );

      switch (attempt.status) {
        case _PendingClockAttemptStatus.synced:
          synced += 1;
          break;
        case _PendingClockAttemptStatus.failed:
          failed += 1;
          remaining.add(attempt.record!);
          break;
        case _PendingClockAttemptStatus.pending:
          remaining.add(attempt.record!);
          stoppedByConnectivity = attempt.connectivityIssue;
          if (attempt.connectivityIssue) {
            remaining.addAll(pending.sublist(i + 1));
            break syncLoop;
          }
          break;
      }
    }

    await _offlineClockQueue.saveForEmployee(
      employeeId: employeeId,
      records: remaining,
    );
    final snapshot = PendingClockSnapshot.fromRecords(remaining);
    await pruneEmployeePhotos(
      employeeId: employeeId,
      keepRecords: snapshot.records,
    );

    final message = stoppedByConnectivity
        ? 'Sincronizadas $synced. Restantes: ${remaining.length}.'
        : failed > 0
        ? 'Sincronizadas $synced. Con error: $failed.'
        : 'Sincronizadas $synced. Cola al dia.';

    return PendingClockSyncBatchResult(
      snapshot: snapshot,
      message: message,
      hadPending: true,
      syncedCount: synced,
      failedCount: failed,
      stoppedByConnectivity: stoppedByConnectivity,
      completedAt: DateTime.now(),
    );
  }

  Future<PendingClockRetryResult> retryRecord({
    required int employeeId,
    required String token,
    required OfflineClockRecord record,
  }) async {
    final attempt = await _attemptRecordSync(
      token: token,
      record: record,
      missingPhotoError: 'No se encontró la foto local para este ítem.',
      connectivityError: 'Error de conexión al sincronizar este ítem.',
    );

    switch (attempt.status) {
      case _PendingClockAttemptStatus.synced:
        await _offlineClockQueue.removeForEmployee(
          employeeId: employeeId,
          recordId: record.id,
        );
        final snapshot = await readSnapshot(employeeId: employeeId);
        await pruneEmployeePhotos(
          employeeId: employeeId,
          keepRecords: snapshot.records,
        );
        return PendingClockRetryResult(
          snapshot: snapshot,
          message: 'Fichada sincronizada correctamente.',
          synced: true,
          completedAt: DateTime.now(),
        );
      case _PendingClockAttemptStatus.failed:
      case _PendingClockAttemptStatus.pending:
        await _upsertRecord(
          employeeId: employeeId,
          updated: attempt.record!,
        );
        final snapshot = await readSnapshot(employeeId: employeeId);
        await pruneEmployeePhotos(
          employeeId: employeeId,
          keepRecords: snapshot.records,
        );
        final message = attempt.missingPhoto
            ? 'No se encontró la foto local del ítem.'
            : attempt.connectivityIssue
            ? 'Sin internet. El ítem sigue pendiente.'
            : 'El ítem sigue con error de validación.';
        return PendingClockRetryResult(
          snapshot: snapshot,
          message: message,
          synced: false,
        );
    }
  }

  Future<PendingClockSnapshot> deleteRecord({
    required int employeeId,
    required String recordId,
  }) async {
    final current = await _offlineClockQueue.readForEmployee(employeeId);
    String? photoPathToDelete;
    for (final item in current) {
      if (item.id == recordId) {
        photoPathToDelete = item.fotoPath;
        break;
      }
    }

    await _offlineClockQueue.removeForEmployee(
      employeeId: employeeId,
      recordId: recordId,
    );
    await _clockPhotoCache.deleteFile(photoPathToDelete);

    final snapshot = await readSnapshot(employeeId: employeeId);
    await pruneEmployeePhotos(
      employeeId: employeeId,
      keepRecords: snapshot.records,
    );
    return snapshot;
  }

  Future<PendingClockSnapshot> clearEmployee({required int employeeId}) async {
    final current = await _offlineClockQueue.readForEmployee(employeeId);
    for (final record in current) {
      await _clockPhotoCache.deleteFile(record.fotoPath);
    }

    await _offlineClockQueue.clearForEmployee(employeeId);
    await pruneEmployeePhotos(
      employeeId: employeeId,
      keepRecords: const <OfflineClockRecord>[],
    );
    return const PendingClockSnapshot.empty();
  }

  Future<void> pruneEmployeePhotos({
    required int employeeId,
    Iterable<OfflineClockRecord>? keepRecords,
  }) async {
    final records = keepRecords?.toList(growable: false) ??
        (await _offlineClockQueue.readForEmployee(employeeId));
    final keepPaths = records
        .map((item) => (item.fotoPath ?? '').trim())
        .where((value) => value.isNotEmpty);
    await _clockPhotoCache.pruneEmployee(
      employeeId: employeeId,
      keepPaths: keepPaths,
    );
  }

  Future<void> _upsertRecord({
    required int employeeId,
    required OfflineClockRecord updated,
  }) async {
    final items = await _offlineClockQueue.readForEmployee(employeeId);
    var replaced = false;
    final next = items
        .map((item) {
          if (item.id == updated.id) {
            replaced = true;
            return updated;
          }
          return item;
        })
        .toList(growable: true);
    if (!replaced) {
      next.add(updated);
    }
    await _offlineClockQueue.saveForEmployee(
      employeeId: employeeId,
      records: next,
    );
  }

  Future<_PendingClockAttemptResult> _attemptRecordSync({
    required String token,
    required OfflineClockRecord record,
    required String missingPhotoError,
    required String connectivityError,
  }) async {
    final attempted = record.copyWith(
      attempts: record.attempts + 1,
      lastAttemptAt: DateTime.now(),
      lastError: null,
      status: OfflineClockStatus.pending,
    );

    try {
      final foto = await _resolveRecordPhoto(attempted);
      if (attempted.hasPhotoReference && (foto ?? '').trim().isEmpty) {
        return _PendingClockAttemptResult(
          status: _PendingClockAttemptStatus.failed,
          record: attempted.copyWith(
            status: OfflineClockStatus.failed,
            lastError: missingPhotoError,
          ),
          missingPhoto: true,
        );
      }

      await _apiClient.registrarScanQr(
        token: token,
        qrToken: attempted.qrToken,
        lat: attempted.lat,
        lon: attempted.lon,
        foto: foto,
        eventAt: attempted.eventAt,
      );
      await _clockPhotoCache.deleteFile(attempted.fotoPath);
      return const _PendingClockAttemptResult(
        status: _PendingClockAttemptStatus.synced,
      );
    } on ApiException catch (error) {
      final isConnectivityIssue = error.statusCode == null;
      return _PendingClockAttemptResult(
        status: isConnectivityIssue
            ? _PendingClockAttemptStatus.pending
            : _PendingClockAttemptStatus.failed,
        record: attempted.copyWith(
          status: isConnectivityIssue
              ? OfflineClockStatus.pending
              : OfflineClockStatus.failed,
          lastError: isConnectivityIssue ? connectivityError : error.message,
        ),
        connectivityIssue: isConnectivityIssue,
      );
    } catch (_) {
      return _PendingClockAttemptResult(
        status: _PendingClockAttemptStatus.pending,
        record: attempted.copyWith(
          status: OfflineClockStatus.pending,
          lastError: connectivityError,
        ),
        connectivityIssue: true,
      );
    }
  }

  Future<String?> _resolveRecordPhoto(OfflineClockRecord record) async {
    final inline = (record.foto ?? '').trim();
    if (inline.isNotEmpty) {
      return inline;
    }
    return _clockPhotoCache.readAsBase64(record.fotoPath);
  }
}

class PendingClockSnapshot {
  const PendingClockSnapshot({
    required this.records,
    required this.total,
    required this.failed,
  });

  const PendingClockSnapshot.empty()
    : records = const <OfflineClockRecord>[],
      total = 0,
      failed = 0;

  factory PendingClockSnapshot.fromRecords(Iterable<OfflineClockRecord> records) {
    final sorted = records.toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    var failed = 0;
    for (final record in sorted) {
      if (record.status == OfflineClockStatus.failed) {
        failed += 1;
      }
    }
    return PendingClockSnapshot(
      records: List<OfflineClockRecord>.unmodifiable(sorted),
      total: sorted.length,
      failed: failed,
    );
  }

  final List<OfflineClockRecord> records;
  final int total;
  final int failed;
}

class PendingClockSyncBatchResult {
  const PendingClockSyncBatchResult({
    required this.snapshot,
    required this.message,
    required this.hadPending,
    required this.syncedCount,
    required this.failedCount,
    required this.stoppedByConnectivity,
    this.completedAt,
  });

  final PendingClockSnapshot snapshot;
  final String message;
  final bool hadPending;
  final int syncedCount;
  final int failedCount;
  final bool stoppedByConnectivity;
  final DateTime? completedAt;

  bool get shouldNotify => stoppedByConnectivity || failedCount > 0;
}

class PendingClockRetryResult {
  const PendingClockRetryResult({
    required this.snapshot,
    required this.message,
    required this.synced,
    this.completedAt,
  });

  final PendingClockSnapshot snapshot;
  final String message;
  final bool synced;
  final DateTime? completedAt;
}

class _PendingClockAttemptResult {
  const _PendingClockAttemptResult({
    required this.status,
    this.record,
    this.connectivityIssue = false,
    this.missingPhoto = false,
  });

  final _PendingClockAttemptStatus status;
  final OfflineClockRecord? record;
  final bool connectivityIssue;
  final bool missingPhoto;
}

enum _PendingClockAttemptStatus {
  synced,
  pending,
  failed,
}
