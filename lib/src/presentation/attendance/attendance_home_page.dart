import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../core/attendance/attendance_config_cache.dart';
import '../../core/attendance/clock_readiness_cache.dart';
import '../../core/attendance/clock_feedback_presenter.dart';
import '../../core/attendance/clock_gps_service.dart';
import '../../core/attendance/clock_metrics_tracker.dart';
import '../../core/attendance/qr_clock_preflight_service.dart';
import '../../core/attendance/clock_readiness_service.dart';
import '../../core/attendance/qr_clock_submission_service.dart';
import '../../core/feedback/app_rating_service.dart';
import '../../core/feedback/clock_feedback_audio_service.dart';
import '../widgets/app_rating_dialog.dart';
import '../../core/image/clock_photo_cache.dart';
import '../../core/image/profile_photo_cache.dart';
import '../../core/auth/session_manager.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/offline/pending_clock_sync_service.dart';
import '../../core/offline/offline_clock_queue.dart';
import '../../core/offline/pending_queue_controller.dart';
import '../../core/permissions/device_permission_bootstrap.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/clock_format_utils.dart';
import '../../core/utils/date_formatter.dart';
import 'attendance_home_action_presenter.dart';
import 'attendance_home_coordinator.dart';
import 'attendance_home_view_model.dart';
import 'widgets/attendance_dashboard_widgets.dart';
import '../widgets/centered_snackbar.dart';

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({
    super.key,
    required this.apiClient,
    required this.token,
    required this.empleado,
    required this.sessionManager,
    required this.onLogout,
    required this.onLockSession,
  });

  final MobileApiClient apiClient;
  final String token;
  final EmployeeSummary empleado;
  final SessionManager sessionManager;
  final Future<void> Function() onLogout;
  final Future<void> Function() onLockSession;

  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage>
    with WidgetsBindingObserver {
  static final _log = AppLogger.get('AttendanceHomePage');

  static const Duration _configCacheTtl = Duration(minutes: 3);
  static const Duration _gpsCacheTtl = Duration(minutes: 5);
  static const Duration _clockReadinessRefreshInterval = Duration(minutes: 3);

  final ImagePicker _imagePicker = ImagePicker();
  final ClockPhotoCache _clockPhotoCache = ClockPhotoCache();
  final AttendanceConfigCache _attendanceConfigCache = AttendanceConfigCache();
  final ClockReadinessCache _clockReadinessCache = ClockReadinessCache();
  final ClockFeedbackAudioService _feedbackAudio = ClockFeedbackAudioService();
  final DevicePermissionBootstrap _devicePermissionBootstrap =
      DevicePermissionBootstrap();
  late final PendingClockSyncService _pendingClockSyncService;
  final ClockFeedbackPresenter _clockFeedbackPresenter =
      const ClockFeedbackPresenter();
  final AttendanceHomeActionPresenter _homeActionPresenter =
      const AttendanceHomeActionPresenter();
  final AttendanceHomeCoordinator _homeCoordinator =
      const AttendanceHomeCoordinator();
  late final ClockGpsService _clockGpsService;
  late final ClockReadinessService _clockReadinessService;
  final ClockMetricsTracker _clockMetricsTracker = ClockMetricsTracker();
  late final QrClockPreflightService _qrClockPreflightService;
  late final QrClockSubmissionService _qrClockSubmissionService;
  late final PendingQueueController _pendingQueueController;

  int _selectedTab = 0;

  bool _submitting = false;
  bool _loadingConfig = false;
  bool _loadingProfile = false;
  bool _locatingGps = false;
  DashboardResponse? _dashboard;
  HorarioEsperadoResponse? _turnoHoy;
  String? _lastQrData;
  String? _profileLoadError;
  AttendanceConfig? _config;
  EmployeeProfile? _profile;

  // URL de foto memoizada: se calcula una vez y solo se actualiza cuando
  // imagenVersion realmente cambia (usuario subio/elimino foto).
  // Si recalculamos en cada build(), CachedNetworkImage ve URLs distintas
  // entre EmployeeSummary y EmployeeProfile (null vs 0 vs 1 en version)
  // y descarta el cache → re-descarga → si falla, la foto desaparece.
  late String _resolvedPhotoUrl;
  DateTime? _configLoadedAt;
  DateTime? _profileLoadedAt;
  Timer? _pendingSyncTicker;
  Timer? _clockReadinessTicker;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  ClockMetricsSnapshot _clockMetrics = const ClockMetricsSnapshot();
  PendingQueueState _pendingQueue = const PendingQueueState();
  ClockReadinessSnapshot _clockReadiness = const ClockReadinessSnapshot();
  String? _clockActionPhase;

  // ─── Trivia ────────────────────────────────────────────────────────────────
  TriviaEstadoResponse? _triviaEstado;
  List<TriviaNotificacion> _triviaNotificaciones = [];
  int _triviaPuntosAcumulados = 0;

  // ─── Rating ────────────────────────────────────────────────────────────────
  late final AppRatingService _ratingService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pendingClockSyncService = PendingClockSyncService(
      offlineClockQueue: OfflineClockQueue(),
      clockPhotoCache: _clockPhotoCache,
      apiClient: widget.apiClient,
    );
    _clockGpsService = ClockGpsService(
      locationServiceEnabledProvider: Geolocator.isLocationServiceEnabled,
      locationGrantedProvider: _devicePermissionBootstrap.isLocationGranted,
    );
    _clockReadinessService = ClockReadinessService(
      cameraGrantedProvider: _devicePermissionBootstrap.isCameraGranted,
      locationGrantedProvider: _devicePermissionBootstrap.isLocationGranted,
      locationServiceEnabledProvider: Geolocator.isLocationServiceEnabled,
    );
    _qrClockPreflightService = QrClockPreflightService(
      cameraGrantedProvider: _devicePermissionBootstrap.isCameraGranted,
      locationGrantedProvider: _devicePermissionBootstrap.isLocationGranted,
      locationServiceEnabledProvider: Geolocator.isLocationServiceEnabled,
    );
    _qrClockSubmissionService = QrClockSubmissionService(
      apiClient: widget.apiClient,
      pendingClockSyncService: _pendingClockSyncService,
      clockPhotoCache: _clockPhotoCache,
    );
    _pendingQueueController = PendingQueueController(
      syncService: _pendingClockSyncService,
    );
    // Inicializar URL de foto usando el endpoint canonico /empleados/imagen/{dni}.
    // No usar el campo `foto` de EmployeeSummary como primario porque el backend
    // puede devolverlo como URL relativa (sin esquema), que CachedNetworkImage
    // no puede descargar y queda en blanco.
    _resolvedPhotoUrl = widget.empleado.dni.isNotEmpty
        ? widget.apiClient.buildEmpleadoImagenUrl(
            dni: widget.empleado.dni,
            version: widget.empleado.imagenVersion,
          )
        : ProfilePhotoCache.withVersion(
            widget.empleado.foto,
            version: widget.empleado.imagenVersion,
          );
    _ratingService = AppRatingService(
      apiClient: widget.apiClient,
      token: widget.token,
    );
    unawaited(_feedbackAudio.initialize());
    unawaited(_applyFeedbackProfileFromSession());
    unawaited(_preloadReadinessFromCache());
    unawaited(_loadTodayLastMark());
    _loadConfig();
    _loadProfile();
    unawaited(_loadDashboard());
    unawaited(_loadTurnoHoy());
    unawaited(_loadTriviaEstado());
    _loadPendingQueueState();
    Future<void>.microtask(() => _warmUpClockReadiness(forceGps: true));
    Future<void>.microtask(
      () => _pendingClockSyncService.pruneEmployeePhotos(
        employeeId: widget.empleado.id,
      ),
    );
    Future<void>.microtask(() => _syncPendingClocks(isBackground: true));
    _startTimers();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  void _startTimers() {
    _pendingSyncTicker?.cancel();
    _clockReadinessTicker?.cancel();
    _pendingSyncTicker = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted || !_pendingQueue.hasPending || _pendingQueue.syncing || _submitting) return;
      _syncPendingClocks(isBackground: true);
    });
    _clockReadinessTicker = Timer.periodic(_clockReadinessRefreshInterval, (_) {
      if (!mounted || _submitting || _locatingGps) return;
      unawaited(_warmUpClockReadiness());
    });
  }

  void _stopTimers() {
    _pendingSyncTicker?.cancel();
    _clockReadinessTicker?.cancel();
    _pendingSyncTicker = null;
    _clockReadinessTicker = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    _connectivitySubscription?.cancel();
    unawaited(_feedbackAudio.dispose());
    super.dispose();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (!hasConnection || !mounted) return;

    // Si la sesion es offline, el token no sirve para la API.
    // Avisamos al usuario que reconecte sesion y no intentamos sincronizar.
    if (_isOfflineToken) {
      if (_pendingQueue.hasPending) {
        _showMessage(
          'Conexión restaurada. Volvé a iniciar sesión para sincronizar tus fichadas pendientes.',
          isError: false,
          tone: ClockFeedbackTone.warning,
        );
      }
      if (!_hasFreshConfig()) unawaited(_loadConfig());
      return;
    }

    // Recupero de red: sincronizar pendientes y refrescar config si hace falta.
    if (_pendingQueue.hasPending && !_pendingQueue.syncing && !_submitting) {
      unawaited(_syncPendingClocks(isBackground: true));
    }
    if (!_hasFreshConfig()) {
      unawaited(_loadConfig());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimers();
      unawaited(_warmUpClockReadiness(forceGps: true, refreshConfig: true));
    } else if (state == AppLifecycleState.paused) {
      _stopTimers();
    }
  }

  Future<void> _fichar() async {
    await _runScanAndClock();
  }

  Future<void> _openRateApp() async {
    if (!mounted) return;
    await showAppRatingDialog(
      context,
      ratingService: _ratingService,
      pantalla: 'mas_opciones',
    );
  }

  static final _linksUrl = Uri.parse('https://horamda.github.io/delPalacio_DPO/');

  Future<void> _openLinks() async {
    if (await canLaunchUrl(_linksUrl)) {
      await launchUrl(_linksUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openSecurityEvents() async {
    if (_submitting) {
      return;
    }
    await _homeCoordinator.openSecurityEvents(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openJustificaciones() async {
    if (_submitting) {
      return;
    }
    await _homeCoordinator.openJustificaciones(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openAdelantos() async {
    if (_submitting) {
      return;
    }
    await _homeCoordinator.openAdelantos(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openVacaciones() async {
    if (_submitting) return;
    await _homeCoordinator.openVacaciones(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openFrancos() async {
    if (_submitting) return;
    await _homeCoordinator.openFrancos(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openLegajo() async {
    if (_submitting) return;
    await _homeCoordinator.openLegajo(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openPedidosMercaderia() async {
    if (_submitting) return;
    await _homeCoordinator.openPedidosMercaderia(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openKpisSector() async {
    if (_submitting) return;
    await _homeCoordinator.openKpisSector(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openPremios() async {
    if (_submitting) return;
    await _homeCoordinator.openPremios(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openHorarios() async {
    if (_submitting) return;
    await _homeCoordinator.openHorarios(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openAttendanceHistory() async {
    if (_submitting) {
      return;
    }
    await _homeCoordinator.openAttendanceHistory(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openMarksHistory() async {
    if (_submitting) {
      return;
    }
    await _homeCoordinator.openMarksHistory(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openStats() async {
    if (_submitting) {
      return;
    }
    await _homeCoordinator.openStats(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
    );
  }

  Future<void> _openProfile() async {
    if (_submitting) {
      return;
    }
    await _homeCoordinator.openProfile(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
      employeeDni: widget.empleado.dni,
    );
    if (!mounted) {
      return;
    }
    await _loadProfile(force: true);
  }

  Future<void> _openBiometricSettings() async {
    if (_submitting) {
      return;
    }
    await _homeCoordinator.openBiometricSettings(
      context,
      sessionManager: widget.sessionManager,
    );
    if (!mounted) {
      return;
    }
    unawaited(_applyFeedbackProfileFromSession());
    setState(() {});
  }

  Future<void> _applyFeedbackProfileFromSession() async {
    await _feedbackAudio.setProfile(widget.sessionManager.clockFeedbackProfile);
  }

  Future<void> _loadTriviaEstado() async {
    try {
      final results = await Future.wait([
        widget.apiClient.getTriviaEstado(token: widget.token),
        widget.apiClient.getTriviaNotificaciones(token: widget.token),
        widget.apiClient
            .getMiHistorialTrivia(token: widget.token)
            .catchError((_) => <TriviaMyHistorialItem>[]),
      ]);
      if (!mounted) return;
      final historial = results[2] as List<TriviaMyHistorialItem>;
      final pts = historial.fold<int>(0, (sum, i) => sum + (i.puntosTotal ?? 0));
      setState(() {
        _triviaEstado = results[0] as TriviaEstadoResponse;
        _triviaNotificaciones = results[1] as List<TriviaNotificacion>;
        _triviaPuntosAcumulados = pts;
      });
    } catch (_) {
      // Trivia es opcional — si falla no bloqueamos el home
    }
  }

  Future<void> _openTrivia() async {
    if (_submitting) return;
    await _homeCoordinator.openTrivia(
      context,
      apiClient: widget.apiClient,
      token: widget.token,
      empleadoDni: widget.empleado.dni,
      empleadoId: widget.empleado.id,
    );
    if (!mounted) return;
    unawaited(_loadTriviaEstado());
  }

  Future<void> _loadDashboard() async {
    try {
      final dashboard = await widget.apiClient.getDashboard(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() => _dashboard = dashboard);
    } catch (_) {
      // Dashboard es opcional — si falla no bloqueamos el home
    }
  }

  Future<void> _loadTurnoHoy() async {
    try {
      final hoy = DateTime.now();
      final fecha =
          '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
      final turno = await widget.apiClient.getHorarioEsperado(
        token: widget.token,
        fecha: fecha,
      );
      if (!mounted) return;
      setState(() => _turnoHoy = turno);
    } catch (_) {
      // Turno es opcional — si falla no bloqueamos el home
    }
  }

  Future<void> _loadProfile({bool force = false}) async {
    if (_loadingProfile) {
      return;
    }
    if (!force &&
        _profile != null &&
        _profileLoadedAt != null &&
        DateTime.now().difference(_profileLoadedAt!) <
            const Duration(minutes: 2)) {
      return;
    }
    final previousVersion = _profile?.imagenVersion ?? widget.empleado.imagenVersion;
    setState(() {
      _loadingProfile = true;
    });
    try {
      final profile = await widget.apiClient.getMe(token: widget.token);
      // Solo evictar si la version de la imagen realmente cambio (el usuario
      // subio/elimino una foto). Comparar por URL string causa evicts falsos
      // cuando EmployeeSummary y EmployeeProfile difieren en formato de URL.
      final nextVersion = profile.imagenVersion;
      if (nextVersion != previousVersion) {
        await ProfilePhotoCache.evict(_resolvedPhotoUrl, version: previousVersion);
      }
      if (!mounted) return;
      // Recalcular URL solo si la version cambio, para no romper el cache de
      // Usar siempre el endpoint canonico por DNI (mismo criterio que initState).
      final effectiveDni = (profile.dni ?? widget.empleado.dni).trim();
      final newUrl = effectiveDni.isNotEmpty
          ? widget.apiClient.buildEmpleadoImagenUrl(
              dni: effectiveDni,
              version: profile.imagenVersion,
            )
          : ProfilePhotoCache.withVersion(profile.foto, version: profile.imagenVersion);
      setState(() {
        _profile = profile;
        _profileLoadError = null;
        _profileLoadedAt = DateTime.now();
        if (newUrl.isNotEmpty) _resolvedPhotoUrl = newUrl;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileLoadError = _shouldShowProfileLoadError(e) ? e.message : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileLoadError = _profile == null
            ? null
            : 'No se pudo cargar el perfil/foto.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });
      }
    }
  }

  bool _shouldShowProfileLoadError(ApiException error) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      return true;
    }
    return _profile != null;
  }

  bool _hasFreshConfig() {
    final loadedAt = _configLoadedAt;
    if (_config == null || loadedAt == null) {
      return false;
    }
    return DateTime.now().difference(loadedAt) < _configCacheTtl;
  }

  Future<void> _loadConfig({bool force = false}) async {
    if (_loadingConfig) return;
    if (!force && _hasFreshConfig()) return;
    setState(() => _loadingConfig = true);
    try {
      final config = await widget.apiClient.getConfigAsistencia(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _config = config;
        _configLoadedAt = DateTime.now();
      });
      // Persistir para que funcione en cold-start sin internet.
      unawaited(_attendanceConfigCache.save(config));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_config != null) {
        // Ya hay config en memoria de esta sesion — ignorar silenciosamente.
        return;
      }
      // Sin config en memoria: intentar recuperar del cache persistente.
      final cached = await _attendanceConfigCache.load();
      if (!mounted) return;
      if (cached != null) {
        // Usar config cacheada; configLoadedAt queda null → se reintentara
        // la API en la proxima llamada.
        setState(() => _config = cached);
      } else {
        _showMessage(e.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  bool _hasFreshGps() {
    return _clockReadiness.hasFreshGps(_gpsCacheTtl);
  }

  /// Pre-carga el estado de permisos desde cache persistente.
  ///
  /// Se llama en [initState] para que los badges de readiness muestren el
  /// estado correcto de inmediato, sin esperar el primer warm-up.
  /// El warm-up posterior sobreescribe con el valor real del sistema.
  Future<void> _preloadReadinessFromCache() async {
    final cached = await _clockReadinessCache.load();
    if (!mounted) return;
    if (!cached.cameraGranted && !cached.locationGranted) return;
    setState(() {
      _clockReadiness = _clockReadiness.copyWith(
        cameraGranted: cached.cameraGranted ? true : null,
        locationGranted: cached.locationGranted ? true : null,
      );
    });
  }

  Future<void> _warmUpClockReadiness({
    bool forceGps = false,
    bool refreshConfig = false,
  }) async {
    if (_clockReadiness.warming) {
      return;
    }

    if (mounted) {
      setState(() {
        _clockReadiness = _clockReadiness.copyWith(warming: true);
      });
    } else {
      _clockReadiness = _clockReadiness.copyWith(warming: true);
    }

    try {
      if (refreshConfig || !_hasFreshConfig()) {
        await _loadConfig(force: refreshConfig);
      }

      final next = await _clockReadinessService.warmUp(
        current: _clockReadiness,
        forceGps: forceGps,
        canCaptureGps: !_submitting && !_locatingGps,
        gpsTtl: _gpsCacheTtl,
        captureGps: () => _clockGpsService.capture(
          cachedGps: _clockReadiness.gps,
          gpsTtl: _gpsCacheTtl,
          forceRefresh: forceGps,
        ),
      );

      // Persistir permisos concedidos para arranques futuros.
      if (next.cameraGranted == true || next.locationGranted == true) {
        unawaited(_clockReadinessCache.saveGranted(
          cameraGranted: next.cameraGranted == true,
          locationGranted: next.locationGranted == true,
        ));
      }

      if (!mounted) {
        _clockReadiness = next;
        return;
      }

      setState(() {
        _clockReadiness = next;
      });
    } catch (_) {
      // Best effort warm-up: the runtime flow still performs hard checks.
    } finally {
      if (mounted) {
        setState(() {
          _clockReadiness = _clockReadiness.copyWith(warming: false);
        });
      } else {
        _clockReadiness = _clockReadiness.copyWith(warming: false);
      }
    }
  }

  void _setClockActionPhase(String? phase) {
    if (!mounted || _clockActionPhase == phase) {
      return;
    }
    setState(() {
      _clockActionPhase = phase;
    });
  }

  Future<String?> _capturePhotoToCache() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 60,
        requestFullMetadata: false,
      );
      if (photo == null) {
        return null;
      }
      return _clockPhotoCache.saveFromPath(
        employeeId: widget.empleado.id,
        sourcePath: photo.path,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _captureAndShowGps() async {
    if (_submitting || _loadingConfig || _locatingGps) {
      return;
    }
    setState(() {
      _locatingGps = true;
      _clockActionPhase = 'Validando GPS...';
    });
    try {
      final gps = await _clockGpsService.capture(
        cachedGps: _clockReadiness.gps,
        gpsTtl: _gpsCacheTtl,
        forceRefresh: true,
      );
      if (!mounted) {
        return;
      }
      if (gps == null) {
        final availability = await _clockGpsService.readAvailability();
        setState(() {
          _clockReadiness = _clockReadiness.copyWith(
            locationGranted: availability.locationGranted,
            locationServiceEnabled: availability.locationServiceEnabled,
            checkedAt: availability.checkedAt,
          );
        });
        if (!availability.locationServiceEnabled) {
          _showNotice(_clockFeedbackPresenter.locationServiceDisabled());
        } else {
          _showNotice(
            _clockFeedbackPresenter.permissionSettings(missing: 'la ubicación'),
          );
        }
        return;
      }
      setState(() {
        _clockReadiness = _clockReadiness.copyWith(
          gps: gps,
          locationGranted: true,
          locationServiceEnabled: true,
          checkedAt: DateTime.now(),
        );
      });
      _showMessage('Ubicación obtenida correctamente.');
    } finally {
      if (mounted) {
        setState(() {
          _locatingGps = false;
          if (!_submitting) {
            _clockActionPhase = null;
          }
        });
      }
    }
  }

  Future<void> _runScanAndClock() async {
    if (_submitting || _loadingConfig) {
      return;
    }

    await _loadConfig();
    if (!mounted) {
      return;
    }
    final effectiveConfig = _config;
    final preflight = await _qrClockPreflightService.validate(
      config: effectiveConfig,
      current: _clockReadiness,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _clockReadiness = preflight.readiness;
    });

    switch (preflight.status) {
      case QrClockPreflightStatus.ready:
        break;
      case QrClockPreflightStatus.missingConfig:
        _showNotice(_clockFeedbackPresenter.missingConfig());
        return;
      case QrClockPreflightStatus.qrDisabled:
        _showNotice(_clockFeedbackPresenter.qrDisabled());
        return;
      case QrClockPreflightStatus.cameraPermissionDenied:
        _showNotice(
          _clockFeedbackPresenter.permissionSettings(missing: 'la cámara'),
        );
        return;
      case QrClockPreflightStatus.locationServiceDisabled:
        _showNotice(_clockFeedbackPresenter.locationServiceDisabled());
        return;
      case QrClockPreflightStatus.locationPermissionDenied:
        _showNotice(
          _clockFeedbackPresenter.permissionSettings(missing: 'la ubicación'),
        );
        return;
    }

    if (effectiveConfig == null) {
      _showNotice(_clockFeedbackPresenter.missingConfig());
      return;
    }

    unawaited(_warmUpClockReadiness(forceGps: true));

    final qrData = await _homeCoordinator.scanQr(
      context,
      requiresPhoto: effectiveConfig.requiereFoto,
    );

    if (!mounted) {
      return;
    }
    if (qrData == null) {
      _showMessage('Fichada cancelada.', isError: false);
      return;
    }

    final cleanQrData = qrData.trim();
    if (cleanQrData.isEmpty) {
      _showNotice(_clockFeedbackPresenter.invalidQr());
      return;
    }
    final eventAt = DateTime.now();

    setState(() {
      _submitting = true;
      _lastQrData = cleanQrData;
      _clockActionPhase = 'Preparando fichada...';
    });

    try {
      final result = await _qrClockSubmissionService.submit(
        employeeId: widget.empleado.id,
        token: widget.token,
        qrToken: cleanQrData,
        eventAt: eventAt,
        requiresPhoto: effectiveConfig.requiereFoto,
        capturePhotoToCache: _capturePhotoToCache,
        captureGps: () => _clockGpsService.capture(
          cachedGps: _clockReadiness.gps,
          gpsTtl: _gpsCacheTtl,
        ),
        onPhase: _setClockActionPhase,
      );

      if (!mounted) {
        return;
      }

      _recordClockMetrics(
        total: result.totalDuration,
        api: result.apiDuration,
        gps: result.gpsDuration,
        photo: result.photoDuration,
        success: result.status == QrClockSubmissionStatus.success,
        errorCode: result.apiError?.code,
      );

      if (result.gps != null) {
        setState(() {
          _clockReadiness = _clockReadiness.copyWith(gps: result.gps);
        });
      }

      if (result.pendingSnapshot != null) {
        setState(() {
          _pendingQueue = _pendingQueueController.applySnapshot(
            current: _pendingQueue,
            snapshot: result.pendingSnapshot!,
          );
        });
      }

      final presentation = _clockFeedbackPresenter.presentSubmissionResult(
        result,
        formatDuration: fmtClockDuration,
      );
      _showNotice(presentation.notice);
      if (presentation.shouldSyncPendingSilently) {
        await _syncPendingClocks(isBackground: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _clockActionPhase = null;
        });
      }
    }
  }

  Future<void> _loadPendingQueueState() async {
    final next = await _pendingQueueController.load(
      employeeId: widget.empleado.id,
      current: _pendingQueue,
    );
    if (!mounted) {
      _pendingQueue = next;
      return;
    }
    setState(() {
      _pendingQueue = next;
    });
  }

  Future<String?> _syncPendingClocks({bool isBackground = false}) async {
    if (_pendingQueue.syncing) {
      return null;
    }

    // El token 'offline' no es valido en el servidor: intentar sincronizar lo
    // marcaria todo como "failed". Avisamos al usuario (solo en sync manual)
    // y abortamos.
    if (_isOfflineToken) {
      if (!isBackground && mounted) {
        _showMessage(
          'Sesión iniciada sin conexión. Volvé a ingresar con internet para sincronizar tus fichadas.',
          isError: false,
          tone: ClockFeedbackTone.warning,
        );
      }
      return null;
    }

    final started = _pendingQueueController.startSync(
      current: _pendingQueue,
      isBackground: isBackground,
    );
    if (mounted) {
      setState(() {
        _pendingQueue = started;
      });
    } else {
      _pendingQueue = started;
    }

    final next = await _pendingQueueController.syncAll(
      employeeId: widget.empleado.id,
      token: widget.token,
      current: started,
      isBackground: isBackground,
    );
    if (!mounted) {
      _pendingQueue = next;
      return isBackground ? null : next.lastMessage;
    }
    setState(() {
      _pendingQueue = next;
    });
    return isBackground ? null : next.lastMessage;
  }

  Future<void> _openPendingQueueDetails() async {
    await _loadPendingQueueState();
    if (!mounted) {
      return;
    }

    final queueState = ValueNotifier<PendingQueueState>(_pendingQueue);

    void syncState(PendingQueueState next) {
      queueState.value = next;
      if (!mounted) {
        _pendingQueue = next;
        return;
      }
      setState(() {
        _pendingQueue = next;
      });
    }

    Future<void> runSync() async {
      if (queueState.value.syncing) {
        return;
      }
      final started = _pendingQueueController.startSync(
        current: queueState.value,
        isBackground: false,
      );
      syncState(started);
      final next = await _pendingQueueController.syncAll(
        employeeId: widget.empleado.id,
        token: widget.token,
        current: started,
      );
      syncState(next);
    }

    Future<void> clearAll(BuildContext sheetContext) async {
      if (queueState.value.syncing) {
        return;
      }
      final confirmed = await _homeCoordinator.confirmClearPendingQueue(
        sheetContext,
      );
      if (!confirmed) {
        return;
      }
      final started = queueState.value.copyWith(syncing: true);
      syncState(started);
      final next = await _pendingQueueController.clearAll(
        employeeId: widget.empleado.id,
        current: started,
      );
      syncState(next.copyWith(syncing: false));
    }

    await _homeCoordinator.showPendingQueueSheet(
      context,
      queueState: queueState,
      formatDateTime: fmtClockDateTime,
      onSync: runSync,
      onClearAll: clearAll,
      onRetry: (item) async {
        final started = queueState.value.copyWith(syncing: true);
        syncState(started);
        final next = await _pendingQueueController.retryRecord(
          employeeId: widget.empleado.id,
          token: widget.token,
          record: item,
          current: started,
        );
        syncState(next);
      },
      onDelete: (item) async {
        final next = await _pendingQueueController.deleteRecord(
          employeeId: widget.empleado.id,
          recordId: item.id,
          current: queueState.value,
        );
        syncState(next);
      },
    );

    queueState.dispose();
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      _loadConfig(force: true),
      _loadProfile(force: true),
      _loadDashboard(),
      _loadTurnoHoy(),
      _loadTriviaEstado(),
      _syncPendingClocks(isBackground: true),
      _warmUpClockReadiness(forceGps: true, refreshConfig: true),
    ]);
    await _loadPendingQueueState();
  }

  bool get _isBusy => _submitting || _loadingConfig;

  /// Devuelve true cuando la sesion se inicio sin conexion (token sintetico).
  /// En ese caso NO se intenta sincronizar pendientes con la API porque el token
  /// no es valido en el servidor y causaria que los registros queden en "failed".
  bool get _isOfflineToken => widget.token.startsWith('offline_');

  AttendanceActionButtonData _buttonData(AttendanceHomeActionSpec spec) {
    return AttendanceActionButtonData(
      label: spec.label,
      icon: spec.icon,
      loading: spec.loading,
      color: spec.color,
      onPressed: _actionCallbackFor(spec),
    );
  }

  AttendanceQuickActionItem _quickActionItem(AttendanceHomeActionSpec spec) {
    return AttendanceQuickActionItem(
      icon: spec.icon,
      label: spec.label,
      onTap: _actionCallbackFor(spec),
    );
  }

  VoidCallback? _actionCallbackFor(AttendanceHomeActionSpec spec) {
    if (!spec.enabled) {
      return null;
    }
    switch (spec.intent) {
      case AttendanceHomeActionIntent.openPendingQueue:
        return () {
          unawaited(_openPendingQueueDetails());
        };
      case AttendanceHomeActionIntent.syncPending:
        return () {
          unawaited(_syncPendingClocks());
        };
      case AttendanceHomeActionIntent.captureGps:
        return () {
          unawaited(_captureAndShowGps());
        };
      case AttendanceHomeActionIntent.startClock:
        return () {
          unawaited(_fichar());
        };
      case AttendanceHomeActionIntent.openMarksHistory:
        return () {
          unawaited(_openMarksHistory());
        };
      case AttendanceHomeActionIntent.openAttendanceHistory:
        return () {
          unawaited(_openAttendanceHistory());
        };
      case AttendanceHomeActionIntent.openProfile:
        return () {
          unawaited(_openProfile());
        };
      case AttendanceHomeActionIntent.openBiometricSettings:
        return () {
          unawaited(_openBiometricSettings());
        };
      case AttendanceHomeActionIntent.openStats:
        return () {
          unawaited(_openStats());
        };
      case AttendanceHomeActionIntent.openSecurityEvents:
        return () {
          unawaited(_openSecurityEvents());
        };
      case AttendanceHomeActionIntent.openJustificaciones:
        return () {
          unawaited(_openJustificaciones());
        };
      case AttendanceHomeActionIntent.openAdelantos:
        return () {
          unawaited(_openAdelantos());
        };
      case AttendanceHomeActionIntent.openVacaciones:
        return () {
          unawaited(_openVacaciones());
        };
      case AttendanceHomeActionIntent.openFrancos:
        return () {
          unawaited(_openFrancos());
        };
      case AttendanceHomeActionIntent.openLegajo:
        return () {
          unawaited(_openLegajo());
        };
      case AttendanceHomeActionIntent.openPedidosMercaderia:
        return () {
          unawaited(_openPedidosMercaderia());
        };
      case AttendanceHomeActionIntent.openKpisSector:
        return () {
          unawaited(_openKpisSector());
        };
      case AttendanceHomeActionIntent.openPremios:
        return () {
          unawaited(_openPremios());
        };
      case AttendanceHomeActionIntent.openHorarios:
        return () {
          unawaited(_openHorarios());
        };
      case AttendanceHomeActionIntent.openLinks:
        return () {
          unawaited(_openLinks());
        };
    }
  }

  Future<void> _playFeedback({
    ClockFeedbackTone tone = ClockFeedbackTone.success,
  }) async {
    await _feedbackAudio.play(tone: tone);
  }

  void _showMessage(
    String text, {
    bool isError = false,
    ClockFeedbackTone? tone,
  }) {
    final effectiveTone =
        tone ?? (isError ? ClockFeedbackTone.error : ClockFeedbackTone.success);
    unawaited(_playFeedback(tone: effectiveTone));
    showCenteredSnackBar(context, text: text, isError: isError);
  }

  void _showNotice(ClockUserNotice notice) {
    unawaited(_playFeedback(tone: notice.effectiveTone));
    showCenteredSnackBar(
      context,
      text: notice.message,
      isError: notice.isError,
      duration: notice.duration,
      backgroundColor: notice.style == ClockNoticeStyle.fraud
          ? Colors.red.shade800
          : null,
      action: _buildSnackBarAction(notice.action),
    );
  }

  SnackBarAction? _buildSnackBarAction(ClockNoticeAction? action) {
    switch (action) {
      case null:
        return null;
      case ClockNoticeAction.openAppSettings:
        return SnackBarAction(
          label: 'Ajustes',
          textColor: Colors.white,
          onPressed: () {
            unawaited(_devicePermissionBootstrap.openAppSettings());
          },
        );
      case ClockNoticeAction.openLocationSettings:
        return SnackBarAction(
          label: 'GPS',
          textColor: Colors.white,
          onPressed: () {
            unawaited(_devicePermissionBootstrap.openLocationSettings());
          },
        );
      case ClockNoticeAction.openSecurityEvents:
        return SnackBarAction(
          label: 'Ver eventos',
          textColor: Colors.white,
          onPressed: () {
            unawaited(_openSecurityEvents());
          },
        );
    }
  }

  void _showDiagnosticsSheet(
    BuildContext context, {
    required AttendanceHomeViewData viewData,
    required ClockMetricsSnapshot clockMetrics,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (ctx, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  AttendanceDiagnosticsCard(
                    ruleBadges: [
                      if (_config != null) ...[
                        AttendanceRuleChip(
                          label: 'QR',
                          enabled: _config!.requiereQr,
                        ),
                        AttendanceRuleChip(
                          label: 'FOTO',
                          enabled: _config!.requiereFoto,
                        ),
                        const AttendanceRuleChip(label: 'GPS', enabled: true),
                        AttendanceInfoChip(
                          'Cooldown: ${_config!.cooldownScanSegundos}s',
                        ),
                        if (_config!.intervaloMinimoFichadasMinutos != null)
                          AttendanceInfoChip(
                            'Intervalo min: ${_config!.intervaloMinimoFichadasMinutos} min',
                          ),
                        if (_config!.toleranciaGlobal != null)
                          AttendanceInfoChip(
                            'Tolerancia: ${_config!.toleranciaGlobal} min',
                          ),
                        if (_config!.metodosHabilitados.isNotEmpty)
                          AttendanceInfoChip(
                            'Metodos: ${_config!.metodosHabilitados.join(', ')}',
                          ),
                      ],
                    ],
                    hasMetrics: clockMetrics.hasSamples,
                    sampleCount: clockMetrics.sampleCount,
                    lastClockText: viewData.lastClockStatText == '-'
                        ? null
                        : viewData.lastClockStatText,
                    lastTotalText: viewData.lastClockTotalText,
                    lastApiText: viewData.lastClockApiText,
                    lastGpsText: viewData.lastClockGpsText,
                    lastPhotoText: viewData.lastClockPhotoText,
                    averageTotalText: viewData.avgTotal,
                    averageApiText: viewData.avgApi,
                    lastQrText: _lastQrData == null
                        ? null
                        : shortQrToken(_lastQrData!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTodayLastMark() async {
    final today = DateFormatter.formatApiDate(DateTime.now());
    try {
      final result = await widget.apiClient.getMarcas(
        token: widget.token,
        page: 1,
        per: 50,
        desde: today,
        hasta: today,
      );
      if (!mounted || result.items.isEmpty) return;
      final last = result.items.reduce(
        (a, b) => ((a.hora ?? '').compareTo(b.hora ?? '') >= 0) ? a : b,
      );
      final at = _parseMarcaToDateTime(last);
      if (at != null && mounted) {
        setState(() {
          _clockMetrics = _clockMetrics.copyWith(lastClockAt: at);
        });
      }
    } catch (_) {
      // silencioso — no es crítico para el funcionamiento de la app
    }
  }

  DateTime? _parseMarcaToDateTime(MarcaItem marca) {
    final fecha = marca.fecha;
    final hora = marca.hora;
    if (fecha == null || hora == null) return null;
    try {
      final d = fecha.split('-');
      final t = hora.split(':');
      if (d.length < 3) return null;
      return DateTime(
        int.parse(d[0]),
        int.parse(d[1]),
        int.parse(d[2]),
        t.isNotEmpty ? int.parse(t[0]) : 0,
        t.length > 1 ? int.parse(t[1]) : 0,
      );
    } catch (_) {
      return null;
    }
  }

  void _recordClockMetrics({
    required Duration total,
    Duration? api,
    Duration? gps,
    Duration? photo,
    required bool success,
    String? errorCode,
  }) {
    if (mounted) {
      setState(() {
        _clockMetrics = _clockMetricsTracker.record(
          current: _clockMetrics,
          total: total,
          api: api,
          gps: gps,
          photo: photo,
        );
      });
    } else {
      _clockMetrics = _clockMetricsTracker.record(
        current: _clockMetrics,
        total: total,
        api: api,
        gps: gps,
        photo: photo,
      );
    }
    _log.debug(
      'clock-metric success=$success code=${errorCode ?? "-"} '
      'total_ms=${total.inMilliseconds} api_ms=${api?.inMilliseconds ?? 0} '
      'gps_ms=${gps?.inMilliseconds ?? 0} photo_ms=${photo?.inMilliseconds ?? 0}',
    );
  }

  String? _syncStatusText() {
    final configAt = _configLoadedAt;
    final profileAt = _profileLoadedAt;
    DateTime? latest;
    if (configAt != null && profileAt != null) {
      latest = configAt.isAfter(profileAt) ? configAt : profileAt;
    } else {
      latest = configAt ?? profileAt;
    }
    if (latest == null) {
      return null;
    }
    final diff = DateTime.now().difference(latest);
    if (diff.inSeconds < 60) {
      return 'Datos sincronizados hace ${diff.inSeconds}s';
    }
    if (diff.inMinutes < 60) {
      return 'Datos sincronizados hace ${diff.inMinutes} min';
    }
    return 'Datos sincronizados hace ${diff.inHours} h';
  }

  String _sessionStatusText() {
    if (widget.sessionManager.isRefreshing) {
      return 'Sesión: renovando...';
    }
    if (widget.sessionManager.isLocked) {
      return 'Sesión: bloqueada';
    }
    return 'Sesión: activa';
  }

  Color _sessionStatusColor() {
    if (widget.sessionManager.isRefreshing) {
      return const Color(0xFFE8EEF7);
    }
    if (widget.sessionManager.isLocked) {
      return const Color(0xFFFFE0E0);
    }
    return const Color(0xFFE6F4EA);
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab && index == 0) return;
    switch (index) {
      case 0:
        setState(() => _selectedTab = 0);
      case 1:
        unawaited(_navigateAndReset(_openMarksHistory, index));
      case 2:
        unawaited(_navigateAndReset(_openStats, index));
      case 3:
        unawaited(_navigateAndReset(_openProfile, index));
    }
  }

  String _greetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Future<void> _navigateAndReset(
    Future<void> Function() action,
    int tab,
  ) async {
    setState(() => _selectedTab = tab);
    await action();
    if (mounted) setState(() => _selectedTab = 0);
  }

  @override
  Widget build(BuildContext context) {
    final empleado = widget.empleado;
    final now = DateTime.now();
    final fotoUrl = _resolvedPhotoUrl;
    final sessionColor = _sessionStatusColor();
    final readiness = _clockReadiness;
    final clockMetrics = _clockMetrics;
    final pendingQueue = _pendingQueue;
    final viewData = const AttendanceHomeViewDataBuilder().build(
      now: now,
      screenWidth: MediaQuery.of(context).size.width,
      syncText: _syncStatusText() ?? 'Sincronizando datos...',
      sessionBaseText: _sessionStatusText(),
      // Solo propagar statusMessage cuando agrega info real (lock/refresh).
      // En sesion activa normal, statusMessage = 'Sesion activa.' que ya esta
      // incorporado en sessionBaseText, lo que causaria texto duplicado.
      sessionMessage: (widget.sessionManager.isRefreshing ||
              widget.sessionManager.isLocked)
          ? widget.sessionManager.statusMessage
          : null,
      sessionColor: sessionColor,
      readiness: readiness,
      clockMetrics: clockMetrics,
      pendingQueue: pendingQueue,
      loadingConfig: _loadingConfig,
      hasFreshConfig: _hasFreshConfig(),
      hasFreshGps: _hasFreshGps(),
      formatTimeOfDay: fmtClockTimeOfDay,
      formatRelative: fmtClockRelative,
      formatDuration: fmtClockDuration,
      isSameDay: clockIsSameDay,
    );
    final actionViewData = _homeActionPresenter.build(
      viewData: viewData,
      pendingQueue: pendingQueue,
      submitting: _submitting,
      locatingGps: _locatingGps,
      isBusy: _isBusy,
    );
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FichaYa'),
        actions: [
          PopupMenuButton<_HomeMenuAction>(
            enabled: !_submitting,
            icon: const Icon(Icons.more_vert),
            tooltip: 'Mas opciones',
            onSelected: (action) async {
              switch (action) {
                case _HomeMenuAction.biometrics:
                  await _openBiometricSettings();
                case _HomeMenuAction.security:
                  await _openSecurityEvents();
                case _HomeMenuAction.rateApp:
                  await _openRateApp();
                case _HomeMenuAction.links:
                  await _openLinks();
                case _HomeMenuAction.diagnostics:
                  if (mounted) {
                    _showDiagnosticsSheet(
                      context,
                      viewData: viewData,
                      clockMetrics: clockMetrics,
                    );
                  }
                case _HomeMenuAction.lockSession:
                  await widget.onLockSession();
                case _HomeMenuAction.about:
                  await _homeCoordinator.openAbout(context);
                case _HomeMenuAction.logout:
                  await widget.onLogout();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _HomeMenuAction.biometrics,
                child: ListTile(
                  leading: Icon(Icons.fingerprint),
                  title: Text('Sesion y sonido'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _HomeMenuAction.security,
                child: ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Seguridad'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _HomeMenuAction.rateApp,
                child: ListTile(
                  leading: Icon(Icons.star_outline_rounded),
                  title: Text('Calificá la app'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _HomeMenuAction.links,
                child: ListTile(
                  leading: Icon(Icons.link_rounded),
                  title: Text('Acceso a mis Links'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              if (!AppConfig.current.isProd)
                const PopupMenuItem(
                  value: _HomeMenuAction.diagnostics,
                  child: ListTile(
                    leading: Icon(Icons.developer_mode_outlined),
                    title: Text('Diagnóstico'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _HomeMenuAction.about,
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Acerca de'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _HomeMenuAction.lockSession,
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Bloquear sesión'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: _HomeMenuAction.logout,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Cerrar sesión'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitting ? null : _fichar,
        backgroundColor: _submitting ? cs.surfaceContainerHighest : const Color(0xFF00B09C),
        foregroundColor: Colors.white,
        elevation: 6,
        tooltip: 'Fichar con QR',
        shape: const CircleBorder(),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.qr_code_scanner, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 64,
        padding: EdgeInsets.zero,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBarItem(
              icon: Badge(
                isLabelVisible: pendingQueue.hasPending,
                label: Text('${pendingQueue.total}',
                    style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.home_outlined),
              ),
              selectedIcon: const Icon(Icons.home),
              label: 'Inicio',
              selected: _selectedTab == 0,
              onTap: () => _onTabSelected(0),
            ),
            _NavBarItem(
              icon: const Icon(Icons.punch_clock_outlined),
              selectedIcon: const Icon(Icons.punch_clock),
              label: 'Historial',
              selected: _selectedTab == 1,
              onTap: () => _onTabSelected(1),
            ),
            const SizedBox(width: 64), // espacio para el FAB
            _NavBarItem(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: 'Stats',
              selected: _selectedTab == 2,
              onTap: () => _onTabSelected(2),
            ),
            _NavBarItem(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: 'Perfil',
              selected: _selectedTab == 3,
              onTap: () => _onTabSelected(3),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
        onRefresh: _refreshHome,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: viewData.contentMaxWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                viewData.horizontalPadding,
                20,
                viewData.horizontalPadding,
                24,
              ),
              children: [
                if (_loadingConfig || _loadingProfile)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (viewData.hasPendingUrgency)
                  AttendancePendingBanner(
                    hasErrors: viewData.hasPendingErrors,
                    pendingCleanCount: viewData.pendingClean,
                    failedCount: pendingQueue.failed,
                    lastSyncText: viewData.lastSyncText,
                    statusMessage: pendingQueue.lastMessage,
                    primaryAction: _buttonData(actionViewData.bannerPrimary),
                    secondaryAction: _buttonData(actionViewData.bannerSecondary),
                  ),
                if (viewData.hasPendingUrgency) const SizedBox(height: 12),
                AttendanceHeroCard(
                  photoUrl: fotoUrl,
                  token: widget.token,
                  greeting: _greetingPrefix(),
                  employeeName: empleado.nombreCompleto,
                  employeeDni: empleado.dni,
                  employeeCompany: null,
                  syncText: viewData.syncText,
                  sessionText: viewData.sessionText,
                  sessionColor: sessionColor,
                  sessionForeground: viewData.sessionForeground,
                  gpsStatusText: viewData.gpsStatusText,
                ),
                if (_profileLoadError != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _profileLoadError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // ── Status banner ──────────────────────────────────
                AttendanceStatusBanner(
                  pendingTotal: pendingQueue.total,
                  pendingFailed: pendingQueue.failed,
                  lastClockText: viewData.lastClockStatText,
                  hasClockToday: viewData.hasClockToday,
                  hasFreshGps: viewData.hasFreshGps,
                  onTap: viewData.hasPendingErrors || viewData.hasPendingSync
                      ? () => unawaited(_openPendingQueueDetails())
                      : null,
                ),
                if (_turnoHoy != null && _turnoHoy!.bloques.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _TurnoHoyBanner(turno: _turnoHoy!),
                ],
                const SizedBox(height: 12),
                // ── Stats grid (4 tiles) ───────────────────────────
                AttendanceStatsCarousel(
                  items: [
                    AttendanceStatItem(
                      title: 'Puntualidad',
                      value: _dashboard != null
                          ? '${_dashboard!.asistencia.kpis.puntualidadPct.toStringAsFixed(0)}%'
                          : '–',
                      icon: Icons.timer_outlined,
                      accent: const Color(0xFF2A789E),
                    ),
                    AttendanceStatItem(
                      title: 'A tiempo semana',
                      value: _dashboard != null
                          ? '${_dashboard!.asistencia.totales.ok} / ${_dashboard!.asistencia.totales.ok + _dashboard!.asistencia.totales.tarde + _dashboard!.asistencia.totales.ausente}'
                          : '–',
                      icon: Icons.calendar_today_outlined,
                      accent: const Color(0xFF315D52),
                    ),
                    AttendanceStatItem(
                      title: 'Pendientes',
                      value: '${pendingQueue.total}',
                      icon: Icons.cloud_upload_outlined,
                      accent: pendingQueue.total > 0
                          ? const Color(0xFFC85F0F)
                          : const Color(0xFF3D4F6B),
                    ),
                    AttendanceStatItem(
                      title: 'Última fichada',
                      value: viewData.lastClockStatText,
                      icon: Icons.punch_clock_outlined,
                      accent: const Color(0xFF5C3D8F),
                    ),
                  ],
                ),
                // ── Trivia card ────────────────────────────────────────────
                const SizedBox(height: 12),
                _TriviaDashboardCard(
                  estado: _triviaEstado,
                  notificaciones: _triviaNotificaciones,
                  onTap: () => unawaited(_openTrivia()),
                ),
                const SizedBox(height: 8),
                _TriviaPuntosCard(
                  puntos: _triviaPuntosAcumulados,
                  onTap: () => unawaited(_openTrivia()),
                ),
                // ── Readiness strip: solo visible si algo no está listo ────
                if (!viewData.configReady ||
                    !viewData.cameraReady ||
                    !(viewData.locationReady && viewData.locationServiceReady) ||
                    !viewData.hasFreshGps ||
                    readiness.warming ||
                    _clockActionPhase != null) ...[
                  const SizedBox(height: 12),
                  AttendanceReadinessStrip(
                    warming: readiness.warming,
                    phaseText: _clockActionPhase,
                    badges: [
                      AttendanceReadinessBadgeData(
                        text: viewData.configPrepText,
                        ready: viewData.configReady,
                      ),
                      AttendanceReadinessBadgeData(
                        text: viewData.cameraPrepText,
                        ready: viewData.cameraReady,
                      ),
                      AttendanceReadinessBadgeData(
                        text: viewData.locationPrepText,
                        ready: viewData.locationReady &&
                            viewData.locationServiceReady,
                      ),
                      AttendanceReadinessBadgeData(
                        text: viewData.gpsPrepText,
                        ready: viewData.hasFreshGps,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // ── Quick actions ──────────────────────────────────
                AttendanceQuickActionsCard(
                  items: actionViewData.quickActions
                      .map(_quickActionItem)
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
          ),
          // ── Overlay de procesamiento (visible mientras _submitting = true) ─
          if (_submitting)
            _ClockProcessingOverlay(phase: _clockActionPhase),
        ],
      ),
    );
  }

}

// ─── Turno de hoy ────────────────────────────────────────────────────────────

class _TurnoHoyBanner extends StatelessWidget {
  const _TurnoHoyBanner({required this.turno});

  final HorarioEsperadoResponse turno;

  String _bloquesText() {
    return turno.bloques
        .map((b) => '${b.entrada} – ${b.salida}')
        .join('  |  ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turno de hoy',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                Text(
                  _bloquesText(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          if (turno.tolerancia != null && turno.tolerancia! > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '±${turno.tolerancia} min',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
          ],
          if (turno.tieneExcepcion) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Horario con excepción',
              child: Icon(Icons.info_outline, size: 16, color: cs.tertiary),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Menu actions ────────────────────────────────────────────────────────────

enum _HomeMenuAction { biometrics, security, rateApp, links, diagnostics, lockSession, about, logout }

// ─── Processing overlay ───────────────────────────────────────────────────────

/// Overlay que cubre el body mientras se procesa una fichada.
/// Aparece en cuanto el usuario vuelve de la pantalla de escaneo QR y
/// desaparece al terminar (success, error u offline queued).
class _ClockProcessingOverlay extends StatelessWidget {
  const _ClockProcessingOverlay({required this.phase});

  final String? phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black45),
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 16,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    phase ?? 'Procesando fichada...',
                    key: ValueKey(phase),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Por favor espera un momento',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Trivia Dashboard Card ────────────────────────────────────────────────────

class _TriviaDashboardCard extends StatelessWidget {
  const _TriviaDashboardCard({
    required this.estado,
    required this.notificaciones,
    required this.onTap,
  });

  final TriviaEstadoResponse? estado;
  final List<TriviaNotificacion> notificaciones;
  final VoidCallback onTap;

  static const _primary = Color(0xFF0E3A5B);
  static const _gradientA = Color(0xFF6C3EB8);
  static const _gradientB = Color(0xFF00B09C);

  @override
  Widget build(BuildContext context) {
    final e = estado;
    final tieneNotif = notificaciones.isNotEmpty;

    // Estado destacado: trivia activa sin participar → tarjeta grande con gradiente
    if (e != null && e.hayTriviaActiva) {
      final trivia = e.trivia!;
      if (trivia.estado == 'activa' && !e.yaParticipo) {
        return _buildActivaCard(trivia, tieneNotif);
      }
    }

    return _buildCompactCard(context, e, tieneNotif);
  }

  Widget _buildActivaCard(TriviaInfo trivia, bool tieneNotif) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_gradientA, _gradientB],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _gradientA.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tieneNotif)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const Text(
                        '🎯  TRIVIA ACTIVA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text('🏆', style: TextStyle(fontSize: 24)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              trivia.titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              '¡Respondé y competí por el primer lugar!',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _gradientA,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: onTap,
                child: const Text('Jugar ahora →'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(
    BuildContext context,
    TriviaEstadoResponse? e,
    bool tieneNotif,
  ) {
    final cs = Theme.of(context).colorScheme;

    final String titulo;
    final String subtitulo;
    final Color badgeColor;
    final IconData icono;
    final String? botonLabel;

    if (e == null) {
      titulo = 'Trivia';
      subtitulo = 'Demostrá tu conocimiento';
      badgeColor = _primary;
      icono = Icons.quiz_outlined;
      botonLabel = 'Abrir';
    } else if (!e.hayTriviaActiva) {
      titulo = 'Trivia';
      subtitulo = tieneNotif
          ? notificaciones.first.mensaje ?? 'Sin trivias activas'
          : 'No hay trivias activas por el momento';
      badgeColor = Colors.grey.shade500;
      icono = Icons.history_outlined;
      botonLabel = 'Ver historial';
    } else {
      final trivia = e.trivia!;
      final est = trivia.estado;
      if (est == 'programada') {
        titulo = 'Próxima trivia';
        subtitulo = trivia.titulo;
        badgeColor = const Color(0xFF315D52);
        icono = Icons.schedule_outlined;
        botonLabel = null;
      } else if (est == 'activa' && e.yaParticipo) {
        final pts = e.participacion?.puntosTotal;
        titulo = 'Ya participaste';
        subtitulo = pts != null ? '${trivia.titulo} · $pts pts' : trivia.titulo;
        badgeColor = const Color(0xFF2A789E);
        icono = Icons.check_circle_outline;
        botonLabel = 'Ver ranking';
      } else {
        titulo = 'Trivia';
        subtitulo = trivia.titulo;
        badgeColor = Colors.grey.shade500;
        icono = Icons.history_outlined;
        botonLabel = 'Ver historial';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icono, color: badgeColor, size: 24),
                ),
                if (tieneNotif)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitulo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (botonLabel != null) ...[
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: badgeColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: onTap,
                child: Text(botonLabel),
              ),
            ] else
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Trivia Puntos Card ───────────────────────────────────────────────────────

class _TriviaPuntosCard extends StatelessWidget {
  const _TriviaPuntosCard({required this.puntos, required this.onTap});

  final int puntos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF0E3A5B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            const Text(
              'Mis Puntos Trivia',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '$puntos pts',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom nav item ──────────────────────────────────────────────────────────

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final Widget selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(color: color, size: 24),
                child: selected ? selectedIcon : icon,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
