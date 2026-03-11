import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

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

  Future<bool> authenticate({
    String reason = 'Usa tu huella para continuar.',
  }) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Autenticacion requerida',
            biometricHint: 'Toca el sensor de huellas digitales',
            biometricNotRecognized:
                'Huella no reconocida. Intenta nuevamente.',
            biometricRequiredTitle: 'Huella requerida',
            biometricSuccess: 'Huella validada',
            cancelButton: 'Cancelar',
            goToSettingsButton: 'Ir a configuracion',
            goToSettingsDescription:
                'Configura tu huella para habilitar este acceso.',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancelar',
            goToSettingsButton: 'Ir a configuracion',
            goToSettingsDescription:
                'Habilita Touch ID o Face ID para continuar.',
            lockOut:
                'Biometria bloqueada temporalmente. Desbloquea el dispositivo e intenta de nuevo.',
          ),
        ],
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
