import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../network/mobile_api_client.dart';

abstract class AppRatingStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class _SecureRatingStorage implements AppRatingStorage {
  _SecureRatingStorage(this._s);
  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
}

/// Manages when and whether to show the in-app rating dialog.
///
/// Logic:
/// - Show after [minSessions] launches (tracked per app version).
/// - Never show again for a version once the user rated OR explicitly dismissed
///   [maxDismissals] times.
class AppRatingService {
  AppRatingService({
    required this.apiClient,
    required this.token,
    AppRatingStorage? storage,
    this.minSessions = 3,
    this.maxDismissals = 2,
  }) : _storage =
           storage ??
           _SecureRatingStorage(
             const FlutterSecureStorage(
               aOptions: AndroidOptions(encryptedSharedPreferences: true),
             ),
           );

  final MobileApiClient apiClient;
  final String token;
  final AppRatingStorage _storage;
  final int minSessions;
  final int maxDismissals;

  Future<String> _currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  String _sessionKey(String version) => 'rating_sessions_$version';
  String _ratedKey(String version) => 'rating_rated_$version';
  String _dismissKey(String version) => 'rating_dismissals_$version';

  Future<bool> shouldShowDialog() async {
    final version = await _currentVersion();

    final rated = await _storage.read(_ratedKey(version));
    if (rated == '1') return false;

    final dismissals =
        int.tryParse(await _storage.read(_dismissKey(version)) ?? '0') ?? 0;
    if (dismissals >= maxDismissals) return false;

    final sessions =
        int.tryParse(await _storage.read(_sessionKey(version)) ?? '0') ?? 0;
    final newCount = sessions + 1;
    await _storage.write(_sessionKey(version), newCount.toString());
    return newCount >= minSessions;
  }

  Future<void> markDismissed() async {
    final version = await _currentVersion();
    final dismissals =
        int.tryParse(await _storage.read(_dismissKey(version)) ?? '0') ?? 0;
    await _storage.write(_dismissKey(version), (dismissals + 1).toString());
  }

  /// Sends the rating to the backend and marks as rated locally.
  Future<bool> submitRating({
    required int puntuacion,
    String? comentario,
    String? pantalla,
  }) async {
    final version = await _currentVersion();
    final ok = await apiClient.calificarApp(
      token: token,
      puntuacion: puntuacion,
      comentario: comentario,
      pantalla: pantalla,
      versionApp: version,
    );
    if (ok) {
      await _storage.write(_ratedKey(version), '1');
    }
    return ok;
  }
}
