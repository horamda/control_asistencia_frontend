import 'dart:async';
import 'dart:js_interop';
import 'package:geolocator/geolocator.dart';
import 'package:web/web.dart' as web;

Future<Position> readBrowserLocation(Duration timeLimit) {
  final result = Completer<Position>();
  // Both the browser and Dart timers use the requested duration. The plugin
  // version previously used microseconds for the browser's millisecond timeout.
  final timer = Timer(timeLimit, () {
    if (!result.isCompleted) {
      result.completeError(TimeoutException('Location timeout'));
    }
  });
  void fail(Object error) {
    timer.cancel();
    if (!result.isCompleted) result.completeError(error);
  }

  try {
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition value) {
        timer.cancel();
        if (result.isCompleted) return;
        try {
          final coords = value.coords;
          result.complete(
            Position(
              latitude: coords.latitude,
              longitude: coords.longitude,
              timestamp: DateTime.fromMillisecondsSinceEpoch(value.timestamp),
              accuracy: coords.accuracy,
              altitude: coords.altitude ?? 0,
              altitudeAccuracy: coords.altitudeAccuracy ?? 0,
              heading: coords.heading ?? 0,
              headingAccuracy: 0,
              speed: coords.speed ?? 0,
              speedAccuracy: 0,
            ),
          );
        } catch (error) {
          fail(error);
        }
      }).toJS,
      ((web.GeolocationPositionError error) {
        fail(switch (error.code) {
          1 => PermissionDeniedException(error.message),
          2 => PositionUpdateException(error.message),
          3 => TimeoutException(error.message),
          _ => StateError('Unknown geolocation error'),
        });
      }).toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: timeLimit.inMilliseconds,
        maximumAge: 0,
      ),
    );
  } catch (error) {
    fail(error);
  }
  return result.future;
}
