import 'qr_clock_submission_service.dart';

typedef ClockReadinessBoolProvider = Future<bool> Function();

class ClockReadinessService {
  ClockReadinessService({
    required ClockReadinessBoolProvider cameraGrantedProvider,
    required ClockReadinessBoolProvider locationGrantedProvider,
    required ClockReadinessBoolProvider locationServiceEnabledProvider,
    DateTime Function()? nowProvider,
  }) : _cameraGrantedProvider = cameraGrantedProvider,
       _locationGrantedProvider = locationGrantedProvider,
       _locationServiceEnabledProvider = locationServiceEnabledProvider,
       _nowProvider = nowProvider ?? DateTime.now;

  final ClockReadinessBoolProvider _cameraGrantedProvider;
  final ClockReadinessBoolProvider _locationGrantedProvider;
  final ClockReadinessBoolProvider _locationServiceEnabledProvider;
  final DateTime Function() _nowProvider;

  Future<ClockReadinessSnapshot> warmUp({
    required ClockReadinessSnapshot current,
    required bool forceGps,
    required bool canCaptureGps,
    required Duration gpsTtl,
    required Future<ClockGpsPoint?> Function() captureGps,
  }) async {
    final cameraGranted = await _cameraGrantedProvider();
    final locationGranted = await _locationGrantedProvider();
    final locationServiceEnabled = locationGranted
        ? await _locationServiceEnabledProvider()
        : false;

    ClockGpsPoint? warmedGps = current.gps;
    if (canCaptureGps &&
        locationGranted &&
        locationServiceEnabled &&
        (forceGps || !current.hasFreshGps(gpsTtl, now: _nowProvider()))) {
      warmedGps = await captureGps() ?? current.gps;
    }

    return current.copyWith(
      warming: false,
      cameraGranted: cameraGranted,
      locationGranted: locationGranted,
      locationServiceEnabled: locationServiceEnabled,
      checkedAt: _nowProvider(),
      gps: warmedGps,
    );
  }
}

class ClockReadinessSnapshot {
  static const Object _notSet = Object();

  const ClockReadinessSnapshot({
    this.warming = false,
    this.cameraGranted,
    this.locationGranted,
    this.locationServiceEnabled,
    this.checkedAt,
    this.gps,
  });

  final bool warming;
  final bool? cameraGranted;
  final bool? locationGranted;
  final bool? locationServiceEnabled;
  final DateTime? checkedAt;
  final ClockGpsPoint? gps;

  bool get cameraReady => cameraGranted == true;
  bool get locationReady => locationGranted == true;
  bool get locationServiceReady => locationServiceEnabled == true;

  bool hasFreshGps(Duration ttl, {DateTime? now}) {
    final capturedAt = gps?.capturedAt;
    if (gps == null || capturedAt == null) {
      return false;
    }
    return (now ?? DateTime.now()).difference(capturedAt) < ttl;
  }

  ClockReadinessSnapshot copyWith({
    bool? warming,
    Object? cameraGranted = _notSet,
    Object? locationGranted = _notSet,
    Object? locationServiceEnabled = _notSet,
    Object? checkedAt = _notSet,
    Object? gps = _notSet,
  }) {
    return ClockReadinessSnapshot(
      warming: warming ?? this.warming,
      cameraGranted: identical(cameraGranted, _notSet)
          ? this.cameraGranted
          : cameraGranted as bool?,
      locationGranted: identical(locationGranted, _notSet)
          ? this.locationGranted
          : locationGranted as bool?,
      locationServiceEnabled: identical(locationServiceEnabled, _notSet)
          ? this.locationServiceEnabled
          : locationServiceEnabled as bool?,
      checkedAt: identical(checkedAt, _notSet)
          ? this.checkedAt
          : checkedAt as DateTime?,
      gps: identical(gps, _notSet) ? this.gps : gps as ClockGpsPoint?,
    );
  }
}
