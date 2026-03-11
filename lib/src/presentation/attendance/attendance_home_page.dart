import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/feedback/clock_feedback_audio_service.dart';
import '../../core/image/clock_photo_cache.dart';
import '../../core/image/profile_photo_cache.dart';
import '../../core/auth/session_manager.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/offline/offline_clock_queue.dart';
import '../../core/permissions/device_permission_bootstrap.dart';
import '../auth/biometric_settings_page.dart';
import '../profile/profile_page.dart';
import '../widgets/centered_snackbar.dart';
import '../widgets/employee_photo_widget.dart';
import 'attendance_history_page.dart';
import 'employee_stats_page.dart';
import 'marks_history_page.dart';
import 'qr_scan_page.dart';
import 'security_events_page.dart';

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

class _AttendanceHomePageState extends State<AttendanceHomePage> {
  static const Duration _configCacheTtl = Duration(minutes: 3);
  static const Duration _gpsCacheTtl = Duration(minutes: 2);

  final ImagePicker _imagePicker = ImagePicker();
  final OfflineClockQueue _offlineClockQueue = OfflineClockQueue();
  final ClockPhotoCache _clockPhotoCache = ClockPhotoCache();
  final ClockFeedbackAudioService _feedbackAudio = ClockFeedbackAudioService();
  final DevicePermissionBootstrap _devicePermissionBootstrap =
      DevicePermissionBootstrap();

  bool _submitting = false;
  bool _loadingConfig = false;
  bool _loadingProfile = false;
  bool _locatingGps = false;
  String? _lastQrData;
  String? _profileLoadError;
  _GpsPoint? _lastGps;
  AttendanceConfig? _config;
  EmployeeProfile? _profile;
  DateTime? _configLoadedAt;
  DateTime? _profileLoadedAt;
  DateTime? _lastClockAt;
  Duration? _lastClockTotalDuration;
  Duration? _lastClockApiDuration;
  Duration? _lastClockGpsDuration;
  Duration? _lastClockPhotoDuration;
  int _clockMeasureCount = 0;
  int _clockMeasureTotalMs = 0;
  int _clockMeasureApiMs = 0;
  int _clockMeasureApiCount = 0;
  bool _syncingPending = false;
  int _pendingCount = 0;
  int _pendingFailedCount = 0;
  List<OfflineClockRecord> _pendingRecords = const [];
  DateTime? _lastPendingSyncAt;
  String? _pendingSyncMessage;
  Timer? _pendingSyncTicker;

  @override
  void initState() {
    super.initState();
    unawaited(_feedbackAudio.initialize());
    unawaited(_applyFeedbackProfileFromSession());
    _loadConfig();
    _loadProfile();
    _refreshPendingCount();
    Future<void>.microtask(_cleanupCachedClockPhotos);
    Future<void>.microtask(() => _syncPendingClocks(silent: true));
    _pendingSyncTicker = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted || _pendingCount <= 0 || _syncingPending || _submitting) {
        return;
      }
      _syncPendingClocks(silent: true);
    });
  }

  @override
  void dispose() {
    _pendingSyncTicker?.cancel();
    unawaited(_feedbackAudio.dispose());
    super.dispose();
  }

  Future<void> _fichar() async {
    await _runScanAndClock();
  }

  Future<void> _openSecurityEvents() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SecurityEventsPage(
          apiClient: widget.apiClient,
          token: widget.token,
        ),
      ),
    );
  }

  Future<void> _openAttendanceHistory() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceHistoryPage(
          apiClient: widget.apiClient,
          token: widget.token,
        ),
      ),
    );
  }

  Future<void> _openMarksHistory() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MarksHistoryPage(apiClient: widget.apiClient, token: widget.token),
      ),
    );
  }

  Future<void> _openStats() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EmployeeStatsPage(apiClient: widget.apiClient, token: widget.token),
      ),
    );
  }

  Future<void> _openProfile() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProfilePage(apiClient: widget.apiClient, token: widget.token),
      ),
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BiometricSettingsPage(sessionManager: widget.sessionManager),
      ),
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

  Future<String?> _resolveRecordPhoto(OfflineClockRecord record) async {
    final inline = (record.foto ?? '').trim();
    if (inline.isNotEmpty) {
      return inline;
    }
    return _clockPhotoCache.readAsBase64(record.fotoPath);
  }

  Future<void> _cleanupCachedClockPhotos({
    List<OfflineClockRecord>? keepRecords,
  }) async {
    final records =
        keepRecords ??
        await _offlineClockQueue.readForEmployee(widget.empleado.id);
    final keepPaths = records
        .map((item) => (item.fotoPath ?? '').trim())
        .where((path) => path.isNotEmpty)
        .toSet();
    await _clockPhotoCache.pruneEmployee(
      employeeId: widget.empleado.id,
      keepPaths: keepPaths,
    );
  }

  Future<_GpsPoint?> _captureGps() async {
    final cachedGps = _lastGps;
    final now = DateTime.now();
    if (cachedGps != null &&
        cachedGps.capturedAt != null &&
        now.difference(cachedGps.capturedAt!) < _gpsCacheTtl) {
      return cachedGps;
    }
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return null;
      }

      final permissionGranted =
          await _devicePermissionBootstrap.isLocationGranted();
      if (!permissionGranted) {
        return null;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final age = now.difference(lastKnown.timestamp);
        if (age < _gpsCacheTtl) {
          return _GpsPoint(
            lat: lastKnown.latitude,
            lon: lastKnown.longitude,
            accuracyM: lastKnown.accuracy,
            capturedAt: lastKnown.timestamp,
          );
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      return _GpsPoint(
        lat: position.latitude,
        lon: position.longitude,
        accuracyM: position.accuracy,
        capturedAt: DateTime.now(),
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
    });
    try {
      final gps = await _captureGps();
      if (!mounted) {
        return;
      }
      if (gps == null) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _showLocationServiceDisabledMessage();
        } else {
          _showPermissionSettingsMessage(missing: 'la ubicacion');
        }
        return;
      }
      setState(() {
        _lastGps = gps;
      });
      _showMessage(
        'GPS OK: ${gps.lat.toStringAsFixed(6)}, ${gps.lon.toStringAsFixed(6)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _locatingGps = false;
        });
      }
    }
  }

  Future<void> _runScanAndClock() async {
    if (_submitting || _loadingConfig) {
      return;
    }

    final flowWatch = Stopwatch()..start();
    bool shouldRecordMetrics = false;
    bool apiRequestStarted = false;
    Duration? photoDuration;
    Duration? gpsDuration;
    Duration? apiDuration;
    late final DateTime eventAt;

    await _loadConfig();
    if (!mounted) {
      return;
    }
    final effectiveConfig = _config;
    if (effectiveConfig == null) {
      _showMessage(
        'No se pudo obtener la configuracion de fichada. Reintenta.',
        isError: true,
      );
      return;
    }
    if (!effectiveConfig.isMetodoHabilitado('qr')) {
      _showMessage(
        'El metodo QR no esta habilitado para tu empresa en este momento.',
        isError: true,
      );
      return;
    }
    await _devicePermissionBootstrap.ensureRequestedAfterLogin();
    if (!mounted) {
      return;
    }
    final cameraGranted = await _devicePermissionBootstrap.isCameraGranted();
    if (!cameraGranted) {
      _showPermissionSettingsMessage(missing: 'la camara');
      return;
    }
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      _showLocationServiceDisabledMessage();
      return;
    }
    final locationGranted = await _devicePermissionBootstrap.isLocationGranted();
    if (!locationGranted) {
      _showPermissionSettingsMessage(missing: 'la ubicacion');
      return;
    }
    if (!mounted) {
      return;
    }

    final qrData = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScanPage(title: 'Escanear QR para fichar'),
      ),
    );

    if (!mounted || qrData == null) {
      return;
    }

    final cleanQrData = qrData.trim();
    if (cleanQrData.isEmpty) {
      _showMessage('QR invalido.', isError: true);
      return;
    }
    shouldRecordMetrics = true;
    eventAt = DateTime.now();

    setState(() {
      _submitting = true;
      _lastQrData = cleanQrData;
    });

    String? foto;
    String? fotoPath;
    double? lat;
    double? lon;
    var queuedOffline = false;

    try {
      if (effectiveConfig.requiereFoto) {
        final photoWatch = Stopwatch()..start();
        fotoPath = await _capturePhotoToCache();
        photoWatch.stop();
        photoDuration = photoWatch.elapsed;
        if (fotoPath != null) {
          foto = await _clockPhotoCache.readAsBase64(fotoPath);
        }
        if (foto == null || foto.isEmpty) {
          throw ApiException(message: 'La empresa requiere foto para fichar.');
        }
      }

      final gpsWatch = Stopwatch()..start();
      final gps = await _captureGps();
      gpsWatch.stop();
      gpsDuration = gpsWatch.elapsed;
      if (gps == null) {
        throw ApiException(
          message: 'Debes habilitar la ubicacion para fichar por QR.',
        );
      }
      setState(() {
        _lastGps = gps;
      });
      lat = gps.lat;
      lon = gps.lon;

      final apiWatch = Stopwatch()..start();
      apiRequestStarted = true;
      final response = await widget.apiClient.registrarScanQr(
        token: widget.token,
        qrToken: cleanQrData,
        foto: foto,
        lat: lat,
        lon: lon,
        eventAt: eventAt,
      );
      apiWatch.stop();
      apiDuration = apiWatch.elapsed;

      if (!mounted) {
        return;
      }

      final accion = (response.accion ?? 'movimiento').trim();
      final estado = response.estado ?? '-';
      flowWatch.stop();
      _recordClockMetrics(
        total: flowWatch.elapsed,
        api: apiDuration,
        gps: gpsDuration,
        photo: photoDuration,
        success: true,
      );
      _showMessage(
        'Fichada de $accion registrada. ID: ${response.id}. Estado: $estado. '
        'Tiempo total: ${_fmtDuration(flowWatch.elapsed)}.',
      );
      await _syncPendingClocks(silent: true);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      flowWatch.stop();
      if (shouldRecordMetrics) {
        _recordClockMetrics(
          total: flowWatch.elapsed,
          api: apiDuration,
          gps: gpsDuration,
          photo: photoDuration,
          success: false,
          errorCode: e.code,
        );
      }
      if (e.code == 'scan_cooldown') {
        _showCooldownMessage(e);
      } else if (e.alertaFraude == true) {
        _showFraudMessage(e);
      } else if (apiRequestStarted && _isConnectivityError(e)) {
        final queued = await _enqueueOfflineClock(
          qrToken: cleanQrData,
          eventAt: eventAt,
          lat: lat,
          lon: lon,
          fotoPath: fotoPath,
        );
        queuedOffline = queued;
        if (queued) {
          _showMessage(
            'Sin internet: fichada guardada como pendiente de sincronizacion.',
            tone: ClockFeedbackTone.offlineQueued,
          );
        } else {
          _showMessage(
            'Sin internet y no se pudo guardar la fichada pendiente. Reintenta.',
            isError: true,
          );
        }
      } else {
        _showMessage(e.message, isError: true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      flowWatch.stop();
      if (shouldRecordMetrics) {
        _recordClockMetrics(
          total: flowWatch.elapsed,
          api: apiDuration,
          gps: gpsDuration,
          photo: photoDuration,
          success: false,
        );
      }
      _showMessage('Error inesperado al registrar la fichada.', isError: true);
    } finally {
      if (!queuedOffline && (fotoPath ?? '').trim().isNotEmpty) {
        await _clockPhotoCache.deleteFile(fotoPath);
      }
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  bool _isConnectivityError(ApiException error) {
    return error.statusCode == null;
  }

  Future<bool> _enqueueOfflineClock({
    required String qrToken,
    required DateTime eventAt,
    double? lat,
    double? lon,
    String? fotoPath,
  }) async {
    try {
      await _offlineClockQueue.enqueue(
        employeeId: widget.empleado.id,
        qrToken: qrToken,
        eventAt: eventAt,
        lat: lat,
        lon: lon,
        fotoPath: fotoPath,
      );
      await _refreshPendingCount();
      await _cleanupCachedClockPhotos();
      return true;
    } catch (e) {
      debugPrint('[offline-queue] enqueue failed: $e');
      return false;
    }
  }

  Future<void> _refreshPendingCount() async {
    final records = await _offlineClockQueue.readForEmployee(
      widget.empleado.id,
    );
    var failed = 0;
    for (final record in records) {
      if (record.status == OfflineClockStatus.failed) {
        failed += 1;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingRecords = records;
      _pendingCount = records.length;
      _pendingFailedCount = failed;
    });
  }

  Future<String?> _syncPendingClocks({bool silent = false}) async {
    if (_syncingPending) {
      return null;
    }
    final pending = await _offlineClockQueue.readForEmployee(
      widget.empleado.id,
    );
    if (pending.isEmpty) {
      if (!silent && mounted) {
        setState(() {
          _pendingSyncMessage = 'No hay fichadas pendientes.';
        });
      }
      await _refreshPendingCount();
      return silent ? null : 'No hay fichadas pendientes.';
    }

    if (mounted) {
      setState(() {
        _syncingPending = true;
        if (!silent) {
          _pendingSyncMessage = null;
        }
      });
    }

    final remaining = <OfflineClockRecord>[];
    var synced = 0;
    var failed = 0;
    var stoppedByConnectivity = false;

    for (var i = 0; i < pending.length; i++) {
      final record = pending[i];
      final shouldAttempt =
          !silent || record.status == OfflineClockStatus.pending;
      if (!shouldAttempt) {
        remaining.add(record);
        continue;
      }
      final attempted = record.copyWith(
        attempts: record.attempts + 1,
        lastAttemptAt: DateTime.now(),
        lastError: null,
        status: OfflineClockStatus.pending,
      );
      try {
        final foto = await _resolveRecordPhoto(attempted);
        if (attempted.hasPhotoReference && (foto ?? '').trim().isEmpty) {
          failed += 1;
          remaining.add(
            attempted.copyWith(
              status: OfflineClockStatus.failed,
              lastError:
                  'No se encontro la foto local para esta fichada pendiente.',
            ),
          );
          continue;
        }
        await widget.apiClient.registrarScanQr(
          token: widget.token,
          qrToken: attempted.qrToken,
          lat: attempted.lat,
          lon: attempted.lon,
          foto: foto,
          eventAt: attempted.eventAt,
        );
        await _clockPhotoCache.deleteFile(attempted.fotoPath);
        synced += 1;
      } on ApiException catch (e) {
        if (_isConnectivityError(e)) {
          stoppedByConnectivity = true;
          remaining.add(
            attempted.copyWith(
              status: OfflineClockStatus.pending,
              lastError: 'Sin conexion al sincronizar.',
            ),
          );
          if (i + 1 < pending.length) {
            remaining.addAll(pending.sublist(i + 1));
          }
          break;
        }
        failed += 1;
        remaining.add(
          attempted.copyWith(
            status: OfflineClockStatus.failed,
            lastError: e.message,
          ),
        );
      } catch (_) {
        stoppedByConnectivity = true;
        remaining.add(
          attempted.copyWith(
            status: OfflineClockStatus.pending,
            lastError: 'Error de conexion al sincronizar.',
          ),
        );
        if (i + 1 < pending.length) {
          remaining.addAll(pending.sublist(i + 1));
        }
        break;
      }
    }

    try {
      await _offlineClockQueue.saveForEmployee(
        employeeId: widget.empleado.id,
        records: remaining,
      );
      await _refreshPendingCount();
      await _cleanupCachedClockPhotos(keepRecords: remaining);
    } catch (e) {
      debugPrint('[offline-queue] sync save failed: $e');
      if (mounted) {
        setState(() {
          _syncingPending = false;
          if (!silent) {
            _pendingSyncMessage =
                'No se pudo actualizar la cola local de pendientes.';
          }
        });
      }
      return 'No se pudo actualizar la cola local de pendientes.';
    }

    if (!mounted) {
      return null;
    }
    final message = stoppedByConnectivity
        ? 'Sincronizadas $synced. Restantes: ${remaining.length}.'
        : failed > 0
        ? 'Sincronizadas $synced. Con error: $failed.'
        : 'Sincronizadas $synced. Cola al dia.';
    setState(() {
      _syncingPending = false;
      _lastPendingSyncAt = DateTime.now();
      if (!silent || stoppedByConnectivity || failed > 0) {
        _pendingSyncMessage = message;
      }
    });
    return message;
  }

  Future<void> _deletePendingRecord(String recordId) async {
    String? photoPathToDelete;
    for (final item in _pendingRecords) {
      if (item.id == recordId) {
        photoPathToDelete = item.fotoPath;
        break;
      }
    }
    try {
      await _offlineClockQueue.removeForEmployee(
        employeeId: widget.empleado.id,
        recordId: recordId,
      );
      await _clockPhotoCache.deleteFile(photoPathToDelete);
      await _refreshPendingCount();
      await _cleanupCachedClockPhotos();
    } catch (e) {
      debugPrint('[offline-queue] delete pending failed: $e');
      _showMessage(
        'No se pudo eliminar el pendiente local. Reintenta.',
        isError: true,
      );
    }
  }

  Future<bool> _upsertPendingRecord(OfflineClockRecord updated) async {
    try {
      final items = await _offlineClockQueue.readForEmployee(widget.empleado.id);
      var replaced = false;
      final next = items
          .map((item) {
            if (item.id == updated.id) {
              replaced = true;
              return updated;
            }
            return item;
          })
          .toList(growable: true);
      if (!replaced) {
        next.add(updated);
      }
      await _offlineClockQueue.saveForEmployee(
        employeeId: widget.empleado.id,
        records: next,
      );
      await _cleanupCachedClockPhotos(keepRecords: next);
      return true;
    } catch (e) {
      debugPrint('[offline-queue] upsert failed: $e');
      return false;
    }
  }

  Future<String> _retryPendingRecord(OfflineClockRecord record) async {
    if (_syncingPending) {
      return 'Ya hay una sincronizacion en curso.';
    }
    if (mounted) {
      setState(() {
        _syncingPending = true;
      });
    }

    final attempted = record.copyWith(
      attempts: record.attempts + 1,
      lastAttemptAt: DateTime.now(),
      lastError: null,
      status: OfflineClockStatus.pending,
    );

    try {
      final foto = await _resolveRecordPhoto(attempted);
      if (attempted.hasPhotoReference && (foto ?? '').trim().isEmpty) {
        final updated = attempted.copyWith(
          status: OfflineClockStatus.failed,
          lastError: 'No se encontro la foto local para este item.',
        );
        final saved = await _upsertPendingRecord(updated);
        if (!saved) {
          if (mounted) {
            setState(() {
              _pendingSyncMessage =
                  'No se pudo guardar el estado local del item pendiente.';
            });
          }
          return 'No se pudo guardar el estado local del item pendiente.';
        }
        await _refreshPendingCount();
        if (mounted) {
          setState(() {
            _pendingSyncMessage = 'No se encontro la foto local del item.';
          });
        }
        return 'No se encontro la foto local del item.';
      }
      await widget.apiClient.registrarScanQr(
        token: widget.token,
        qrToken: attempted.qrToken,
        lat: attempted.lat,
        lon: attempted.lon,
        foto: foto,
        eventAt: attempted.eventAt,
      );
      await _offlineClockQueue.removeForEmployee(
        employeeId: widget.empleado.id,
        recordId: attempted.id,
      );
      await _clockPhotoCache.deleteFile(attempted.fotoPath);
      await _refreshPendingCount();
      await _cleanupCachedClockPhotos();
      if (mounted) {
        setState(() {
          _lastPendingSyncAt = DateTime.now();
          _pendingSyncMessage = 'Fichada sincronizada correctamente.';
        });
      }
      return 'Fichada sincronizada correctamente.';
    } on ApiException catch (e) {
      final isConnectivity = _isConnectivityError(e);
      final updated = attempted.copyWith(
        status: isConnectivity
            ? OfflineClockStatus.pending
            : OfflineClockStatus.failed,
        lastError: isConnectivity
            ? 'Sin conexion al sincronizar este item.'
            : e.message,
      );
      final saved = await _upsertPendingRecord(updated);
      if (!saved) {
        if (mounted) {
          setState(() {
            _pendingSyncMessage =
                'No se pudo guardar el estado local del item pendiente.';
          });
        }
        return 'No se pudo guardar el estado local del item pendiente.';
      }
      await _refreshPendingCount();
      if (mounted) {
        setState(() {
          _pendingSyncMessage = isConnectivity
              ? 'Sin internet. El item sigue pendiente.'
              : 'El item sigue con error de validacion.';
        });
      }
      return isConnectivity
          ? 'Sin internet. El item sigue pendiente.'
          : 'El item sigue con error de validacion.';
    } catch (_) {
      final updated = attempted.copyWith(
        status: OfflineClockStatus.pending,
        lastError: 'Error de conexion al sincronizar este item.',
      );
      final saved = await _upsertPendingRecord(updated);
      if (!saved) {
        if (mounted) {
          setState(() {
            _pendingSyncMessage =
                'No se pudo guardar el estado local del item pendiente.';
          });
        }
        return 'No se pudo guardar el estado local del item pendiente.';
      }
      await _refreshPendingCount();
      if (mounted) {
        setState(() {
          _pendingSyncMessage = 'Sin internet. El item sigue pendiente.';
        });
      }
      return 'Sin internet. El item sigue pendiente.';
    } finally {
      if (mounted) {
        setState(() {
          _syncingPending = false;
        });
      }
    }
  }

  Future<void> _clearPendingRecords() async {
    try {
      for (final record in _pendingRecords) {
        await _clockPhotoCache.deleteFile(record.fotoPath);
      }
      await _offlineClockQueue.clearForEmployee(widget.empleado.id);
      await _refreshPendingCount();
      await _cleanupCachedClockPhotos(
        keepRecords: const <OfflineClockRecord>[],
      );
    } catch (e) {
      debugPrint('[offline-queue] clear failed: $e');
      _showMessage(
        'No se pudo limpiar la cola local. Reintenta.',
        isError: true,
      );
    }
  }

  Future<void> _openPendingQueueDetails() async {
    await _refreshPendingCount();
    if (!mounted) {
      return;
    }

    final records = ValueNotifier<List<OfflineClockRecord>>(_pendingRecords);
    final busy = ValueNotifier<bool>(false);
    final statusText = ValueNotifier<String?>(null);

    Future<void> reload() async {
      final latest = await _offlineClockQueue.readForEmployee(
        widget.empleado.id,
      );
      records.value = latest;
      await _refreshPendingCount();
    }

    Future<void> runSync() async {
      if (busy.value) {
        return;
      }
      busy.value = true;
      final message = await _syncPendingClocks();
      await reload();
      busy.value = false;
      statusText.value = message;
    }

    Future<void> clearAll(BuildContext sheetContext) async {
      if (busy.value) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: sheetContext,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Limpiar pendientes'),
            content: const Text(
              'Se eliminaran todas las fichadas pendientes y con error.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Limpiar'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }
      busy.value = true;
      await _clearPendingRecords();
      await reload();
      busy.value = false;
      statusText.value = 'Cola limpiada.';
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bandeja de sincronizacion',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fichadas guardadas localmente hasta recuperar internet.',
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<bool>(
                    valueListenable: busy,
                    builder: (_, isBusy, __) {
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isBusy ? null : runSync,
                              icon: isBusy
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync),
                              label: Text(
                                isBusy
                                    ? 'Sincronizando...'
                                    : 'Sincronizar ahora',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isBusy
                                  ? null
                                  : () => clearAll(sheetContext),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Limpiar cola'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: statusText,
                    builder: (_, text, __) {
                      if (text == null || text.trim().isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(text),
                      );
                    },
                  ),
                  Expanded(
                    child: ValueListenableBuilder<List<OfflineClockRecord>>(
                      valueListenable: records,
                      builder: (_, items, __) {
                        if (items.isEmpty) {
                          return const Center(
                            child: Text('No hay fichadas pendientes.'),
                          );
                        }
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final item = items[index];
                            final statusColor =
                                item.status == OfflineClockStatus.failed
                                ? const Color(0xFFFFE0E0)
                                : const Color(0xFFE8EEF7);
                            final statusLabel =
                                item.status == OfflineClockStatus.failed
                                ? 'Error'
                                : 'Pendiente';
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Fecha: ${_fmtDateTime(item.eventAt)}',
                                            style: Theme.of(
                                              sheetContext,
                                            ).textTheme.titleSmall,
                                          ),
                                        ),
                                        Chip(
                                          label: Text(statusLabel),
                                          backgroundColor: statusColor,
                                        ),
                                      ],
                                    ),
                                    Text('Intentos: ${item.attempts}'),
                                    if (item.lastAttemptAt != null)
                                      Text(
                                        'Ultimo intento: ${_fmtDateTime(item.lastAttemptAt!)}',
                                      ),
                                    if ((item.lastError ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Text(
                                        'Ultimo error: ${item.lastError}',
                                        style: TextStyle(
                                          color: Theme.of(
                                            sheetContext,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: busy.value
                                              ? null
                                              : () async {
                                                  busy.value = true;
                                                  final message =
                                                      await _retryPendingRecord(
                                                        item,
                                                      );
                                                  await reload();
                                                  busy.value = false;
                                                  statusText.value = message;
                                                },
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Reintentar'),
                                        ),
                                        const SizedBox(width: 6),
                                        TextButton.icon(
                                          onPressed: busy.value
                                              ? null
                                              : () async {
                                                  await _deletePendingRecord(
                                                    item.id,
                                                  );
                                                  await reload();
                                                },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    records.dispose();
    busy.dispose();
    statusText.dispose();
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      _loadConfig(force: true),
      _loadProfile(force: true),
      _syncPendingClocks(silent: true),
    ]);
    await _refreshPendingCount();
  }

  bool get _isBusy => _submitting || _loadingConfig;

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
    showCenteredSnackBar(
      context,
      text: text,
      isError: isError,
    );
  }

  void _showPermissionSettingsMessage({required String missing}) {
    unawaited(_playFeedback(tone: ClockFeedbackTone.error));
    showCenteredSnackBar(
      context,
      text: 'Debes habilitar $missing en Ajustes para continuar.',
      isError: true,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Ajustes',
        textColor: Colors.white,
        onPressed: () {
          unawaited(_devicePermissionBootstrap.openAppSettings());
        },
      ),
    );
  }

  void _showLocationServiceDisabledMessage() {
    unawaited(_playFeedback(tone: ClockFeedbackTone.error));
    showCenteredSnackBar(
      context,
      text: 'Activa el GPS del telefono para continuar con la fichada.',
      isError: true,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'GPS',
        textColor: Colors.white,
        onPressed: () {
          unawaited(_devicePermissionBootstrap.openLocationSettings());
        },
      ),
    );
  }

  void _showFraudMessage(ApiException error) {
    final eventSuffix = error.eventoId != null
        ? ' Evento #${error.eventoId}.'
        : '';
    unawaited(_playFeedback(tone: ClockFeedbackTone.fraud));
    showCenteredSnackBar(
      context,
      text: '${error.message}$eventSuffix',
      isError: true,
      duration: const Duration(seconds: 8),
      backgroundColor: Colors.red.shade800,
      action: SnackBarAction(
        label: 'Ver eventos',
        textColor: Colors.white,
        onPressed: () {
          _openSecurityEvents();
        },
      ),
    );
  }

  void _showCooldownMessage(ApiException error) {
    final remaining = error.cooldownSegundosRestantes;
    final message = (remaining != null && remaining > 0)
        ? 'Escaneo duplicado. Espera $remaining segundos para volver a fichar.'
        : error.message;
    _showMessage(
      message,
      isError: true,
      tone: ClockFeedbackTone.warning,
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
    final apiMs = api?.inMilliseconds ?? 0;
    final hasApiSample = api != null;
    if (mounted) {
      setState(() {
        _lastClockAt = DateTime.now();
        _lastClockTotalDuration = total;
        _lastClockApiDuration = api;
        _lastClockGpsDuration = gps;
        _lastClockPhotoDuration = photo;
        _clockMeasureCount += 1;
        _clockMeasureTotalMs += total.inMilliseconds;
        if (hasApiSample) {
          _clockMeasureApiMs += apiMs;
          _clockMeasureApiCount += 1;
        }
      });
    }
    debugPrint(
      '[clock-metric] success=$success code=${errorCode ?? "-"} '
      'total_ms=${total.inMilliseconds} api_ms=$apiMs '
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

  String _avgDurationLabel(int totalMs, int count) {
    if (count <= 0) {
      return '-';
    }
    return _fmtDuration(Duration(milliseconds: (totalMs / count).round()));
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
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Bloquear sesion'),
                  subtitle: const Text(
                    'Mantiene la cuenta en este dispositivo.',
                  ),
                  onTap: () => Navigator.of(context).pop('lock'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar sesion en este dispositivo'),
                  subtitle: const Text(
                    'Borra la sesion guardada y pide login completo.',
                  ),
                  onTap: () => Navigator.of(context).pop('logout'),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'lock') {
      await widget.onLockSession();
      return;
    }
    if (action == 'logout') {
      await widget.onLogout();
    }
  }

  String _resolvePhotoUrl({
    String? rawUrl,
    String? dni,
    int? imagenVersion,
  }) {
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
    final fotoUrl = _photoUrlForProfile(_profile);
    final syncText = _syncStatusText();
    final avgTotal = _avgDurationLabel(
      _clockMeasureTotalMs,
      _clockMeasureCount,
    );
    final avgApi = _avgDurationLabel(_clockMeasureApiMs, _clockMeasureApiCount);
    final hasPendingPanel =
        _pendingCount > 0 || _syncingPending || _pendingSyncMessage != null;
    final sessionMessage = widget.sessionManager.statusMessage;
    final sessionText = sessionMessage == null
        ? _sessionStatusText()
        : '${_sessionStatusText()} | $sessionMessage';
    final sessionColor = _sessionStatusColor();
    final sessionForeground =
        ThemeData.estimateBrightnessForColor(sessionColor) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1B2838);
    final gpsText = _lastGps == null
        ? 'Sin GPS reciente'
        : '${_lastGps!.lat.toStringAsFixed(5)}, ${_lastGps!.lon.toStringAsFixed(5)}';
    final pendingClean = _pendingCount - _pendingFailedCount;
    final lastSyncText = _lastPendingSyncAt == null
        ? 'Sin sincronizar'
        : _fmtTimeOfDay(_lastPendingSyncAt!);
    final screenWidth = MediaQuery.of(context).size.width;
    final contentMaxWidth = screenWidth >= 1400
        ? 1180.0
        : screenWidth >= 1024
        ? 960.0
        : screenWidth >= 760
        ? 720.0
        : 460.0;
    final horizontalPadding = screenWidth < 600 ? 12.0 : 20.0;
    final quickActionColumns = screenWidth >= 1100
        ? 4
        : screenWidth >= 760
        ? 3
        : screenWidth >= 520
        ? 2
        : 1;
    final quickActionRatio = quickActionColumns == 1
        ? 4.0
        : quickActionColumns == 2
        ? 2.45
        : 2.1;
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
            onPressed: _submitting ? null : _openSecurityEvents,
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Eventos de seguridad',
          ),
          IconButton(
            onPressed: _submitting ? null : _openBiometricSettings,
            icon: const Icon(Icons.fingerprint),
            tooltip: 'Configuracion de huella',
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
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                24,
              ),
              children: [
                if (_loadingConfig || _loadingProfile)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0D3B66),
                        Color(0xFF1B5C8A),
                        Color(0xFF2A789E),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EmployeePhotoWidget(
                              photoUrl: fotoUrl,
                              token: widget.token,
                              radius: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    empleado.nombreCompleto,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'DNI: ${empleado.dni}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  if (empleado.empresaId != null)
                                    Text(
                                      'Empresa: ${empleado.empresaId}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DashboardStatusPill(
                              icon: Icons.sync_outlined,
                              text:
                                  syncText ??
                                  'Sincronizando datos iniciales...',
                              background: const Color(0x26FFFFFF),
                              foreground: Colors.white,
                            ),
                            _DashboardStatusPill(
                              icon: Icons.shield_moon_outlined,
                              text: sessionText,
                              background: sessionColor.withAlpha(225),
                              foreground: sessionForeground,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 10.0;
                    final cardsPerRow = constraints.maxWidth >= 640
                        ? 3
                        : constraints.maxWidth >= 380
                        ? 2
                        : 1;
                    final cardWidth = cardsPerRow == 1
                        ? constraints.maxWidth
                        : (constraints.maxWidth -
                                      (spacing * (cardsPerRow - 1))) /
                                  cardsPerRow;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _DashboardStatCard(
                            title: 'Pendientes',
                            value: '$_pendingCount',
                            icon: Icons.cloud_upload_outlined,
                            accent: const Color(0xFF2A789E),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _DashboardStatCard(
                            title: 'Con error',
                            value: '$_pendingFailedCount',
                            icon: Icons.warning_amber_rounded,
                            accent: const Color(0xFFC85F0F),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _DashboardStatCard(
                            title: 'Ultima sync',
                            value: _lastPendingSyncAt == null
                                ? '-'
                                : _fmtTimeOfDay(_lastPendingSyncAt!),
                            icon: Icons.schedule,
                            accent: const Color(0xFF3D4F6B),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marcacion rapida',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Escanea el QR y registramos ingreso/egreso automaticamente.',
                        ),
                        const SizedBox(height: 12),
                        _PhysicalClockButton(
                          label: 'Escanear QR y fichar',
                          icon: Icons.qr_code_scanner_rounded,
                          color: const Color(0xFF0E5A8A),
                          enabled: !_isBusy,
                          loading: _submitting,
                          onPressed: _fichar,
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 430;
                            if (stacked) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: (_isBusy || _locatingGps)
                                        ? null
                                        : _captureAndShowGps,
                                    icon: _locatingGps
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.my_location_outlined),
                                    label: Text(
                                      _locatingGps
                                          ? 'Obteniendo GPS...'
                                          : 'Actualizar GPS',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: (_syncingPending || _submitting)
                                        ? null
                                        : _openPendingQueueDetails,
                                    icon: const Icon(Icons.inbox_outlined),
                                    label: const Text('Bandeja offline'),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: (_isBusy || _locatingGps)
                                        ? null
                                        : _captureAndShowGps,
                                    icon: _locatingGps
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.my_location_outlined),
                                    label: Text(
                                      _locatingGps
                                          ? 'Obteniendo GPS...'
                                          : 'Actualizar GPS',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: (_syncingPending || _submitting)
                                        ? null
                                        : _openPendingQueueDetails,
                                    icon: const Icon(Icons.inbox_outlined),
                                    label: const Text('Bandeja offline'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'GPS: $gpsText',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_lastQrData != null)
                          Text(
                            'Ultimo QR: ${_shortQr(_lastQrData!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accesos rapidos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        GridView.count(
                          crossAxisCount: quickActionColumns,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: quickActionRatio,
                          children: [
                            _DashboardQuickActionTile(
                              icon: Icons.person_outline,
                              label: 'Mi perfil',
                              enabled: !_submitting,
                              onTap: _openProfile,
                            ),
                            _DashboardQuickActionTile(
                              icon: Icons.calendar_month_outlined,
                              label: 'Asistencias',
                              enabled: !_submitting,
                              onTap: _openAttendanceHistory,
                            ),
                            _DashboardQuickActionTile(
                              icon: Icons.timeline_outlined,
                              label: 'Marcas',
                              enabled: !_submitting,
                              onTap: _openMarksHistory,
                            ),
                            _DashboardQuickActionTile(
                              icon: Icons.insights_outlined,
                              label: 'Estadisticas',
                              enabled: !_submitting,
                              onTap: _openStats,
                            ),
                            _DashboardQuickActionTile(
                              icon: Icons.shield_outlined,
                              label: 'Seguridad',
                              enabled: !_submitting,
                              onTap: _openSecurityEvents,
                            ),
                            _DashboardQuickActionTile(
                              icon: Icons.sync_alt_outlined,
                              label: _syncingPending
                                  ? 'Sincronizando...'
                                  : 'Sincronizar cola',
                              enabled: !_submitting && !_syncingPending,
                              onTap: () async {
                                await _syncPendingClocks();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasPendingPanel) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFFFF7E8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.wifi_off_outlined),
                              const SizedBox(width: 8),
                              Text(
                                _pendingCount > 0
                                    ? 'Operacion offline activa'
                                    : 'Cola offline vacia',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pendientes: $pendingClean | Con error: $_pendingFailedCount',
                          ),
                          Text('Ultima sincronizacion: $lastSyncText'),
                          const SizedBox(height: 4),
                          const Text(
                            'Si no hay internet, guardamos la fichada y luego sincronizamos.',
                          ),
                          if (_pendingSyncMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(_pendingSyncMessage!),
                          ],
                          if (_syncingPending) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(minHeight: 3),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if (_config != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _ruleChip(label: 'QR', enabled: _config!.requiereQr),
                          _ruleChip(
                            label: 'FOTO',
                            enabled: _config!.requiereFoto,
                          ),
                          _ruleChip(label: 'GPS', enabled: true),
                          _infoChip(
                            'Cooldown: ${_config!.cooldownScanSegundos}s',
                          ),
                          if (_config!.intervaloMinimoFichadasMinutos != null)
                            _infoChip(
                              'Intervalo minimo: ${_config!.intervaloMinimoFichadasMinutos} min',
                            ),
                          if (_config!.toleranciaGlobal != null)
                            _infoChip(
                              'Tolerancia: ${_config!.toleranciaGlobal} min',
                            ),
                          if (_config!.metodosHabilitados.isNotEmpty)
                            _infoChip(
                              'Metodos: ${_config!.metodosHabilitados.join(', ')}',
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_config != null) const SizedBox(height: 12),
                if (_clockMeasureCount > 0)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rendimiento de fichada',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Muestras: $_clockMeasureCount'
                            '${_lastClockAt != null ? ' | Ultima: ${_fmtTimeOfDay(_lastClockAt!)}' : ''}',
                          ),
                          if (_lastClockTotalDuration != null)
                            Text(
                              'Ultimo total: ${_fmtDuration(_lastClockTotalDuration!)}',
                            ),
                          if (_lastClockApiDuration != null)
                            Text(
                              'Ultima API: ${_fmtDuration(_lastClockApiDuration!)}',
                            ),
                          if (_lastClockGpsDuration != null)
                            Text(
                              'Ultimo GPS: ${_fmtDuration(_lastClockGpsDuration!)}',
                            ),
                          if (_lastClockPhotoDuration != null)
                            Text(
                              'Ultima foto: ${_fmtDuration(_lastClockPhotoDuration!)}',
                            ),
                          const SizedBox(height: 4),
                          Text('Promedio total: $avgTotal'),
                          Text('Promedio API: $avgApi'),
                        ],
                      ),
                    ),
                  ),
                if (_clockMeasureCount > 0) const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Para fichar con QR la ubicacion del dispositivo es obligatoria. '
                      'Si no hay internet, la marca queda en cola offline.',
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

  Widget _ruleChip({required String label, required bool enabled}) {
    return Chip(
      label: Text('$label: ${enabled ? "requerido" : "opcional"}'),
      backgroundColor: enabled
          ? const Color(0xFFE6F4EA)
          : const Color(0xFFF1F3F5),
    );
  }

  Widget _infoChip(String text) {
    return Chip(label: Text(text), backgroundColor: const Color(0xFFE8EEF7));
  }

  String _shortQr(String token) {
    if (token.length <= 38) {
      return token;
    }
    return '${token.substring(0, 22)}...${token.substring(token.length - 12)}';
  }
}

class _DashboardStatusPill extends StatelessWidget {
  const _DashboardStatusPill({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(95)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF4F637A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DashboardQuickActionTile extends StatelessWidget {
  const _DashboardQuickActionTile({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? const Color(0xFF173A57) : const Color(0xFF8090A2);
    return Material(
      color: enabled ? const Color(0xFFF3F8FC) : const Color(0xFFEAF0F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhysicalClockButton extends StatelessWidget {
  const _PhysicalClockButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: Colors.black45,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white24, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(icon, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                loading ? 'Procesando fichada...' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsPoint {
  const _GpsPoint({
    required this.lat,
    required this.lon,
    this.accuracyM,
    this.capturedAt,
  });

  final double lat;
  final double lon;
  final double? accuracyM;
  final DateTime? capturedAt;
}
