import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../core/auth/biometric_credential_cache.dart';
import '../core/auth/offline_credentials_cache.dart';
import '../core/auth/session_manager.dart';
import '../core/network/mobile_api_client.dart';
import '../core/network/pinned_http_client.dart';
import '../core/permissions/device_permission_bootstrap.dart';
import 'attendance/attendance_home_page.dart';
import 'auth/login_page.dart';
import 'widgets/centered_snackbar.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  late final MobileApiClient _apiClient;
  late final SessionManager _sessionManager;
  late final DevicePermissionBootstrap _devicePermissionBootstrap;
  final _offlineCredentialsCache = OfflineCredentialsCache();
  final _biometricCredentialCache = BiometricCredentialCache();
  bool _hasBiometricReauthCreds = false;
  bool _biometricReauthApiLoading = false;
  String? _biometricReauthError;
  bool _autoTriggeredReauth = false;
  bool _bootstrappingDevicePermissions = false;
  bool _devicePermissionBootstrapDoneForSession = false;
  bool _permissionBootstrapMessageShownForSession = false;
  String? _permissionBootstrapSessionKey;

  void _onSessionChanged() {
    if (!mounted) {
      return;
    }
    _scheduleDevicePermissionBootstrap();
    _maybeTriggerBiometricAutoReauth();
    setState(() {});
  }

  void _maybeTriggerBiometricAutoReauth() {
    if (_autoTriggeredReauth) return;
    if (_sessionManager.isBootstrapping) return;
    if (_sessionManager.session != null) return;
    if (_sessionManager.isLocked) return;
    if (!_hasBiometricReauthCreds) return;
    if (!_sessionManager.biometricAvailable) return;
    if (!_sessionManager.biometricEnabled) return;
    _autoTriggeredReauth = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_onBiometricReauth());
    });
  }

  @override
  void initState() {
    super.initState();
    assert(
      AppConfig.current.apiBaseUrl.isNotEmpty,
      'API_BASE_URL no fue inyectada en tiempo de compilacion.\n'
      'Ejecuta: flutter build apk --dart-define=API_BASE_URL=https://tu-backend.com',
    );
    _apiClient = MobileApiClient(
      baseUrl: AppConfig.current.apiBaseUrl,
      mobileApiPrefix: AppConfig.current.mobileApiPrefix,
    );
    _devicePermissionBootstrap = DevicePermissionBootstrap();
    _sessionManager = SessionManager(
      apiClient: _apiClient,
      idleTimeout: AppConfig.current.sessionIdleTimeout,
      maxSessionAge: AppConfig.current.sessionMaxAge,
      proactiveRefreshInterval:
          AppConfig.current.sessionProactiveRefreshInterval,
    );
    _apiClient.configureAuth(
      tokenProvider: _sessionManager.currentTokenFromProvider,
      onUnauthorizedRefresh: _sessionManager.refreshTokenForProvider,
      onUnauthorized: _sessionManager.forceExpireFromProvider,
    );
    _sessionManager.addListener(_onSessionChanged);
    _sessionManager.onUnauthorized.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
    _sessionManager.bootstrap();
    unawaited(_checkBiometricReauthCreds());
    // Upgrade al cliente con certificate pinning en cuanto el asset este listo.
    // Si el asset no existe todavia, PinnedHttpClient.create() devuelve un
    // http.Client() estandar sin lanzar excepcion (ver pinned_http_client.dart).
    unawaited(
      PinnedHttpClient.create().then(_apiClient.upgradeHttpClient),
    );
  }

  void _scheduleDevicePermissionBootstrap() {
    final sessionKey = _currentSessionPermissionKey();
    if (sessionKey == null) {
      _devicePermissionBootstrapDoneForSession = false;
      _permissionBootstrapMessageShownForSession = false;
      _permissionBootstrapSessionKey = null;
      return;
    }

    if (_permissionBootstrapSessionKey != sessionKey) {
      _permissionBootstrapSessionKey = sessionKey;
      _devicePermissionBootstrapDoneForSession = false;
      _permissionBootstrapMessageShownForSession = false;
    }

    if (_bootstrappingDevicePermissions ||
        _devicePermissionBootstrapDoneForSession) {
      return;
    }
    _bootstrappingDevicePermissions = true;
    unawaited(_bootstrapDevicePermissions(sessionKey: sessionKey));
  }

  Future<void> _bootstrapDevicePermissions({required String sessionKey}) async {
    try {
      final result = await _devicePermissionBootstrap.ensureRequestedAfterLogin();
      if (!mounted || _currentSessionPermissionKey() != sessionKey) {
        return;
      }
      if (!_permissionBootstrapMessageShownForSession &&
          result.newlyConfigured &&
          result.cameraGranted &&
          result.locationGranted) {
        _permissionBootstrapMessageShownForSession = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          showCenteredSnackBar(
            context,
            text: 'Permisos iniciales configurados.',
          );
        });
      } else if (!_permissionBootstrapMessageShownForSession &&
          (!result.cameraGranted || !result.locationGranted)) {
        _permissionBootstrapMessageShownForSession = true;
        final missing = <String>[
          if (!result.cameraGranted) 'cámara',
          if (!result.locationGranted) 'ubicación',
        ].join(' y ');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          showCenteredSnackBar(
            context,
            text: 'Para fichar, habilitá $missing en Ajustes del teléfono.',
            isError: true,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Ajustes',
              onPressed: () {
                unawaited(_devicePermissionBootstrap.openAppSettings());
              },
            ),
          );
        });
      }
    } finally {
      _bootstrappingDevicePermissions = false;
      if (_currentSessionPermissionKey() == sessionKey) {
        _devicePermissionBootstrapDoneForSession = true;
      }
    }
  }

  String? _currentSessionPermissionKey() {
    final session = _sessionManager.session;
    if (session == null) {
      return null;
    }
    return '${session.empleado.id}:${session.token}';
  }

  @override
  void dispose() {
    _sessionManager.removeListener(_onSessionChanged);
    _sessionManager.dispose();
    _apiClient.dispose();
    super.dispose();
  }

  Future<void> _onLoginSuccess(LoginResponse session) async {
    _autoTriggeredReauth = false;
    await _sessionManager.onLoginSuccess(session);
    _scheduleDevicePermissionBootstrap();
    unawaited(_checkBiometricReauthCreds());
    if (mounted) {
      setState(() {
        _biometricReauthApiLoading = false;
        _biometricReauthError = null;
      });
    }
  }

  Future<void> _checkBiometricReauthCreds() async {
    final has = await _biometricCredentialCache.hasCredentials;
    if (!mounted) return;
    setState(() => _hasBiometricReauthCreds = has);
    _maybeTriggerBiometricAutoReauth();
  }

  Future<void> _logoutDevice() async {
    // Reset so biometric auto-trigger fires again on the login screen.
    _autoTriggeredReauth = false;
    await Future.wait([
      _sessionManager.logout(clearStored: true),
      _offlineCredentialsCache.clear(),
      // Biometric credentials are kept intentionally: the user should be
      // able to log back in with fingerprint right after closing the session.
    ]);
    // Re-check so the login page reflects the correct biometric state.
    if (mounted) unawaited(_checkBiometricReauthCreds());
  }

  Future<void> _onBiometricReauth() async {
    setState(() {
      _biometricReauthError = null;
    });

    // Fase 1: verificar huella (SessionManager gestiona el loading)
    final verified = await _sessionManager.verifyBiometricOnly();
    if (!verified || !mounted) return;

    // Fase 2: obtener credenciales cacheadas
    final creds = await _biometricCredentialCache.read();
    if (creds == null || !mounted) {
      // Creds desaparecieron inesperadamente; limpiamos el estado
      setState(() => _hasBiometricReauthCreds = false);
      return;
    }

    // Fase 3: login contra la API con las credenciales guardadas
    setState(() => _biometricReauthApiLoading = true);
    try {
      final session = await _apiClient.login(
        dni: creds.dni,
        password: creds.password,
      );
      if (!mounted) return;
      await _onLoginSuccess(session);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _biometricCredentialCache.clear();
        if (!mounted) return;
        setState(() {
          _hasBiometricReauthCreds = false;
          _biometricReauthError =
              'Tu contraseña fue cambiada. Ingresá con DNI y contraseña para reactivar el acceso por huella.';
          _biometricReauthApiLoading = false;
        });
      } else {
        setState(() {
          _biometricReauthError = e.message;
          _biometricReauthApiLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _biometricReauthError = 'Error al autenticar con huella.';
        _biometricReauthApiLoading = false;
      });
    }
  }

  Future<void> _lockSession() async {
    await _sessionManager.lockSession(reason: 'Sesion bloqueada manualmente.');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _unlockSession() async {
    await _sessionManager.restoreWithBiometrics(auto: false);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _sessionManager.session;
    if (_sessionManager.isBootstrapping && session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_sessionManager.isLocked && session != null) {
      return _SessionLockedView(
        loading: _sessionManager.isBiometricLoading,
        message:
            _sessionManager.statusMessage ??
            'Sesion bloqueada por inactividad.',
        onUnlock: _unlockSession,
        onLogout: _logoutDevice,
      );
    }

    if (session == null) {
      return LoginPage(
        apiClient: _apiClient,
        onLoginSuccess: _onLoginSuccess,
        offlineCredentialsCache: _offlineCredentialsCache,
        biometricCredentialCache: _biometricCredentialCache,
        biometricAvailable: _sessionManager.biometricAvailable,
        hasStoredSession: _sessionManager.hasStoredSession,
        biometricEnabled: _sessionManager.biometricEnabled,
        onBiometricLogin:
            (_sessionManager.hasStoredSession &&
                _sessionManager.canUseBiometric)
            ? () async {
                await _sessionManager.restoreWithBiometrics(auto: false);
              }
            : null,
        onBiometricReauth:
            (_hasBiometricReauthCreds &&
                !_sessionManager.hasStoredSession &&
                _sessionManager.biometricAvailable &&
                _sessionManager.biometricEnabled)
            ? _onBiometricReauth
            : null,
        biometricLoading: _sessionManager.isBiometricLoading,
        biometricReauthLoading: _biometricReauthApiLoading,
        biometricError:
            _sessionManager.statusMessage ?? _biometricReauthError,
      );
    }

    return Listener(
      onPointerDown: (_) => _sessionManager.markActivity(),
      behavior: HitTestBehavior.translucent,
      child: AttendanceHomePage(
        apiClient: _apiClient,
        token: session.token,
        empleado: session.empleado,
        sessionManager: _sessionManager,
        onLogout: _logoutDevice,
        onLockSession: _lockSession,
      ),
    );
  }
}

class _SessionLockedView extends StatelessWidget {
  const _SessionLockedView({
    required this.loading,
    required this.message,
    required this.onUnlock,
    required this.onLogout,
  });

  final bool loading;
  final String message;
  final Future<void> Function() onUnlock;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 600 ? 12.0 : 20.0;
            final verticalPadding = constraints.maxHeight < 700 ? 12.0 : 24.0;
            final minHeight =
                (constraints.maxHeight - (verticalPadding * 2))
                    .clamp(0.0, double.infinity)
                    .toDouble();
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sesion bloqueada',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 10),
                            Text(message),
                            if (loading) ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Verificando huella digital...'),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 46,
                              child: FilledButton.icon(
                                onPressed: loading ? null : onUnlock,
                                icon: loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.fingerprint),
                                label: Text(
                                  loading
                                      ? 'Validando...'
                                      : 'Desbloquear con huella',
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: loading ? null : onLogout,
                                icon: const Icon(Icons.logout),
                                label: const Text('Cerrar sesión'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
