import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/mobile_api_client.dart';

/// Persiste credenciales de login para permitir acceso offline.
///
/// Las credenciales se almacenan cifradas en el keychain/keystore del
/// dispositivo (FlutterSecureStorage usa AES-256 en Android y Keychain en iOS).
///
/// La contraseña nunca se guarda en texto plano: se aplica SHA-256 con un
/// salt aleatorio de 32 bytes (HMAC-SHA256). Esto garantiza que incluso si
/// el almacenamiento cifrado se ve comprometido, la contraseña original no
/// puede recuperarse.
///
/// Caducidad: [maxAgeHours] horas desde el ultimo login online exitoso.
/// Pasado ese tiempo, el acceso offline queda bloqueado hasta el proximo
/// login con conexion.
class OfflineCredentialsCache {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyDni = '_off_cred_dni';
  static const _keyPwHash = '_off_cred_pw_hash';   // hash SHA-256
  static const _keyPwSalt = '_off_cred_pw_salt';   // salt hex (32 bytes)
  static const _keyEmpleado = '_off_cred_emp';
  static const _keySavedAt = '_off_cred_at';
  static const maxAgeHours = 72; // 3 dias de gracia

  static final _rng = Random.secure();

  /// Genera un salt aleatorio de 32 bytes devuelto como hex string.
  static String _newSalt() {
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _rng.nextInt(256);
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Devuelve HMAC-SHA256(password, saltHex) como hex string.
  static String _hashPassword(String password, String saltHex) {
    final saltBytes = utf8.encode(saltHex);
    final hmac = Hmac(sha256, saltBytes);
    final digest = hmac.convert(utf8.encode(password));
    return digest.toString();
  }

  /// Guarda las credenciales tras un login online exitoso.
  /// La contraseña se hashea antes de persistirse.
  Future<void> save({
    required String dni,
    required String password,
    required EmployeeSummary empleado,
  }) async {
    final salt = _newSalt();
    final pwHash = _hashPassword(password, salt);
    await Future.wait([
      _storage.write(key: _keyDni, value: dni.trim()),
      _storage.write(key: _keyPwHash, value: pwHash),
      _storage.write(key: _keyPwSalt, value: salt),
      _storage.write(
        key: _keyEmpleado,
        value: jsonEncode(empleado.toJson()),
      ),
      _storage.write(
        key: _keySavedAt,
        value: DateTime.now().toIso8601String(),
      ),
    ]);
  }

  /// Valida las credenciales ingresadas contra las almacenadas.
  Future<OfflineValidationResult> validate({
    required String dni,
    required String password,
  }) async {
    final storedDni = await _storage.read(key: _keyDni);
    final storedPwHash = await _storage.read(key: _keyPwHash);
    final storedSalt = await _storage.read(key: _keyPwSalt);
    final savedAt = await _storage.read(key: _keySavedAt);
    final empleadoJson = await _storage.read(key: _keyEmpleado);

    if (storedDni == null || storedPwHash == null || storedSalt == null ||
        empleadoJson == null) {
      return const OfflineValidationResult.noCredentials();
    }

    // Verificar caducidad
    if (savedAt != null) {
      final saved = DateTime.tryParse(savedAt);
      if (saved != null &&
          DateTime.now().difference(saved).inHours >= maxAgeHours) {
        return const OfflineValidationResult.expired();
      }
    }

    // Verificar credenciales (comparacion de hashes)
    if (storedDni != dni.trim()) {
      return const OfflineValidationResult.wrongCredentials();
    }
    final inputHash = _hashPassword(password, storedSalt);
    if (inputHash != storedPwHash) {
      return const OfflineValidationResult.wrongCredentials();
    }

    // Deserializar empleado
    try {
      final map = jsonDecode(empleadoJson) as Map<String, dynamic>;
      final empleado = EmployeeSummary.fromJson(map);
      return OfflineValidationResult.ok(empleado);
    } catch (_) {
      return const OfflineValidationResult.noCredentials();
    }
  }

  /// Indica si hay credenciales guardadas (sin validar si son correctas).
  Future<bool> get hasCredentials async {
    final dni = await _storage.read(key: _keyDni);
    return dni != null && dni.isNotEmpty;
  }

  /// Elimina las credenciales almacenadas.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyDni),
      _storage.delete(key: _keyPwHash),
      _storage.delete(key: _keyPwSalt),
      _storage.delete(key: _keyEmpleado),
      _storage.delete(key: _keySavedAt),
    ]);
  }
}

// ── Result type ───────────────────────────────────────────────────────────────

enum OfflineValidationStatus { ok, noCredentials, expired, wrongCredentials }

class OfflineValidationResult {
  const OfflineValidationResult._({
    required this.status,
    this.empleado,
  });

  const OfflineValidationResult.ok(EmployeeSummary empleado)
      : this._(status: OfflineValidationStatus.ok, empleado: empleado);

  const OfflineValidationResult.noCredentials()
      : this._(status: OfflineValidationStatus.noCredentials);

  const OfflineValidationResult.expired()
      : this._(status: OfflineValidationStatus.expired);

  const OfflineValidationResult.wrongCredentials()
      : this._(status: OfflineValidationStatus.wrongCredentials);

  final OfflineValidationStatus status;
  final EmployeeSummary? empleado;

  bool get isOk => status == OfflineValidationStatus.ok;

  String get errorMessage {
    return switch (status) {
      OfflineValidationStatus.ok => '',
      OfflineValidationStatus.noCredentials =>
        'Sin credenciales guardadas. Ingresá con conexión al menos una vez.',
      OfflineValidationStatus.expired =>
        'Las credenciales offline expiraron. Conectate y volvé a ingresar.',
      OfflineValidationStatus.wrongCredentials =>
        'DNI o contraseña incorrectos.',
    };
  }
}
