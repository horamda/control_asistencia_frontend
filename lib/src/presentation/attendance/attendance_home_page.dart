import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';
import '../../core/attendance/attendance_config_cache.dart';
import '../../core/attendance/clock_readiness_cache.dart';
import '../../core/attendance/clock_feedback_presenter.dart';
import '../../core/attendance/clock_gps_service.dart';
import '../../core/attendance/clock_metrics_tracker.dart';
import '../../core/attendance/qr_clock_preflight_service.dart';
import '../../core/attendance/clock_readiness_service.dart';
import '../../core/attendance/qr_clock_submission_service.dart';
import '../../core/feedback/clock_feedback_audio_service.dart';
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
  static const Duration _gpsCacheTtl = Duration(minutes: 2);
  static const Duration _clockReadinessRefreshInterval = Duration(seconds: 75);

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
    unawaited(_feedbackAudio.initialize());
    unawaited(_applyFeedbackProfileFromSession());
    unawaited(_preloadReadinessFromCache());
    _loadConfig();
    _loadProfile();
    unawaited(_loadDashboard());
    _loadPendingQueueState();
    Future<void>.microtask(() => _warmUpClockReadiness(forceGps: true));
    Future<void>.microtask(
      () => _pendingClockSyncService.pruneEmployeePhotos(
        employeeId: widget.empleado.id,
      ),
    );
    Future<void>.microtask(() => _syncPendingClocks(isBackground: true));
    _pendingSyncTicker = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted || !_pendingQueue.hasPending || _pendingQueue.syncing || _submitting) {
        return;
      }
      _syncPendingClocks(isBackground: true);
    });
    _clockReadinessTicker = Timer.periodic(_clockReadinessRefreshInterval, (_) {
      if (!mounted || _submitting || _locatingGps) {
        return;
      }
      unawaited(_warmUpClockReadiness());
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingSyncTicker?.cancel();
    _clockReadinessTicker?.cancel();
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
      unawaited(_warmUpClockReadiness(forceGps: true, refreshConfig: true));
    }
  }

  Future<void> _fichar() async {
    await _runScanAndClock();
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
        _profileLoadError = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileLoadError = 'No se pudo cargar el perfil/foto.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });
      }
    }
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
      floatingActionButton: FloatingActionButton.large(
        onPressed: _submitting ? null : _fichar,
        backgroundColor: _submitting ? cs.surfaceContainerHighest : const Color(0xFF00B09C),
        foregroundColor: Colors.white,
        elevation: 6,
        tooltip: 'Fichar con QR',
        shape: const CircleBorder(),
        child: _submitting
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.qr_code_scanner, size: 34),
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

// ─── Menu actions ────────────────────────────────────────────────────────────

enum _HomeMenuAction { biometrics, security, diagnostics, lockSession, logout }

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
