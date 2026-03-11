import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class DevicePermissionBootstrap {
  DevicePermissionBootstrap({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _cameraPermissionGrantedKey = 'camera_permission_granted_v1';
  static const _locationPermissionGrantedKey = 'location_permission_granted_v1';
  static const _cameraPermissionPromptedKey = 'camera_permission_prompted_v1';
  static const _locationPermissionPromptedKey =
      'location_permission_prompted_v1';

  final FlutterSecureStorage _secureStorage;

  Future<DevicePermissionBootstrapResult> ensureRequestedAfterLogin() async {
    final camera = await _ensureCameraPermission();
    final location = await _ensureLocationPermission();
    return DevicePermissionBootstrapResult(
      cameraGranted: camera.granted,
      locationGranted: location.granted,
      newlyConfigured: camera.newlyConfigured || location.newlyConfigured,
    );
  }

  Future<bool> isCameraGranted() async {
    try {
      final status = await Permission.camera.status;
      final granted = status.isGranted || status.isLimited;
      await _writeBool(_cameraPermissionGrantedKey, granted);
      return granted;
    } catch (_) {
      return await _readBool(_cameraPermissionGrantedKey) == true;
    }
  }

  Future<bool> isLocationGranted() async {
    try {
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      await _writeBool(_locationPermissionGrantedKey, granted);
      return granted;
    } catch (_) {
      return await _readBool(_locationPermissionGrantedKey) == true;
    }
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  Future<_PermissionEnsureResult> _ensureCameraPermission() async {
    if (await isCameraGranted()) {
      await _writeBool(_cameraPermissionPromptedKey, true);
      return const _PermissionEnsureResult(
        granted: true,
        newlyConfigured: false,
      );
    }
    if (await _readBool(_cameraPermissionPromptedKey) == true) {
      return const _PermissionEnsureResult(
        granted: false,
        newlyConfigured: false,
      );
    }
    await _writeBool(_cameraPermissionPromptedKey, true);
    try {
      final status = await Permission.camera.request();
      final granted = status.isGranted || status.isLimited;
      await _writeBool(_cameraPermissionGrantedKey, granted);
      if (!granted) {
        return const _PermissionEnsureResult(
          granted: false,
          newlyConfigured: false,
        );
      }
      return const _PermissionEnsureResult(
        granted: true,
        newlyConfigured: true,
      );
    } catch (_) {
      // Ignore: we only persist when permission is explicitly available.
      return const _PermissionEnsureResult(
        granted: false,
        newlyConfigured: false,
      );
    }
  }

  Future<_PermissionEnsureResult> _ensureLocationPermission() async {
    if (await isLocationGranted()) {
      await _writeBool(_locationPermissionPromptedKey, true);
      return const _PermissionEnsureResult(
        granted: true,
        newlyConfigured: false,
      );
    }
    final promptedOnce = await _readBool(_locationPermissionPromptedKey) == true;
    if (promptedOnce) {
      return const _PermissionEnsureResult(
        granted: false,
        newlyConfigured: false,
      );
    }
    await _writeBool(_locationPermissionPromptedKey, true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (granted) {
        await _writeBool(_locationPermissionGrantedKey, true);
        return const _PermissionEnsureResult(
          granted: true,
          newlyConfigured: true,
        );
      }
      return const _PermissionEnsureResult(
        granted: false,
        newlyConfigured: false,
      );
    } catch (_) {
      // Ignore: if we cannot request now, app will keep normal runtime checks.
      return const _PermissionEnsureResult(
        granted: false,
        newlyConfigured: false,
      );
    }
  }

  Future<bool?> _readBool(String key) async {
    try {
      final raw = await _secureStorage.read(key: key);
      if (raw == null) {
        return null;
      }
      final value = raw.trim().toLowerCase();
      if (value == 'true') {
        return true;
      }
      if (value == 'false') {
        return false;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeBool(String key, bool value) async {
    try {
      await _secureStorage.write(key: key, value: value ? 'true' : 'false');
    } catch (_) {}
  }
}

class DevicePermissionBootstrapResult {
  const DevicePermissionBootstrapResult({
    required this.cameraGranted,
    required this.locationGranted,
    required this.newlyConfigured,
  });

  final bool cameraGranted;
  final bool locationGranted;
  final bool newlyConfigured;
}

class _PermissionEnsureResult {
  const _PermissionEnsureResult({
    required this.granted,
    required this.newlyConfigured,
  });

  final bool granted;
  final bool newlyConfigured;
}
