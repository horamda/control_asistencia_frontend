import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../feedback/clock_feedback_profile.dart';
import '../network/mobile_api_client.dart';

class SessionStorage {
  SessionStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _sessionKey = 'auth_session_v1';
  static const _biometricEnabledKey = 'biometric_enabled_v1';
  static const _clockFeedbackProfileKey = 'clock_feedback_profile_v1';

  final FlutterSecureStorage _secureStorage;

  Future<StoredSessionEnvelope?> readEnvelope() async {
    try {
      final raw = await _secureStorage.read(key: _sessionKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clear();
        return null;
      }
      final json = Map<String, dynamic>.from(decoded);
      final envelope = StoredSessionEnvelope.fromJson(json);
      if (envelope.session.token.trim().isEmpty ||
          envelope.session.empleado.id <= 0) {
        await clear();
        return null;
      }
      return envelope;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<LoginResponse?> read() async {
    final envelope = await readEnvelope();
    return envelope?.session;
  }

  Future<void> saveEnvelope(StoredSessionEnvelope envelope) async {
    try {
      await _secureStorage.write(
        key: _sessionKey,
        value: jsonEncode(envelope.toJson()),
      );
    } catch (_) {}
  }

  Future<void> save(LoginResponse session) async {
    await saveEnvelope(
      StoredSessionEnvelope(
        session: session,
        sessionStartedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        lastRefreshAt: DateTime.now(),
      ),
    );
  }

  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
    } catch (_) {}
  }

  Future<bool?> readBiometricEnabled() async {
    try {
      final raw = await _secureStorage.read(key: _biometricEnabledKey);
      if (raw == null) {
        return null;
      }
      final value = raw.trim().toLowerCase();
      if (value == 'true') {
        return true;
      }
      if (value == 'false') {
        return false;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBiometricEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _biometricEnabledKey,
        value: enabled ? 'true' : 'false',
      );
    } catch (_) {}
  }

  Future<ClockFeedbackProfile> readClockFeedbackProfile() async {
    try {
      final raw = await _secureStorage.read(key: _clockFeedbackProfileKey);
      return ClockFeedbackProfileCodec.fromStorageValue(raw);
    } catch (_) {
      return ClockFeedbackProfile.balanced;
    }
  }

  Future<void> saveClockFeedbackProfile(ClockFeedbackProfile profile) async {
    try {
      await _secureStorage.write(
        key: _clockFeedbackProfileKey,
        value: profile.storageValue,
      );
    } catch (_) {}
  }
}

class StoredSessionEnvelope {
  StoredSessionEnvelope({
    required this.session,
    required this.sessionStartedAt,
    required this.lastActivityAt,
    required this.lastRefreshAt,
  });

  final LoginResponse session;
  final DateTime sessionStartedAt;
  final DateTime lastActivityAt;
  final DateTime lastRefreshAt;

  factory StoredSessionEnvelope.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('session')) {
      final rawSession = json['session'];
      final sessionJson = rawSession is Map<String, dynamic>
          ? rawSession
          : Map<String, dynamic>.from(rawSession as Map);
      final session = LoginResponse.fromJson(sessionJson);
      final now = DateTime.now();
      return StoredSessionEnvelope(
        session: session,
        sessionStartedAt:
            DateTime.tryParse((json['session_started_at'] as String?) ?? '') ??
            now,
        lastActivityAt:
            DateTime.tryParse((json['last_activity_at'] as String?) ?? '') ??
            now,
        lastRefreshAt:
            DateTime.tryParse((json['last_refresh_at'] as String?) ?? '') ??
            now,
      );
    }

    // Backward compatibility with legacy shape where LoginResponse was stored directly.
    final session = LoginResponse.fromJson(json);
    final now = DateTime.now();
    return StoredSessionEnvelope(
      session: session,
      sessionStartedAt: now,
      lastActivityAt: now,
      lastRefreshAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'session': session.toJson(),
      'session_started_at': sessionStartedAt.toIso8601String(),
      'last_activity_at': lastActivityAt.toIso8601String(),
      'last_refresh_at': lastRefreshAt.toIso8601String(),
    };
  }
}
