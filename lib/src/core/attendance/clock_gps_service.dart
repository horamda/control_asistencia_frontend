import 'package:geolocator/geolocator.dart';

import 'qr_clock_submission_service.dart';

typedef ClockGpsBoolProvider = Future<bool> Function();
typedef ClockLastKnownGpsProvider = Future<ClockGpsPoint?> Function();
typedef ClockCurrentGpsProvider = Future<ClockGpsPoint?> Function(
  Duration timeLimit,
);

class ClockGpsService {
  ClockGpsService({
    required ClockGpsBoolProvider locationServiceEnabledProvider,
    required ClockGpsBoolProvider locationGrantedProvider,
    ClockLastKnownGpsProvider? lastKnownGpsProvider,
    ClockCurrentGpsProvider? currentGpsProvider,
    DateTime Function()? nowProvider,
  }) : _locationServiceEnabledProvider = locationServiceEnabledProvider,
       _locationGrantedProvider = locationGrantedProvider,
       _lastKnownGpsProvider = lastKnownGpsProvider ?? _defaultLastKnownGps,
       _currentGpsProvider = currentGpsProvider ?? _defaultCurrentGps,
       _nowProvider = nowProvider ?? DateTime.now;

  final ClockGpsBoolProvider _locationServiceEnabledProvider;
  final ClockGpsBoolProvider _locationGrantedProvider;
  final ClockLastKnownGpsProvider _lastKnownGpsProvider;
  final ClockCurrentGpsProvider _currentGpsProvider;
  final DateTime Function() _nowProvider;

  Future<ClockGpsPoint?> capture({
    ClockGpsPoint? cachedGps,
    required Duration gpsTtl,
    bool forceRefresh = false,
    Duration timeLimit = const Duration(seconds: 7),
  }) async {
    final now = _nowProvider();
    final cachedCapturedAt = cachedGps?.capturedAt;
    if (!forceRefresh &&
        cachedGps != null &&
        cachedCapturedAt != null &&
        now.difference(cachedCapturedAt) < gpsTtl) {
      return cachedGps;
    }

    try {
      final checks = await Future.wait([
        _locationServiceEnabledProvider(),
        _locationGrantedProvider(),
      ]);
      if (!checks[0] || !checks[1]) {
        return null;
      }

      if (!forceRefresh) {
        final lastKnown = await _lastKnownGpsProvider();
        final lastKnownCapturedAt = lastKnown?.capturedAt;
        if (lastKnown != null &&
            lastKnownCapturedAt != null &&
            now.difference(lastKnownCapturedAt) < gpsTtl) {
          return lastKnown;
        }
      }

      return await _currentGpsProvider(timeLimit);
    } catch (_) {
      return null;
    }
  }

  Future<ClockGpsAvailability> readAvailability() async {
    final checkedAt = _nowProvider();
    final checks = await Future.wait([
      _locationServiceEnabledProvider(),
      _locationGrantedProvider(),
    ]);
    return ClockGpsAvailability(
      locationServiceEnabled: checks[0],
      locationGranted: checks[1],
      checkedAt: checkedAt,
    );
  }

  static Future<ClockGpsPoint?> _defaultLastKnownGps() async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) {
      return null;
    }
    return ClockGpsPoint(
      lat: position.latitude,
      lon: position.longitude,
      accuracyM: position.accuracy,
      capturedAt: position.timestamp,
    );
  }

  static Future<ClockGpsPoint?> _defaultCurrentGps(Duration timeLimit) async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: timeLimit,
    );
    return ClockGpsPoint(
      lat: position.latitude,
      lon: position.longitude,
      accuracyM: position.accuracy,
      capturedAt: DateTime.now(),
    );
  }
}

class ClockGpsAvailability {
  const ClockGpsAvailability({
    required this.locationServiceEnabled,
    required this.locationGranted,
    required this.checkedAt,
  });

  final bool locationServiceEnabled;
  final bool locationGranted;
  final DateTime checkedAt;
}
