import 'dart:convert';
import 'dart:io';
import 'dart:math';

class ClockPhotoCache {
  ClockPhotoCache({Random? random}) : _random = random ?? Random();

  final Random _random;

  Future<String?> saveFromPath({
    required int employeeId,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      return null;
    }
    final dir = await _employeeCacheDir(employeeId);
    final ext = _extension(sourcePath);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}$ext';
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    final copied = await source.copy(target.path);
    return copied.path;
  }

  Future<String?> readAsBase64(String? cachedPath) async {
    final cleanPath = (cachedPath ?? '').trim();
    if (cleanPath.isEmpty) {
      return null;
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
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteFile(String? cachedPath) async {
    final cleanPath = (cachedPath ?? '').trim();
    if (cleanPath.isEmpty) {
      return;
    }
    try {
      final file = File(cleanPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
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
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<Directory> _employeeCacheDir(int employeeId) async {
    final root = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}offline_clock_photos',
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
