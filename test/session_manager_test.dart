import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/auth/biometric_auth_service.dart';
import 'package:ficharqr/src/core/auth/session_manager.dart';
import 'package:ficharqr/src/core/auth/session_storage.dart';
import 'package:ficharqr/src/core/feedback/clock_feedback_profile.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:http/http.dart' as http;

void main() {
  group('SessionManager bootstrap', () {
    test('bloquea la sesion restaurada antes de habilitar el token', () async {
      final session = LoginResponse(
        token: 'stored-token',
        empleado: EmployeeSummary(
          id: 10,
          dni: '30111222',
          nombre: 'Ana',
          apellido: 'Perez',
          empresaId: 5,
        ),
      );
      final storage = _FakeSessionStorage(
        envelope: StoredSessionEnvelope(
          session: session,
          sessionStartedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          lastActivityAt: DateTime.now().subtract(const Duration(minutes: 1)),
          lastRefreshAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        biometricEnabled: true,
      );
      final biometric = _FakeBiometricAuthService(
        available: true,
        authenticateResult: false,
      );
      final apiClient = _FakeMobileApiClient();
      final manager = SessionManager(
        apiClient: apiClient,
        sessionStorage: storage,
        biometricAuthService: biometric,
      );

      await manager.bootstrap();

      expect(manager.isBootstrapping, isFalse);
      expect(manager.session, isNotNull);
      expect(manager.isLocked, isTrue);
      expect(manager.currentTokenFromProvider(), isNull);
      expect(manager.statusMessage, 'Desbloquea la sesion con huella.');
      expect(apiClient.refreshCalls, 0);

      manager.dispose();
      apiClient.dispose();
    });
  });
}

class _FakeSessionStorage extends SessionStorage {
  _FakeSessionStorage({
    this.envelope,
    this.biometricEnabled = true,
  });

  StoredSessionEnvelope? envelope;
  bool biometricEnabled;
  ClockFeedbackProfile clockFeedbackProfile = ClockFeedbackProfile.balanced;
  bool cleared = false;

  @override
  Future<StoredSessionEnvelope?> readEnvelope() async => envelope;

  @override
  Future<void> saveEnvelope(StoredSessionEnvelope nextEnvelope) async {
    envelope = nextEnvelope;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    envelope = null;
  }

  @override
  Future<bool?> readBiometricEnabled() async => biometricEnabled;

  @override
  Future<void> saveBiometricEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }

  @override
  Future<ClockFeedbackProfile> readClockFeedbackProfile() async {
    return clockFeedbackProfile;
  }

  @override
  Future<void> saveClockFeedbackProfile(ClockFeedbackProfile profile) async {
    clockFeedbackProfile = profile;
  }
}

class _FakeBiometricAuthService extends BiometricAuthService {
  _FakeBiometricAuthService({
    required this.available,
    required this.authenticateResult,
  });

  final bool available;
  final bool authenticateResult;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({
    String reason = 'Usa tu huella para continuar.',
  }) async {
    return authenticateResult;
  }
}

class _FakeMobileApiClient extends MobileApiClient {
  _FakeMobileApiClient()
    : super(baseUrl: 'https://example.com', httpClient: _NoopHttpClient());

  int refreshCalls = 0;

  @override
  Future<String> refreshToken({required String token}) async {
    refreshCalls += 1;
    return 'refreshed-token';
  }
}

class _NoopHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError('No deberia ejecutar requests HTTP en este test.');
  }
}
