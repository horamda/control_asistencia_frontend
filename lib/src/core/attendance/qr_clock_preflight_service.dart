import '../network/mobile_api_client.dart';
import 'clock_readiness_service.dart';

class QrClockPreflightService {
  QrClockPreflightService({
    required ClockReadinessBoolProvider cameraGrantedProvider,
    required ClockReadinessBoolProvider locationGrantedProvider,
    required ClockReadinessBoolProvider locationServiceEnabledProvider,
    DateTime Function()? nowProvider,
    this.snapshotTtl = const Duration(seconds: 30),
  }) : _cameraGrantedProvider = cameraGrantedProvider,
       _locationGrantedProvider = locationGrantedProvider,
       _locationServiceEnabledProvider = locationServiceEnabledProvider,
       _nowProvider = nowProvider ?? DateTime.now;

  final ClockReadinessBoolProvider _cameraGrantedProvider;
  final ClockReadinessBoolProvider _locationGrantedProvider;
  final ClockReadinessBoolProvider _locationServiceEnabledProvider;
  final DateTime Function() _nowProvider;

  /// If the readiness snapshot was checked within this duration, its
  /// permission values are reused instead of querying the OS again.
  final Duration snapshotTtl;

  Future<QrClockPreflightResult> validate({
    required AttendanceConfig? config,
    required ClockReadinessSnapshot current,
  }) async {
    final checkedAt = _nowProvider();
    final snapshotFresh = current.checkedAt != null &&
        checkedAt.difference(current.checkedAt!) < snapshotTtl;

    if (config == null) {
      return QrClockPreflightResult(
        status: QrClockPreflightStatus.missingConfig,
        readiness: current.copyWith(checkedAt: checkedAt),
      );
    }

    if (!config.isMetodoHabilitado('qr')) {
      return QrClockPreflightResult(
        status: QrClockPreflightStatus.qrDisabled,
        readiness: current.copyWith(checkedAt: checkedAt),
      );
    }

    final cameraGranted = (snapshotFresh && current.cameraGranted != null)
        ? current.cameraGranted!
        : await _cameraGrantedProvider();
    if (!cameraGranted) {
      return QrClockPreflightResult(
        status: QrClockPreflightStatus.cameraPermissionDenied,
        readiness: current.copyWith(
          cameraGranted: false,
          checkedAt: checkedAt,
        ),
      );
    }

    final locationServiceEnabled =
        (snapshotFresh && current.locationServiceEnabled != null)
            ? current.locationServiceEnabled!
            : await _locationServiceEnabledProvider();
    if (!locationServiceEnabled) {
      return QrClockPreflightResult(
        status: QrClockPreflightStatus.locationServiceDisabled,
        readiness: current.copyWith(
          cameraGranted: true,
          locationServiceEnabled: false,
          checkedAt: checkedAt,
        ),
      );
    }

    final locationGranted = (snapshotFresh && current.locationGranted != null)
        ? current.locationGranted!
        : await _locationGrantedProvider();
    if (!locationGranted) {
      return QrClockPreflightResult(
        status: QrClockPreflightStatus.locationPermissionDenied,
        readiness: current.copyWith(
          cameraGranted: true,
          locationGranted: false,
          locationServiceEnabled: true,
          checkedAt: checkedAt,
        ),
      );
    }

    return QrClockPreflightResult(
      status: QrClockPreflightStatus.ready,
      readiness: current.copyWith(
        cameraGranted: true,
        locationGranted: true,
        locationServiceEnabled: true,
        checkedAt: checkedAt,
      ),
    );
  }
}

enum QrClockPreflightStatus {
  ready,
  missingConfig,
  qrDisabled,
  cameraPermissionDenied,
  locationServiceDisabled,
  locationPermissionDenied,
}

class QrClockPreflightResult {
  const QrClockPreflightResult({
    required this.status,
    required this.readiness,
  });

  final QrClockPreflightStatus status;
  final ClockReadinessSnapshot readiness;

  bool get canProceed => status == QrClockPreflightStatus.ready;
}
