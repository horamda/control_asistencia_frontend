import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

/// Logger centralizado de la app.
///
/// Uso:
/// ```dart
/// final _log = AppLogger.get('MiClase');
/// _log.debug('mensaje debug');
/// _log.warning('algo salio mal', error, stackTrace);
/// ```
///
/// En modo debug loguea todo. En release solo warning y error.
class AppLogger {
  AppLogger._(this._name);

  final String _name;

  static AppLogger get(String name) => AppLogger._(name);

  /// Mensajes de bajo nivel: flujo normal, valores internos.
  void debug(String message) {
    if (kReleaseMode) return;
    dev.log(message, name: _name, level: 500);
  }

  /// Eventos relevantes del ciclo de vida: login, sync, bootstrap.
  void info(String message) {
    if (kReleaseMode) return;
    dev.log(message, name: _name, level: 800);
  }

  /// Fallos recuperables: retry, fallback, dato corrupto.
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    dev.log(
      message,
      name: _name,
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Fallos no recuperables o estados inesperados.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    dev.log(
      message,
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
