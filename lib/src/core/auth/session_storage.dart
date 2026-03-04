import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/mobile_api_client.dart';

class SessionStorage {
  SessionStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _sessionKey = 'auth_session_v1';

  final FlutterSecureStorage _secureStorage;

  Future<LoginResponse?> read() async {
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
      final session = LoginResponse.fromJson(json);
      if (session.token.trim().isEmpty || session.empleado.id <= 0) {
        await clear();
        return null;
      }
      return session;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(LoginResponse session) async {
    try {
      await _secureStorage.write(
        key: _sessionKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
    } catch (_) {}
  }
}
