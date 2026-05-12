import 'offline_clock_queue.dart';
import 'pending_clock_sync_service.dart';

class PendingQueueController {
  PendingQueueController({required PendingClockSyncService syncService})
    : _syncService = syncService;

  final PendingClockSyncService _syncService;

  Future<PendingQueueState> load({
    required int employeeId,
    required PendingQueueState current,
  }) async {
    final snapshot = await _syncService.readSnapshot(employeeId: employeeId);
    return current.copyWith(snapshot: snapshot);
  }

  PendingQueueState applySnapshot({
    required PendingQueueState current,
    required PendingClockSnapshot snapshot,
  }) {
    return current.copyWith(snapshot: snapshot);
  }

  PendingQueueState startSync({
    required PendingQueueState current,
    bool isBackground = false,
  }) {
    return current.copyWith(
      syncing: true,
      lastMessage: isBackground ? current.lastMessage : null,
    );
  }

  Future<PendingQueueState> syncAll({
    required int employeeId,
    required String token,
    required PendingQueueState current,
    bool isBackground = false,
  }) async {
    try {
      final result = await _syncService.syncAll(
        employeeId: employeeId,
        token: token,
        retryFailed: !isBackground,
      );
      return current.copyWith(
        snapshot: result.snapshot,
        syncing: false,
        lastSyncAt: result.completedAt ?? current.lastSyncAt,
        lastMessage: (!isBackground || result.shouldNotify)
            ? result.message
            : current.lastMessage,
      );
    } catch (_) {
      return current.copyWith(
        syncing: false,
        lastMessage: isBackground
            ? current.lastMessage
            : 'No se pudo actualizar la cola local de pendientes.',
      );
    }
  }

  Future<PendingQueueState> retryRecord({
    required int employeeId,
    required String token,
    required OfflineClockRecord record,
    required PendingQueueState current,
  }) async {
    try {
      final result = await _syncService.retryRecord(
        employeeId: employeeId,
        token: token,
        record: record,
      );
      return current.copyWith(
        snapshot: result.snapshot,
        syncing: false,
        lastSyncAt: result.completedAt ?? current.lastSyncAt,
        lastMessage: result.message,
      );
    } catch (_) {
      return current.copyWith(
        syncing: false,
        lastMessage: 'No se pudo guardar el estado local del item pendiente.',
      );
    }
  }

  Future<PendingQueueState> deleteRecord({
    required int employeeId,
    required String recordId,
    required PendingQueueState current,
  }) async {
    try {
      final snapshot = await _syncService.deleteRecord(
        employeeId: employeeId,
        recordId: recordId,
      );
      return current.copyWith(snapshot: snapshot);
    } catch (_) {
      return current.copyWith(
        lastMessage: 'No se pudo eliminar el pendiente local. Reintenta.',
      );
    }
  }

  Future<PendingQueueState> clearAll({
    required int employeeId,
    required PendingQueueState current,
  }) async {
    try {
      final snapshot = await _syncService.clearEmployee(employeeId: employeeId);
      return current.copyWith(
        snapshot: snapshot,
        lastMessage: 'Cola limpiada.',
      );
    } catch (_) {
      return current.copyWith(
        lastMessage: 'No se pudo limpiar la cola local. Reintenta.',
      );
    }
  }
}

class PendingQueueState {
  static const Object _notSet = Object();

  const PendingQueueState({
    this.snapshot = const PendingClockSnapshot.empty(),
    this.syncing = false,
    this.lastSyncAt,
    this.lastMessage,
  });

  final PendingClockSnapshot snapshot;
  final bool syncing;
  final DateTime? lastSyncAt;
  final String? lastMessage;

  int get total => snapshot.total;
  int get failed => snapshot.failed;
  int get cleanCount => (total - failed) < 0 ? 0 : total - failed;
  List<OfflineClockRecord> get records => snapshot.records;
  bool get hasUrgency => total > 0 || failed > 0;
  bool get hasErrors => failed > 0;
  bool get hasPending => total > 0;

  PendingQueueState copyWith({
    Object? snapshot = _notSet,
    bool? syncing,
    Object? lastSyncAt = _notSet,
    Object? lastMessage = _notSet,
  }) {
    return PendingQueueState(
      snapshot: identical(snapshot, _notSet)
          ? this.snapshot
          : snapshot as PendingClockSnapshot,
      syncing: syncing ?? this.syncing,
      lastSyncAt: identical(lastSyncAt, _notSet)
          ? this.lastSyncAt
          : lastSyncAt as DateTime?,
      lastMessage: identical(lastMessage, _notSet)
          ? this.lastMessage
          : lastMessage as String?,
    );
  }
}
