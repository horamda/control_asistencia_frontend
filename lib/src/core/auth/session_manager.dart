import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../network/mobile_api_client.dart';
import '../utils/app_logger.dart';
import 'biometric_auth_service.dart';
import '../feedback/clock_feedback_profile.dart';
import 'session_storage.dart';

final _log = AppLogger.get('SessionManager');

class SessionManager extends ChangeNotifier {
  SessionManager({
    required MobileApiClient apiClient,
    SessionStorage? sessionStorage,
    BiometricAuthService? biometricAuthService,
    this.idleTimeout = const Duration(minutes: 20),
    this.maxSessionAge = const Duration(hours: 10),
    this.proactiveRefreshInterval = const Duration(minutes: 8),
  }) : _apiClient = apiClient,
       _sessionStorage = sessionStorage ?? SessionStorage(),
       _biometricAuthService = biometricAuthService ?? BiometricAuthService();

  final MobileApiClient _apiClient;
  final SessionStorage _sessionStorage;
  final BiometricAuthService _biometricAuthService;

  final Duration idleTimeout;
  final Duration maxSessionAge;
  final Duration proactiveRefreshInterval;

  final StreamController<void> _onUnauthorizedController =
      StreamController<void>.broadcast();

  LoginResponse? _session;
  bool _bootstrapping = true;
  bool _biometricLoading = false;
  bool _refreshing = false;
  bool _locked = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = true;
  ClockFeedbackProfile _clockFeedbackProfile = ClockFeedbackProfile.balanced;
  bool _hasStoredSession = false;
  String? _statusMessage;
  DateTime? _sessionStartedAt;
  DateTime? _lastActivityAt;
  DateTime? _lastRefreshAt;
  DateTime? _lastPolicyCheckAt;
  Timer? _policyTimer;
  Timer? _proactiveRefreshTimer;
  Completer<bool>? _refreshCompleter;

  Stream<void> get onUnauthorized => _onUnauthorizedController.stream;

  LoginResponse? get session => _session;
  String? get token => _session?.token;
  bool get isAuthenticated => _session != null;
  bool get isBootstrapping => _bootstrapping;
  bool get isBiometricLoading => _biometricLoading;
  bool get isRefreshing => _refreshing;
  bool get isLocked => _locked;
  bool get biometricAvailable => _biometricAvailable;
  bool get biometricEnabled => _biometricEnabled;
  bool get canUseBiometric => _biometricAvailable && _biometricEnabled;
  ClockFeedbackProfile get clockFeedbackProfile => _clockFeedbackProfile;
  bool get hasStoredSession => _hasStoredSession;
  String? get statusMessage => _statusMessage;
  DateTime? get lastRefreshAt => _lastRefreshAt;

  Duration? get sessionAge {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) {
      return null;
    }
    return DateTime.now().difference(startedAt);
  }

  Future<void> bootstrap() async {
    _bootstrapping = true;
    _statusMessage = null;
    notifyListeners();

    _biometricAvailable = await _biometricAuthService.isAvailable();
    final biometricPref = await _sessionStorage.readBiometricEnabled();
    _biometricEnabled = biometricPref ?? true;
    _clockFeedbackProfile = await _sessionStorage.readClockFeedbackProfile();
    final envelope = await _sessionStorage.readEnvelope();
    _hasStoredSession = envelope != null;

    if (envelope == null) {
      _bootstrapping = false;
      notifyListeners();
      return;
    }

    _session = envelope.session;
    _sessionStartedAt = envelope.sessionStartedAt;
    _lastActivityAt = envelope.lastActivityAt;
    _lastRefreshAt = envelope.lastRefreshAt;

    if (_isOverMaxAge()) {
      await _expireSession(
        reason: 'La sesion supero el tiempo maximo permitido.',
        clearStored: true,
      );
      _bootstrapping = false;
      notifyListeners();
      return;
    }

    if (canUseBiometric) {
      _locked = true;
      _bootstrapping = false;
      _statusMessage = 'Desbloquea la sesion con huella.';
      notifyListeners();

      final restored = await restoreWithBiometrics(auto: true);
      if (!restored && _session != null) {
        _locked = true;
        _statusMessage = 'Desbloquea la sesion con huella.';
        notifyListeners();
      }
      return;
    }

    _locked = false;
    _startSessionTimers();
    _bootstrapping = false;
    notifyListeners();
    await refreshSession(silent: true, triggerUnauthorized: false);
  }

  Future<bool> restoreWithBiometrics({bool auto = false}) async {
    if (_biometricLoading) {
      return false;
    }
    final envelope = await _sessionStorage.readEnvelope();
    if (envelope == null) {
      _hasStoredSession = false;
      _session = null;
      _statusMessage = null;
      notifyListeners();
      return false;
    }

    if (!_biometricAvailable) {
      _statusMessage = 'La huella no esta disponible en este dispositivo.';
      notifyListeners();
      return false;
    }
    if (!_biometricEnabled) {
      _statusMessage = 'El uso de huella esta desactivado.';
      notifyListeners();
      return false;
    }

    _biometricLoading = true;
    if (!auto) {
      _statusMessage = null;
    }
    notifyListeners();

    final ok = await _biometricAuthService.authenticate(
      reason: 'Usa tu huella para desbloquear la sesion.',
    );
    if (!ok) {
      _biometricLoading = false;
      if (!auto) {
        _statusMessage = 'No se pudo validar la huella.';
      }
      notifyListeners();
      return false;
    }

    _session = envelope.session;
    _sessionStartedAt = envelope.sessionStartedAt;
    _lastActivityAt = DateTime.now();
    _lastRefreshAt = envelope.lastRefreshAt;
    _locked = false;
    _startSessionTimers();

    final refreshed = await refreshSession(
      silent: auto,
      triggerUnauthorized: false,
    );
    if (!refreshed && _session == null) {
      _biometricLoading = false;
      notifyListeners();
      return false;
    }

    _biometricLoading = false;
    _statusMessage = auto ? null : 'Sesion desbloqueada.';
    await _persistCurrentEnvelope();
    notifyListeners();
    return true;
  }

  Future<void> onLoginSuccess(LoginResponse session) async {
    final now = DateTime.now();
    _session = session;
    _sessionStartedAt = now;
    _lastActivityAt = now;
    _lastRefreshAt = now;
    _locked = false;
    _hasStoredSession = true;
    _statusMessage = 'Sesion activa.';
    _startSessionTimers();
    await _persistCurrentEnvelope();
    notifyListeners();
  }

  Future<void> logout({bool clearStored = true}) async {
    _stopTimers();
    _session = null;
    _locked = false;
    _refreshing = false;
    _statusMessage = null;
    _sessionStartedAt = null;
    _lastActivityAt = null;
    _lastRefreshAt = null;
    if (clearStored) {
      await _sessionStorage.clear();
      _hasStoredSession = false;
    }
    notifyListeners();
  }

  Future<void> lockSession({String? reason}) async {
    if (_session == null) {
      return;
    }
    if (!canUseBiometric) {
      _statusMessage = !_biometricAvailable
          ? 'La huella no esta disponible en este dispositivo.'
          : 'El uso de huella esta desactivado.';
      notifyListeners();
      return;
    }
    _locked = true;
    _statusMessage = reason ?? 'Sesion bloqueada.';
    notifyListeners();
    await _persistCurrentEnvelope();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    await _sessionStorage.saveBiometricEnabled(enabled);
    if (!enabled && _locked) {
      _locked = false;
      _lastActivityAt = DateTime.now();
    }
    _statusMessage = enabled
        ? 'Uso de huella activado.'
        : 'Uso de huella desactivado.';
    await _persistCurrentEnvelope();
    notifyListeners();
  }

  Future<void> setClockFeedbackProfile(ClockFeedbackProfile profile) async {
    _clockFeedbackProfile = profile;
    await _sessionStorage.saveClockFeedbackProfile(profile);
    notifyListeners();
  }

  Future<bool> testBiometricAuthentication() async {
    if (_biometricLoading) {
      return false;
    }
    if (!_biometricAvailable) {
      _statusMessage = 'La huella no esta disponible en este dispositivo.';
      notifyListeners();
      return false;
    }

    _biometricLoading = true;
    _statusMessage = null;
    notifyListeners();

    final ok = await _biometricAuthService.authenticate(
      reason: 'Usa tu huella para confirmar esta accion.',
    );
    _biometricLoading = false;
    _statusMessage = ok
        ? 'Huella validada correctamente.'
        : 'No se pudo validar la huella.';
    notifyListeners();
    return ok;
  }

  void markActivity() {
    if (_session == null || _locked) {
      return;
    }
    _lastActivityAt = DateTime.now();
  }

  Future<T> runAuthorized<T>(Future<T> Function(String token) operation) async {
    if (_session == null) {
      throw ApiException(message: 'Sesion no iniciada.', statusCode: 401);
    }
    if (_isOverMaxAge()) {
      await _expireSession(
        reason: 'La sesion supero el tiempo maximo permitido.',
        clearStored: true,
      );
      _onUnauthorizedController.add(null);
      throw ApiException(
        message: 'La sesion supero el tiempo maximo permitido.',
        statusCode: 401,
      );
    }
    _enforcePolicies();
    if (_session == null) {
      throw ApiException(message: 'Sesion vencida.', statusCode: 401);
    }
    if (_locked) {
      throw ApiException(message: 'Sesion bloqueada por inactividad.');
    }
    markActivity();

    try {
      return await operation(_session!.token);
    } on ApiException catch (e) {
      if (!_isUnauthorized(e)) {
        rethrow;
      }
      final refreshed = await refreshSession(
        silent: false,
        triggerUnauthorized: false,
      );
      if (!refreshed || _session == null) {
        await _expireSession(
          reason: 'La sesion vencio. Ingresa nuevamente.',
          clearStored: true,
        );
        _onUnauthorizedController.add(null);
        throw ApiException(
          message: 'La sesion vencio. Ingresa nuevamente.',
          statusCode: 401,
        );
      }
      return operation(_session!.token);
    }
  }

  Future<bool> refreshSession({
    bool silent = true,
    bool triggerUnauthorized = true,
  }) async {
    final current = _session;
    if (current == null) {
      return false;
    }
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    _refreshing = true;
    if (!silent) {
      _statusMessage = 'Renovando sesion...';
    }
    notifyListeners();

    try {
      final refreshedToken = await _apiClient.refreshToken(
        token: current.token,
      );
      _session = LoginResponse(
        token: refreshedToken,
        empleado: current.empleado,
      );
      _lastRefreshAt = DateTime.now();
      _lastActivityAt = DateTime.now();
      _locked = false;
      _statusMessage = 'Sesion recuperada automaticamente.';
      await _persistCurrentEnvelope();
      notifyListeners();
      completer.complete(true);
      return true;
    } on ApiException catch (e) {
      if (_isUnauthorized(e)) {
        await _expireSession(
          reason: 'La sesion vencio. Ingresa nuevamente.',
          clearStored: true,
        );
        if (triggerUnauthorized) {
          _onUnauthorizedController.add(null);
        }
      } else if (!silent) {
        _statusMessage = e.message;
      }
      notifyListeners();
      completer.complete(false);
      return false;
    } catch (e, stack) {
      _log.warning('Error inesperado al renovar sesion', e, stack);
      if (!silent) {
        _statusMessage = 'No se pudo renovar la sesion.';
      }
      notifyListeners();
      completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
      _refreshing = false;
      notifyListeners();
    }
  }

  String? currentTokenFromProvider() {
    final current = _session;
    if (current == null) {
      return null;
    }
    if (_locked) {
      return null;
    }
    return current.token;
  }

  Future<String?> refreshTokenForProvider(String expiredToken) async {
    final current = _session;
    if (current == null) {
      return null;
    }
    if (current.token.trim() != expiredToken.trim()) {
      return current.token;
    }
    final ok = await refreshSession(silent: true, triggerUnauthorized: true);
    return ok ? _session?.token : null;
  }

  Future<void> forceExpireFromProvider() async {
    await _expireSession(
      reason: 'La sesion vencio. Ingresa nuevamente.',
      clearStored: true,
    );
    _onUnauthorizedController.add(null);
  }

  bool _isUnauthorized(ApiException error) {
    return error.statusCode == 401 || error.statusCode == 403;
  }

  void _startSessionTimers() {
    _stopTimers();
    _policyTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _enforcePolicies();
    });
    _proactiveRefreshTimer = Timer.periodic(proactiveRefreshInterval, (_) {
      if (_session == null || _locked || _refreshing) {
        return;
      }
      if (_tokenExpiringSoon() || !_hasRefreshedRecently()) {
        refreshSession(silent: true, triggerUnauthorized: false);
      }
    });
  }

  void _stopTimers() {
    _policyTimer?.cancel();
    _proactiveRefreshTimer?.cancel();
    _policyTimer = null;
    _proactiveRefreshTimer = null;
  }

  bool _hasRefreshedRecently() {
    final refreshAt = _lastRefreshAt;
    if (refreshAt == null) {
      return false;
    }
    return DateTime.now().difference(refreshAt) < proactiveRefreshInterval;
  }

  bool _tokenExpiringSoon() {
    final current = _session;
    if (current == null) {
      return false;
    }
    final exp = _extractJwtExp(current.token);
    if (exp == null) {
      return false;
    }
    return exp.difference(DateTime.now()) < const Duration(minutes: 2);
  }

  DateTime? _extractJwtExp(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      if (map is! Map) {
        return null;
      }
      final exp = map['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      }
      return null;
    } catch (e) {
      _log.debug('No se pudo parsear exp del JWT: $e');
      return null;
    }
  }

  bool _isOverMaxAge() {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) {
      return false;
    }
    return DateTime.now().difference(startedAt) > maxSessionAge;
  }

  void _enforcePolicies() {
    final current = _session;
    if (current == null) {
      return;
    }
    final now = DateTime.now();
    final lastCheckAt = _lastPolicyCheckAt;
    if (lastCheckAt != null &&
        now.difference(lastCheckAt) < const Duration(seconds: 10)) {
      return;
    }
    _lastPolicyCheckAt = now;

    if (_isOverMaxAge()) {
      unawaited(
        _expireSession(
          reason: 'La sesion supero el tiempo maximo permitido.',
          clearStored: true,
        ),
      );
      _onUnauthorizedController.add(null);
      return;
    }
    final activityAt = _lastActivityAt ?? _sessionStartedAt ?? now;
    if (!_locked && now.difference(activityAt) > idleTimeout) {
      if (canUseBiometric) {
        _locked = true;
        _statusMessage = 'Sesion bloqueada por inactividad.';
        notifyListeners();
      } else {
        unawaited(
          _expireSession(
            reason: 'Sesion expirada por inactividad. Ingresa nuevamente.',
            clearStored: true,
          ),
        );
        _onUnauthorizedController.add(null);
      }
    }
  }

  Future<void> _expireSession({
    required String reason,
    required bool clearStored,
  }) async {
    _stopTimers();
    _session = null;
    _locked = false;
    _refreshing = false;
    _statusMessage = reason;
    _sessionStartedAt = null;
    _lastActivityAt = null;
    _lastRefreshAt = null;
    if (clearStored) {
      await _sessionStorage.clear();
      _hasStoredSession = false;
    }
    notifyListeners();
  }

  Future<void> _persistCurrentEnvelope() async {
    final current = _session;
    final startedAt = _sessionStartedAt;
    if (current == null || startedAt == null) {
      return;
    }
    await _sessionStorage.saveEnvelope(
      StoredSessionEnvelope(
        session: current,
        sessionStartedAt: startedAt,
        lastActivityAt: _lastActivityAt ?? DateTime.now(),
        lastRefreshAt: _lastRefreshAt ?? DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _stopTimers();
    _onUnauthorizedController.close();
    super.dispose();
  }
}
