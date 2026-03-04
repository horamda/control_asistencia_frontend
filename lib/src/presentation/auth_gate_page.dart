import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../core/auth/biometric_auth_service.dart';
import '../core/auth/session_storage.dart';
import '../core/network/mobile_api_client.dart';
import 'attendance/attendance_home_page.dart';
import 'auth/login_page.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  late final MobileApiClient _apiClient;
  final SessionStorage _sessionStorage = SessionStorage();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();

  LoginResponse? _session;
  bool _bootstrapping = true;
  bool _biometricLoading = false;
  bool _biometricAvailable = false;
  bool _hasStoredSession = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _apiClient = MobileApiClient(baseUrl: AppConfig.current.apiBaseUrl);
    _bootstrapSession();
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSession() async {
    final biometricsAvailable = await _biometricAuthService.isAvailable();
    final storedSession = await _sessionStorage.read();
    if (!mounted) {
      return;
    }
    setState(() {
      _biometricAvailable = biometricsAvailable;
      _hasStoredSession = storedSession != null;
    });
    if (storedSession != null && biometricsAvailable) {
      await _loginWithBiometrics(storedSession: storedSession, auto: true);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _bootstrapping = false;
    });
  }

  Future<void> _onLoginSuccess(LoginResponse session) async {
    var sessionStored = false;
    try {
      await _sessionStorage.save(session);
      sessionStored = true;
    } catch (_) {
      sessionStored = false;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _hasStoredSession = sessionStored;
      _authError = null;
    });
  }

  Future<void> _loginWithBiometrics({
    LoginResponse? storedSession,
    bool auto = false,
  }) async {
    if (_biometricLoading) {
      return;
    }
    final cachedSession = storedSession ?? await _sessionStorage.read();
    if (cachedSession == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasStoredSession = false;
        _authError = null;
        _bootstrapping = false;
      });
      return;
    }
    if (!_biometricAvailable) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authError = 'El dispositivo no tiene huella habilitada.';
        _bootstrapping = false;
      });
      return;
    }

    setState(() {
      _biometricLoading = true;
      if (!auto) {
        _authError = null;
      }
    });

    final authorized = await _biometricAuthService.authenticate();
    if (!authorized) {
      if (!mounted) {
        return;
      }
      setState(() {
        _biometricLoading = false;
        _bootstrapping = false;
        if (!auto) {
          _authError = 'No se pudo validar la huella.';
        }
      });
      return;
    }

    try {
      final refreshedToken = await _apiClient.refreshToken(
        token: cachedSession.token,
      );
      final activeSession = LoginResponse(
        token: refreshedToken,
        empleado: cachedSession.empleado,
      );
      await _sessionStorage.save(activeSession);
      if (!mounted) {
        return;
      }
      setState(() {
        _session = activeSession;
        _hasStoredSession = true;
        _authError = null;
        _biometricLoading = false;
        _bootstrapping = false;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _sessionStorage.clear();
        if (!mounted) {
          return;
        }
        setState(() {
          _hasStoredSession = false;
          _authError = 'La sesion guardada vencio. Ingresa con DNI y password.';
          _biometricLoading = false;
          _bootstrapping = false;
        });
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _authError = e.message;
        _biometricLoading = false;
        _bootstrapping = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authError = 'No se pudo validar la sesion con huella.';
        _biometricLoading = false;
        _bootstrapping = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _session = null;
      _authError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (_bootstrapping && session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session == null) {
      return LoginPage(
        apiClient: _apiClient,
        onLoginSuccess: _onLoginSuccess,
        biometricAvailable: _biometricAvailable,
        hasStoredSession: _hasStoredSession,
        onBiometricLogin: (_hasStoredSession && _biometricAvailable)
            ? () => _loginWithBiometrics()
            : null,
        biometricLoading: _biometricLoading,
        biometricError: _authError,
      );
    }

    return AttendanceHomePage(
      apiClient: _apiClient,
      token: session.token,
      empleado: session.empleado,
      onLogout: () {
        _logout();
      },
    );
  }
}
