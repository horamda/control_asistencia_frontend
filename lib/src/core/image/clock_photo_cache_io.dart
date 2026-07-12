import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

final _log = AppLogger.get('ClockPhotoCache');

typedef ClockPhotoCacheDirectoryProvider = Future<Directory> Function();

class ClockPhotoCache {
  ClockPhotoCache({
    Random? random,
    ClockPhotoCacheDirectoryProvider? rootDirectoryProvider,
  }) : _random = random ?? Random(),
       _rootDirectoryProvider =
           rootDirectoryProvider ?? getApplicationSupportDirectory;

  final Random _random;
  final ClockPhotoCacheDirectoryProvider _rootDirectoryProvider;

  Future<String?> saveFromPath({
    required int employeeId,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      return null;
    }
    return saveFromBytes(
      employeeId: employeeId,
      bytes: await source.readAsBytes(),
      sourceName: sourcePath,
    );
  }

  Future<String?> saveFromBytes({
    required int employeeId,
    required List<int> bytes,
    String? sourceName,
  }) async {
    if (bytes.isEmpty) {
      return null;
    }
    final dir = await _employeeCacheDir(employeeId);
    final ext = _extension(sourceName ?? '');
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}$ext';
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<String?> readAsBase64(String? cachedPath) async {
    final cleanPath = (cachedPath ?? '').trim();
    if (cleanPath.isEmpty) {
      return null;
    }

    if (cleanPath.startsWith('base64:')) {
      final payload = cleanPath.substring('base64:'.length).trim();
      return payload.isEmpty ? null : payload;
    }

    if (cleanPath.startsWith('data:')) {
      final commaIndex = cleanPath.indexOf(',');
      if (commaIndex >= 0 && commaIndex < cleanPath.length - 1) {
        final payload = cleanPath.substring(commaIndex + 1).trim();
        return payload.isEmpty ? null : payload;
      }
    }

    try {
      final file = File(cleanPath);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return base64Encode(bytes);
    } catch (e) {
      _log.debug('No se pudo leer foto en base64 [$cleanPath]: $e');
      return null;
    }
  }

  Future<void> deleteFile(String? cachedPath) async {
    final cleanPath = (cachedPath ?? '').trim();
    if (cleanPath.isEmpty ||
        cleanPath.startsWith('base64:') ||
        cleanPath.startsWith('data:')) {
      return;
    }
    try {
      final file = File(cleanPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _log.debug('No se pudo eliminar foto [$cleanPath]: $e');
    }
  }

  Future<void> pruneEmployee({
    required int employeeId,
    required Iterable<String> keepPaths,
  }) async {
    final dir = await _employeeCacheDir(employeeId);
    if (!await dir.exists()) {
      return;
    }
    final keep = keepPaths
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        if (!keep.contains(entity.path)) {
          try {
            await entity.delete();
          } catch (e) {
            _log.debug(
              'No se pudo eliminar foto en prune [${entity.path}]: $e',
            );
          }
        }
      }
    } catch (e, stack) {
      _log.warning(
        'Error al listar directorio de fotos para empleado $employeeId',
        e,
        stack,
      );
    }
  }

  Future<Directory> _employeeCacheDir(int employeeId) async {
    final baseDir = await _rootDirectoryProvider();
    final root = Directory(
      '${baseDir.path}${Platform.pathSeparator}offline_clock_photos',
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    final employeeDir = Directory(
      '${root.path}${Platform.pathSeparator}$employeeId',
    );
    if (!await employeeDir.exists()) {
      await employeeDir.create(recursive: true);
    }
    return employeeDir;
  }

  String _extension(String path) {
    final clean = path.trim();
    final dot = clean.lastIndexOf('.');
    if (dot <= 0 || dot >= clean.length - 1) {
      return '.jpg';
    }
    final ext = clean.substring(dot).toLowerCase();
    if (ext.length > 6 || ext.contains(Platform.pathSeparator)) {
      return '.jpg';
    }
    return ext;
  }
}
