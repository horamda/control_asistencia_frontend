import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persiste credenciales en texto plano protegidas por el keystore del
/// dispositivo, usadas exclusivamente para re-autenticar con biometría
/// después de que la sesión expire.
///
/// A diferencia de [OfflineCredentialsCache], guarda la contraseña sin
/// hashear porque necesita enviarla al servidor para obtener un token nuevo.
/// La seguridad recae en:
///   1. [FlutterSecureStorage] (AES-256 / Keychain — cifrado en hardware)
///   2. La verificación biométrica previa obligatoria antes de leer las creds.
///
/// Se limpia en logout manual. No se limpia en expiración de sesión.
class BiometricCredentialCache {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _key = 'biometric_reauth_v1';

  Future<void> save({required String dni, required String password}) async {
    try {
      final encoded = jsonEncode({'dni': dni, 'pw': password});
      await _storage.write(key: _key, value: encoded);
    } catch (_) {}
  }

  Future<BiometricCredential?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final dni = json['dni'] as String?;
      final pw = json['pw'] as String?;
      if (dni == null || pw == null || dni.isEmpty || pw.isEmpty) return null;
      return BiometricCredential(dni: dni, password: pw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> get hasCredentials async {
    final c = await read();
    return c != null;
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

class BiometricCredential {
  const BiometricCredential({required this.dni, required this.password});
  final String dni;
  final String password;
}
