import '../image/clock_photo_cache.dart';
import '../network/mobile_api_client.dart';
import '../offline/offline_clock_queue.dart';
import '../offline/pending_clock_sync_service.dart';

class QrClockSubmissionService {
  QrClockSubmissionService({
    required MobileApiClient apiClient,
    required PendingClockSyncService pendingClockSyncService,
    required ClockPhotoCache clockPhotoCache,
  }) : _apiClient = apiClient,
       _pendingClockSyncService = pendingClockSyncService,
       _clockPhotoCache = clockPhotoCache;

  final MobileApiClient _apiClient;
  final PendingClockSyncService _pendingClockSyncService;
  final ClockPhotoCache _clockPhotoCache;

  Future<QrClockSubmissionResult> submit({
    required int employeeId,
    required String token,
    required String qrToken,
    required DateTime eventAt,
    required bool requiresPhoto,
    required Future<String?> Function() capturePhotoToCache,
    required Future<ClockGpsPoint?> Function() captureGps,
    void Function(String phase)? onPhase,
  }) async {
    final flowWatch = Stopwatch()..start();
    Duration? photoDuration;
    Duration? gpsDuration;
    Duration? apiDuration;
    String? foto;
    String? fotoPath;
    ClockGpsPoint? gps;
    var queuedOffline = false;

    try {
      if (requiresPhoto) {
        onPhase?.call('Capturando foto...');
        final photoWatch = Stopwatch()..start();
        fotoPath = await capturePhotoToCache();
        photoWatch.stop();
        photoDuration = photoWatch.elapsed;
        if (fotoPath != null) {
          foto = await _clockPhotoCache.readAsBase64(fotoPath);
        }
        if (foto == null || foto.isEmpty) {
          throw ApiException(message: 'La empresa requiere foto para fichar.');
        }
      }

      onPhase?.call('Validando GPS...');
      final gpsWatch = Stopwatch()..start();
      gps = await captureGps();
      gpsWatch.stop();
      gpsDuration = gpsWatch.elapsed;
      if (gps == null) {
        throw ApiException(
          message:
              'No se pudo obtener la ubicacion GPS. '
              'Verifica que el GPS este activo y que la app tenga permiso de ubicacion.',
        );
      }

      onPhase?.call('Enviando fichada...');
      final apiWatch = Stopwatch()..start();
      final response = await _apiClient.registrarScanQr(
        token: token,
        qrToken: qrToken,
        foto: foto,
        lat: gps.lat,
        lon: gps.lon,
        eventAt: eventAt,
      );
      apiWatch.stop();
      apiDuration = apiWatch.elapsed;
      flowWatch.stop();

      return QrClockSubmissionResult(
        status: QrClockSubmissionStatus.success,
        response: response,
        gps: gps,
        totalDuration: flowWatch.elapsed,
        photoDuration: photoDuration,
        gpsDuration: gpsDuration,
        apiDuration: apiDuration,
      );
    } on ApiException catch (error) {
      flowWatch.stop();
      if (error.statusCode == null && gps != null) {
        try {
          onPhase?.call('Guardando fichada offline...');
          final snapshot = await _pendingClockSyncService.enqueue(
            employeeId: employeeId,
            qrToken: qrToken,
            eventAt: eventAt,
            lat: gps.lat,
            lon: gps.lon,
            fotoPath: fotoPath,
          );
          queuedOffline = true;
          return QrClockSubmissionResult(
            status: QrClockSubmissionStatus.offlineQueued,
            apiError: error,
            pendingSnapshot: snapshot,
            gps: gps,
            totalDuration: flowWatch.elapsed,
            photoDuration: photoDuration,
            gpsDuration: gpsDuration,
            apiDuration: apiDuration,
          );
        } on OfflineClockQueueFullException catch (queueError) {
          return QrClockSubmissionResult(
            status: QrClockSubmissionStatus.offlineQueueFull,
            apiError: error,
            queueFullError: queueError,
            gps: gps,
            totalDuration: flowWatch.elapsed,
            photoDuration: photoDuration,
            gpsDuration: gpsDuration,
            apiDuration: apiDuration,
          );
        } catch (_) {
          return QrClockSubmissionResult(
            status: QrClockSubmissionStatus.offlineQueueFailed,
            apiError: error,
            gps: gps,
            totalDuration: flowWatch.elapsed,
            photoDuration: photoDuration,
            gpsDuration: gpsDuration,
            apiDuration: apiDuration,
          );
        }
      }

      return QrClockSubmissionResult(
        status: QrClockSubmissionStatus.apiFailure,
        apiError: error,
        gps: gps,
        totalDuration: flowWatch.elapsed,
        photoDuration: photoDuration,
        gpsDuration: gpsDuration,
        apiDuration: apiDuration,
      );
    } catch (error) {
      flowWatch.stop();
      return QrClockSubmissionResult(
        status: QrClockSubmissionStatus.unexpectedFailure,
        gps: gps,
        totalDuration: flowWatch.elapsed,
        photoDuration: photoDuration,
        gpsDuration: gpsDuration,
        apiDuration: apiDuration,
      );
    } finally {
      if (!queuedOffline && (fotoPath ?? '').trim().isNotEmpty) {
        await _clockPhotoCache.deleteFile(fotoPath);
      }
    }
  }
}

class ClockGpsPoint {
  const ClockGpsPoint({
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

enum QrClockSubmissionStatus {
  success,
  offlineQueued,
  offlineQueueFull,
  offlineQueueFailed,
  apiFailure,
  unexpectedFailure,
}

class QrClockSubmissionResult {
  const QrClockSubmissionResult({
    required this.status,
    required this.totalDuration,
    this.response,
    this.apiError,
    this.queueFullError,
    this.pendingSnapshot,
    this.gps,
    this.photoDuration,
    this.gpsDuration,
    this.apiDuration,
  });

  final QrClockSubmissionStatus status;
  final FichadaResponse? response;
  final ApiException? apiError;
  final OfflineClockQueueFullException? queueFullError;
  final PendingClockSnapshot? pendingSnapshot;
  final ClockGpsPoint? gps;
  final Duration totalDuration;
  final Duration? photoDuration;
  final Duration? gpsDuration;
  final Duration? apiDuration;

  bool get isSuccess => status == QrClockSubmissionStatus.success;
  bool get isOfflineQueued => status == QrClockSubmissionStatus.offlineQueued;
}
