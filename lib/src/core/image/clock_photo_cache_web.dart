import 'dart:convert';
import 'dart:math';

class ClockPhotoCache {
  ClockPhotoCache({Random? random, Object? rootDirectoryProvider});

  Future<String?> saveFromPath({
    required int employeeId,
    required String sourcePath,
  }) async {
    return null;
  }

  Future<String?> saveFromBytes({
    required int employeeId,
    required List<int> bytes,
    String? sourceName,
  }) async {
    if (bytes.isEmpty) {
      return null;
    }
    final payload = base64Encode(bytes);
    return 'base64:$payload';
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
    return null;
  }

  Future<void> deleteFile(String? cachedPath) async {
    return;
  }

  Future<void> pruneEmployee({
    required int employeeId,
    required Iterable<String> keepPaths,
  }) async {
    return;
  }
}
