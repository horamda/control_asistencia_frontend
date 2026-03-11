import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OfflineClockQueue {
  OfflineClockQueue({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _queueKey = 'offline_clock_queue_v1';
  static const _maxItems = 40;

  final FlutterSecureStorage _secureStorage;
  final Random _random = Random();

  Future<List<OfflineClockRecord>> readAll() async {
    try {
      final raw = await _secureStorage.read(key: _queueKey);
      if (raw == null || raw.trim().isEmpty) {
        return const <OfflineClockRecord>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        try {
          await _secureStorage.delete(key: _queueKey);
        } catch (_) {}
        return const <OfflineClockRecord>[];
      }
      final items = <OfflineClockRecord>[];
      for (final value in decoded) {
        if (value is Map<String, dynamic>) {
          final parsed = OfflineClockRecord.fromJson(value).compactPhotoPayload();
          if (parsed.isValid) {
            items.add(parsed);
          }
          continue;
        }
        if (value is Map) {
          final parsed = OfflineClockRecord.fromJson(
            Map<String, dynamic>.from(value),
          ).compactPhotoPayload();
          if (parsed.isValid) {
            items.add(parsed);
          }
        }
      }
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (_) {
      try {
        await _secureStorage.delete(key: _queueKey);
      } catch (_) {}
      return const <OfflineClockRecord>[];
    }
  }

  Future<List<OfflineClockRecord>> readForEmployee(int employeeId) async {
    final all = await readAll();
    return all.where((item) => item.employeeId == employeeId).toList();
  }

  Future<int> countForEmployee(int employeeId) async {
    final items = await readForEmployee(employeeId);
    return items.length;
  }

  Future<OfflineClockSummary> summaryForEmployee(int employeeId) async {
    final items = await readForEmployee(employeeId);
    var pending = 0;
    var failed = 0;
    for (final item in items) {
      if (item.status == OfflineClockStatus.failed) {
        failed += 1;
      } else {
        pending += 1;
      }
    }
    return OfflineClockSummary(
      total: items.length,
      pending: pending,
      failed: failed,
    );
  }

  Future<void> enqueue({
    required int employeeId,
    required String qrToken,
    required DateTime eventAt,
    double? lat,
    double? lon,
    String? foto,
    String? fotoPath,
  }) async {
    final all = await readAll();
    final cleanFotoPath = (fotoPath ?? '').trim();
    final cleanFotoInline = (foto ?? '').trim();
    final shouldStoreInlinePhoto =
        cleanFotoPath.isEmpty && cleanFotoInline.isNotEmpty;
    all.add(
      OfflineClockRecord(
        id: _newId(),
        employeeId: employeeId,
        qrToken: qrToken.trim(),
        eventAt: eventAt,
        lat: lat,
        lon: lon,
        foto: shouldStoreInlinePhoto ? cleanFotoInline : null,
        fotoPath: cleanFotoPath.isEmpty ? null : cleanFotoPath,
        createdAt: DateTime.now(),
      ),
    );
    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (all.length > _maxItems) {
      all.removeRange(0, all.length - _maxItems);
    }
    await _writeAll(all);
  }

  Future<void> saveForEmployee({
    required int employeeId,
    required List<OfflineClockRecord> records,
  }) async {
    final all = await readAll();
    final others = all.where((item) => item.employeeId != employeeId).toList();
    final merged = <OfflineClockRecord>[...others, ...records];
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await _writeAll(merged);
  }

  Future<void> removeForEmployee({
    required int employeeId,
    required String recordId,
  }) async {
    final all = await readAll();
    all.removeWhere(
      (item) => item.employeeId == employeeId && item.id == recordId,
    );
    await _writeAll(all);
  }

  Future<void> clearForEmployee(int employeeId) async {
    final all = await readAll();
    all.removeWhere((item) => item.employeeId == employeeId);
    await _writeAll(all);
  }

  String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rnd = _random.nextInt(1 << 20);
    return '${now}_$rnd';
  }

  Future<void> _writeAll(List<OfflineClockRecord> records) async {
    final normalized = records
        .where((item) => item.isValid)
        .map((item) => item.compactPhotoPayload())
        .toList(growable: false);
    final payload = normalized
        .map((item) => item.toJson())
        .toList(growable: false);
    await _secureStorage.write(key: _queueKey, value: jsonEncode(payload));
  }
}

class OfflineClockRecord {
  static const Object _notSet = Object();

  OfflineClockRecord({
    required this.id,
    required this.employeeId,
    required this.qrToken,
    required this.eventAt,
    required this.createdAt,
    this.status = OfflineClockStatus.pending,
    this.attempts = 0,
    this.lastAttemptAt,
    this.lastError,
    this.lat,
    this.lon,
    this.foto,
    this.fotoPath,
  });

  final String id;
  final int employeeId;
  final String qrToken;
  final DateTime eventAt;
  final DateTime createdAt;
  final OfflineClockStatus status;
  final int attempts;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final double? lat;
  final double? lon;
  final String? foto;
  final String? fotoPath;

  bool get hasPhotoReference =>
      (foto ?? '').trim().isNotEmpty || (fotoPath ?? '').trim().isNotEmpty;
  bool get isValid =>
      id.trim().isNotEmpty &&
      employeeId > 0 &&
      qrToken.trim().isNotEmpty;

  OfflineClockRecord compactPhotoPayload() {
    final cleanPath = (fotoPath ?? '').trim();
    final cleanInline = (foto ?? '').trim();
    if (cleanPath.isEmpty || cleanInline.isEmpty) {
      return this;
    }
    return copyWith(
      foto: null,
      fotoPath: cleanPath,
    );
  }

  OfflineClockRecord copyWith({
    String? id,
    int? employeeId,
    String? qrToken,
    DateTime? eventAt,
    DateTime? createdAt,
    OfflineClockStatus? status,
    int? attempts,
    Object? lastAttemptAt = _notSet,
    Object? lastError = _notSet,
    Object? lat = _notSet,
    Object? lon = _notSet,
    Object? foto = _notSet,
    Object? fotoPath = _notSet,
  }) {
    return OfflineClockRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      qrToken: qrToken ?? this.qrToken,
      eventAt: eventAt ?? this.eventAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: identical(lastAttemptAt, _notSet)
          ? this.lastAttemptAt
          : lastAttemptAt as DateTime?,
      lastError: identical(lastError, _notSet)
          ? this.lastError
          : lastError as String?,
      lat: identical(lat, _notSet) ? this.lat : lat as double?,
      lon: identical(lon, _notSet) ? this.lon : lon as double?,
      foto: identical(foto, _notSet) ? this.foto : foto as String?,
      fotoPath: identical(fotoPath, _notSet)
          ? this.fotoPath
          : fotoPath as String?,
    );
  }

  factory OfflineClockRecord.fromJson(Map<String, dynamic> json) {
    final eventAtRaw = json['event_at'] as String?;
    final createdAtRaw = json['created_at'] as String?;
    final lastAttemptAtRaw = json['last_attempt_at'] as String?;
    final eventAt = DateTime.tryParse(eventAtRaw ?? '') ?? DateTime.now();
    final createdAt = DateTime.tryParse(createdAtRaw ?? '') ?? eventAt;
    final lastAttemptAt = DateTime.tryParse(lastAttemptAtRaw ?? '');
    return OfflineClockRecord(
      id: ((json['id'] as String?) ?? '').trim(),
      employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
      qrToken: ((json['qr_token'] as String?) ?? '').trim(),
      eventAt: eventAt,
      createdAt: createdAt,
      status: _statusFromRaw(json['status']),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastAttemptAt: lastAttemptAt,
      lastError: (json['last_error'] as String?)?.trim(),
      lat: _toDouble(json['lat']),
      lon: _toDouble(json['lon']),
      foto: (json['foto'] as String?)?.trim(),
      fotoPath: (json['foto_path'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'employee_id': employeeId,
      'qr_token': qrToken,
      'event_at': eventAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'status': status.value,
      'attempts': attempts,
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'last_error': lastError,
      'lat': lat,
      'lon': lon,
      'foto': foto,
      'foto_path': fotoPath,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static OfflineClockStatus _statusFromRaw(dynamic value) {
    final raw = (value as String?)?.trim().toLowerCase();
    if (raw == OfflineClockStatus.failed.value) {
      return OfflineClockStatus.failed;
    }
    return OfflineClockStatus.pending;
  }
}

enum OfflineClockStatus {
  pending('pending'),
  failed('failed');

  const OfflineClockStatus(this.value);
  final String value;
}

class OfflineClockSummary {
  const OfflineClockSummary({
    required this.total,
    required this.pending,
    required this.failed,
  });

  final int total;
  final int pending;
  final int failed;
}
