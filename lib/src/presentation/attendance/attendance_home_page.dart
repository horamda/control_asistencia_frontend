import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

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
  static const Duration _configCacheTtl = Duration(minutes: 3);
  static const Duration _gpsCacheTtl = Duration(minutes: 2);
  static const Duration _clockReadinessRefreshInterval = Duration(seconds: 75);

  final ImagePicker _imagePicker = ImagePicker();
  final ClockPhotoCache _clockPhotoCache = ClockPhotoCache();
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

  bool _submitting = false;
  bool _loadingConfig = false;
  bool _loadingProfile = false;
  bool _locatingGps = false;
  String? _lastQrData;
  String? _profileLoadError;
  AttendanceConfig? _config;
  EmployeeProfile? _profile;
  DateTime? _configLoadedAt;
  DateTime? _profileLoadedAt;
  Timer? _pendingSyncTicker;
  Timer? _clockReadinessTicker;
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
    unawaited(_feedbackAudio.initialize());
    unawaited(_applyFeedbackProfileFromSession());
    _loadConfig();
    _loadProfile();
    _loadPendingQueueState();
    Future<void>.microtask(() => _warmUpClockReadiness(forceGps: true));
    Future<void>.microtask(
      () => _pendingClockSyncService.pruneEmployeePhotos(
        employeeId: widget.empleado.id,
      ),
    );
    Future<void>.microtask(() => _syncPendingClocks(silent: true));
    _pendingSyncTicker = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted || !_pendingQueue.hasPending || _pendingQueue.syncing || _submitting) {
        return;
      }
      _syncPendingClocks(silent: true);
    });
    _clockReadinessTicker = Timer.periodic(_clockReadinessRefreshInterval, (_) {
      if (!mounted || _submitting || _locatingGps) {
        return;
      }
      unawaited(_warmUpClockReadiness());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingSyncTicker?.cancel();
    _clockReadinessTicker?.cancel();
    unawaited(_feedbackAudio.dispose());
    super.dispose();
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
    final previousPhotoUrl = _photoUrlForProfile(_profile);
    setState(() {
      _loadingProfile = true;
    });
    try {
      final profile = await widget.apiClient.getMe(token: widget.token);
      final nextPhotoUrl = _photoUrlForProfile(profile);
      if (previousPhotoUrl != nextPhotoUrl) {
        await ProfilePhotoCache.evict(previousPhotoUrl);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _profileLoadError = null;
        _profileLoadedAt = DateTime.now();
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
    if (_loadingConfig) {
      return;
    }
    if (!force && _hasFreshConfig()) {
      return;
    }
    setState(() {
      _loadingConfig = true;
    });
    try {
      final config = await widget.apiClient.getConfigAsistencia(
        token: widget.token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _configLoadedAt = DateTime.now();
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingConfig = false;
        });
      }
    }
  }

  bool _hasFreshGps() {
    return _clockReadiness.hasFreshGps(_gpsCacheTtl);
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
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 70,
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
            _clockFeedbackPresenter.permissionSettings(missing: 'la ubicacion'),
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
      _showMessage(
        'GPS OK: ${gps.lat.toStringAsFixed(6)}, ${gps.lon.toStringAsFixed(6)}',
      );
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
          _clockFeedbackPresenter.permissionSettings(missing: 'la camara'),
        );
        return;
      case QrClockPreflightStatus.locationServiceDisabled:
        _showNotice(_clockFeedbackPresenter.locationServiceDisabled());
        return;
      case QrClockPreflightStatus.locationPermissionDenied:
        _showNotice(
          _clockFeedbackPresenter.permissionSettings(missing: 'la ubicacion'),
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
        formatDuration: _fmtDuration,
      );
      _showNotice(presentation.notice);
      if (presentation.shouldSyncPendingSilently) {
        await _syncPendingClocks(silent: true);
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

  Future<String?> _syncPendingClocks({bool silent = false}) async {
    if (_pendingQueue.syncing) {
      return null;
    }

    final started = _pendingQueueController.startSync(
      current: _pendingQueue,
      silent: silent,
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
      silent: silent,
    );
    if (!mounted) {
      _pendingQueue = next;
      return silent ? null : next.lastMessage;
    }
    setState(() {
      _pendingQueue = next;
    });
    return silent ? null : next.lastMessage;
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
        silent: false,
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
      formatDateTime: _fmtDateTime,
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
      _syncPendingClocks(silent: true),
      _warmUpClockReadiness(forceGps: true, refreshConfig: true),
    ]);
    await _loadPendingQueueState();
  }

  bool get _isBusy => _submitting || _loadingConfig;

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
            _openSecurityEvents();
          },
        );
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
    debugPrint(
      '[clock-metric] success=$success code=${errorCode ?? "-"} '
      'total_ms=${total.inMilliseconds} api_ms=${api?.inMilliseconds ?? 0} '
      'gps_ms=${gps?.inMilliseconds ?? 0} photo_ms=${photo?.inMilliseconds ?? 0}',
    );
  }

  String _fmtDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds} ms';
    }
    return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s';
  }

  String _fmtTimeOfDay(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    final ss = dateTime.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _fmtDateTime(DateTime dateTime) {
    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final y = dateTime.year.toString().padLeft(4, '0');
    return '$d/$m/$y ${_fmtTimeOfDay(dateTime)}';
  }

  String _fmtRelative(DateTime dateTime) {
    var diff = DateTime.now().difference(dateTime);
    if (diff.isNegative) {
      diff = Duration.zero;
    }
    if (diff.inSeconds < 45) {
      return 'hace segundos';
    }
    if (diff.inMinutes < 60) {
      return 'hace ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'hace ${diff.inHours} h';
    }
    return 'hace ${diff.inDays} d';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
      return 'Sesion: renovando...';
    }
    if (widget.sessionManager.isLocked) {
      return 'Sesion: bloqueada';
    }
    return 'Sesion: activa';
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

  Future<void> _showSessionExitOptions() async {
    if (_submitting) {
      return;
    }
    final action = await _homeCoordinator.showSessionExitOptions(context);
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case AttendanceSessionExitAction.lock:
        await widget.onLockSession();
        return;
      case AttendanceSessionExitAction.logout:
        await widget.onLogout();
    }
  }

  String _resolvePhotoUrl({String? rawUrl, String? dni, int? imagenVersion}) {
    return ProfilePhotoCache.resolve(
      rawUrl: rawUrl,
      dni: dni,
      version: imagenVersion,
      fallbackBuilder: (valueDni, valueVersion) => widget.apiClient
          .buildEmpleadoImagenUrl(dni: valueDni, version: valueVersion),
    );
  }

  String _photoUrlForProfile(EmployeeProfile? profile) {
    if (profile != null) {
      final fromProfile = _resolvePhotoUrl(
        rawUrl: profile.foto,
        dni: profile.dni ?? widget.empleado.dni,
        imagenVersion: profile.imagenVersion,
      );
      if (fromProfile.isNotEmpty) {
        return fromProfile;
      }
    }
    return _resolvePhotoUrl(
      rawUrl: widget.empleado.foto,
      dni: widget.empleado.dni,
      imagenVersion: widget.empleado.imagenVersion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final empleado = widget.empleado;
    final now = DateTime.now();
    final fotoUrl = _photoUrlForProfile(_profile);
    final sessionColor = _sessionStatusColor();
    final readiness = _clockReadiness;
    final clockMetrics = _clockMetrics;
    final pendingQueue = _pendingQueue;
    final viewData = const AttendanceHomeViewDataBuilder().build(
      now: now,
      screenWidth: MediaQuery.of(context).size.width,
      syncText: _syncStatusText() ?? 'Sincronizando datos...',
      sessionBaseText: _sessionStatusText(),
      sessionMessage: widget.sessionManager.statusMessage,
      sessionColor: sessionColor,
      readiness: readiness,
      clockMetrics: clockMetrics,
      pendingQueue: pendingQueue,
      loadingConfig: _loadingConfig,
      hasFreshConfig: _hasFreshConfig(),
      hasFreshGps: _hasFreshGps(),
      formatTimeOfDay: _fmtTimeOfDay,
      formatRelative: _fmtRelative,
      formatDuration: _fmtDuration,
      isSameDay: _isSameDay,
    );
    final actionViewData = _homeActionPresenter.build(
      viewData: viewData,
      pendingQueue: pendingQueue,
      submitting: _submitting,
      locatingGps: _locatingGps,
      isBusy: _isBusy,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichada por QR'),
        actions: [
          IconButton(
            onPressed: _submitting ? null : _openProfile,
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi perfil',
          ),
          IconButton(
            onPressed: _submitting ? null : _openBiometricSettings,
            icon: const Icon(Icons.fingerprint),
            tooltip: 'Seguridad y sonido',
          ),
          IconButton(
            onPressed: _submitting ? null : _showSessionExitOptions,
            icon: const Icon(Icons.logout),
            tooltip: 'Opciones de sesion',
          ),
        ],
      ),
      body: RefreshIndicator(
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
                  employeeName: empleado.nombreCompleto,
                  employeeDni: empleado.dni,
                  employeeCompany: empleado.empresaId == null
                      ? null
                      : 'Empresa: ${empleado.empresaId}',
                  syncText: viewData.syncText,
                  sessionText: viewData.sessionText,
                  sessionColor: sessionColor,
                  sessionForeground: viewData.sessionForeground,
                  gpsStatusText: viewData.gpsStatusText,
                ),
                if (_profileLoadError != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    color: const Color(0xFFFFF4E5),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_profileLoadError!),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                AttendanceNextStepCard(
                  priorityLabel: viewData.nextStepPriorityLabel,
                  priorityBackground: viewData.nextStepPriorityBackground,
                  priorityForeground: viewData.nextStepPriorityForeground,
                  title: viewData.nextStepTitle,
                  body: viewData.nextStepBody,
                  primaryAction: _buttonData(actionViewData.nextStepPrimary),
                  secondaryAction: _buttonData(
                    actionViewData.nextStepSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                AttendanceStatsGrid(
                  items: [
                    AttendanceStatItem(
                      title: 'Pendientes',
                      value: '${pendingQueue.total}',
                      icon: Icons.cloud_upload_outlined,
                      accent: const Color(0xFF2A789E),
                    ),
                    AttendanceStatItem(
                      title: 'Con error',
                      value: '${pendingQueue.failed}',
                      icon: Icons.warning_amber_rounded,
                      accent: const Color(0xFFC85F0F),
                    ),
                    AttendanceStatItem(
                      title: 'Ultima sync',
                      value: viewData.lastSyncStatText,
                      icon: Icons.schedule,
                      accent: const Color(0xFF3D4F6B),
                    ),
                    AttendanceStatItem(
                      title: 'Ultima fichada',
                      value: viewData.lastClockStatText,
                      icon: Icons.punch_clock_outlined,
                      accent: const Color(0xFF315D52),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_2_outlined),
                            const SizedBox(width: 8),
                            Text(
                              'Fichar',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Escanea el QR en el punto de control. Detectamos ingreso/egreso automaticamente.',
                        ),
                        const SizedBox(height: 12),
                        AttendanceClockPanel(
                          warming: readiness.warming,
                          readinessBadges: [
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
                          readinessSummary: viewData.readinessSummary,
                          readinessCheckText: viewData.readinessCheckText,
                          phaseText: _clockActionPhase,
                          mainAction: _buttonData(actionViewData.clockMain),
                          secondaryActions: actionViewData.clockSecondary
                              .map(_buttonData)
                              .toList(growable: false),
                          gpsText: viewData.gpsText,
                          lastQrText: _lastQrData == null
                              ? null
                              : _shortQr(_lastQrData!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AttendanceQuickActionsCard(
                  columns: viewData.quickActionColumns,
                  ratio: viewData.quickActionRatio,
                  items: actionViewData.quickActions
                      .map(_quickActionItem)
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
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
                          'Intervalo minimo: ${_config!.intervaloMinimoFichadasMinutos} min',
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
                  lastQrText: _lastQrData == null ? null : _shortQr(_lastQrData!),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Para fichar con QR la ubicacion del dispositivo es obligatoria. '
                      'Si no hay internet, la marca queda en cola offline. '
                      'Desliza hacia abajo para refrescar.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortQr(String token) {
    if (token.length <= 38) {
      return token;
    }
    return '${token.substring(0, 22)}...${token.substring(token.length - 12)}';
  }
}
