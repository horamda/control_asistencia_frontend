import '../image/clock_photo_cache.dart';
import '../network/mobile_api_client.dart';
import '../network/reuniones_models.dart';
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
    if (isReunionQr(qrToken)) {
      return QrClockSubmissionResult(
        status: QrClockSubmissionStatus.apiFailure,
        apiError: ApiException(
          message: 'Este QR corresponde a una reunión.',
          statusCode: 400,
        ),
        totalDuration: Duration.zero,
      );
    }
    final flowWatch = Stopwatch()..start();
    Duration? photoDuration;
    Duration? gpsDuration;
    Duration? apiDuration;
    String? foto;
    String? fotoPath;
    ClockGpsPoint? gps;
    var queuedOffline = false;

    // Arrancar GPS inmediatamente — corre en paralelo con la captura de foto.
    final gpsWatch = Stopwatch()..start();
    final gpsFuture = captureGps();

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
      gps = await gpsFuture;
      gpsWatch.stop();
      gpsDuration = gpsWatch.elapsed;
      if (gps == null) {
        throw ApiException(
          message:
              'No se pudo obtener la ubicación GPS. '
              'Verificá que el GPS esté activo y que la app tenga permiso de ubicación.',
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
        gpsPrecisionM: gps.accuracyM,
        gpsSimulada: gps.mocked,
        gpsEdadS: gpsAgeSeconds(gps, eventAt),
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
            gpsPrecisionM: gps.accuracyM,
            gpsSimulada: gps.mocked,
            gpsEdadS: gpsAgeSeconds(gps, eventAt),
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
    this.mocked,
  });

  final double lat;
  final double lon;
  final double? accuracyM;
  final DateTime? capturedAt;

  /// `true` si el sistema marco la posicion como simulada (GPS falso); `null`
  /// si la plataforma no lo informa (web).
  final bool? mocked;
}

/// Segundos que tenia la posicion al momento de la fichada (contrato 1.54.0).
/// Se mide contra la hora de la fichada, no la del envio: una fichada guardada
/// sin conexion conserva su valor. Una diferencia negativa chica (la posicion
/// llego despues del escaneo) cuenta como 0; si es grande (reloj del telefono
/// desfasado) no se informa.
int? gpsAgeSeconds(ClockGpsPoint gps, DateTime eventAt) {
  final capturedAt = gps.capturedAt;
  if (capturedAt == null) return null;
  final seconds = eventAt.difference(capturedAt).inSeconds;
  if (seconds < -120) return null;
  return seconds < 0 ? 0 : seconds;
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
