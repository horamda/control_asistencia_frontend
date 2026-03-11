import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'clock_feedback_profile.dart';

enum ClockFeedbackTone { success, offlineQueued, warning, error, fraud }

class ClockFeedbackAudioService {
  ClockFeedbackAudioService({
    AudioPlayer? successPlayer,
    AudioPlayer? offlinePlayer,
    AudioPlayer? warningPlayer,
    AudioPlayer? errorPlayer,
    AudioPlayer? fraudPlayer,
  }) : _successPlayer = successPlayer ?? AudioPlayer(),
       _offlinePlayer = offlinePlayer ?? AudioPlayer(),
       _warningPlayer = warningPlayer ?? AudioPlayer(),
       _errorPlayer = errorPlayer ?? AudioPlayer(),
       _fraudPlayer = fraudPlayer ?? AudioPlayer();

  static const String _successAsset = 'sounds/clock_ok.wav';
  static const String _offlineAsset = 'sounds/clock_offline.wav';
  static const String _warningAsset = 'sounds/clock_warning.wav';
  static const String _errorAsset = 'sounds/clock_error.wav';
  static const String _fraudAsset = 'sounds/clock_fraud.wav';

  final AudioPlayer _successPlayer;
  final AudioPlayer _offlinePlayer;
  final AudioPlayer _warningPlayer;
  final AudioPlayer _errorPlayer;
  final AudioPlayer _fraudPlayer;
  bool _initialized = false;
  ClockFeedbackProfile _profile = ClockFeedbackProfile.balanced;

  ClockFeedbackProfile get profile => _profile;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    try {
      await Future.wait([
        _successPlayer.setReleaseMode(ReleaseMode.stop),
        _offlinePlayer.setReleaseMode(ReleaseMode.stop),
        _warningPlayer.setReleaseMode(ReleaseMode.stop),
        _errorPlayer.setReleaseMode(ReleaseMode.stop),
        _fraudPlayer.setReleaseMode(ReleaseMode.stop),
      ]);
      _initialized = true;
      await setProfile(_profile);
    } catch (_) {
      _initialized = false;
    }
  }

  Future<void> play({
    ClockFeedbackTone tone = ClockFeedbackTone.success,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final player = _playerForTone(tone);
    final assetPath = _assetForTone(tone);
    try {
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (_) {
      await _playSystemFallback(tone);
    }
  }

  Future<void> setProfile(ClockFeedbackProfile profile) async {
    _profile = profile;
    if (!_initialized) {
      return;
    }
    final volumes = _volumesForProfile(profile);
    try {
      await Future.wait([
        _successPlayer.setVolume(volumes[ClockFeedbackTone.success] ?? 1.0),
        _offlinePlayer.setVolume(
          volumes[ClockFeedbackTone.offlineQueued] ?? 1.0,
        ),
        _warningPlayer.setVolume(volumes[ClockFeedbackTone.warning] ?? 1.0),
        _errorPlayer.setVolume(volumes[ClockFeedbackTone.error] ?? 1.0),
        _fraudPlayer.setVolume(volumes[ClockFeedbackTone.fraud] ?? 1.0),
      ]);
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await Future.wait([
        _successPlayer.dispose(),
        _offlinePlayer.dispose(),
        _warningPlayer.dispose(),
        _errorPlayer.dispose(),
        _fraudPlayer.dispose(),
      ]);
    } catch (_) {}
  }

  AudioPlayer _playerForTone(ClockFeedbackTone tone) {
    switch (tone) {
      case ClockFeedbackTone.success:
        return _successPlayer;
      case ClockFeedbackTone.offlineQueued:
        return _offlinePlayer;
      case ClockFeedbackTone.warning:
        return _warningPlayer;
      case ClockFeedbackTone.error:
        return _errorPlayer;
      case ClockFeedbackTone.fraud:
        return _fraudPlayer;
    }
  }

  String _assetForTone(ClockFeedbackTone tone) {
    switch (tone) {
      case ClockFeedbackTone.success:
        return _successAsset;
      case ClockFeedbackTone.offlineQueued:
        return _offlineAsset;
      case ClockFeedbackTone.warning:
        return _warningAsset;
      case ClockFeedbackTone.error:
        return _errorAsset;
      case ClockFeedbackTone.fraud:
        return _fraudAsset;
    }
  }

  bool _isErrorTone(ClockFeedbackTone tone) {
    return tone == ClockFeedbackTone.error ||
        tone == ClockFeedbackTone.warning ||
        tone == ClockFeedbackTone.fraud;
  }

  Future<void> _playSystemFallback(ClockFeedbackTone tone) async {
    try {
      await SystemSound.play(
        _isErrorTone(tone) ? SystemSoundType.alert : SystemSoundType.click,
      );
    } catch (_) {}
  }

  Map<ClockFeedbackTone, double> _volumesForProfile(
    ClockFeedbackProfile profile,
  ) {
    switch (profile) {
      case ClockFeedbackProfile.subtle:
        return const {
          ClockFeedbackTone.success: 0.55,
          ClockFeedbackTone.offlineQueued: 0.48,
          ClockFeedbackTone.warning: 0.58,
          ClockFeedbackTone.error: 0.64,
          ClockFeedbackTone.fraud: 0.70,
        };
      case ClockFeedbackProfile.balanced:
        return const {
          ClockFeedbackTone.success: 0.82,
          ClockFeedbackTone.offlineQueued: 0.72,
          ClockFeedbackTone.warning: 0.86,
          ClockFeedbackTone.error: 0.92,
          ClockFeedbackTone.fraud: 1.0,
        };
      case ClockFeedbackProfile.strong:
        return const {
          ClockFeedbackTone.success: 0.95,
          ClockFeedbackTone.offlineQueued: 0.88,
          ClockFeedbackTone.warning: 0.98,
          ClockFeedbackTone.error: 1.0,
          ClockFeedbackTone.fraud: 1.0,
        };
    }
  }
}
