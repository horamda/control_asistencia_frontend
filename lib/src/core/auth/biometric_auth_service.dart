import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> isAvailable() async {
    try {
      final isSupported = await _localAuthentication.isDeviceSupported();
      if (!isSupported) {
        return false;
      }
      final available = await _localAuthentication.getAvailableBiometrics();
      if (available.isEmpty) {
        return false;
      }
      return available.any(
        (type) =>
            type == BiometricType.fingerprint ||
            type == BiometricType.strong ||
            type == BiometricType.weak,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: 'Confirma tu huella para ingresar',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
