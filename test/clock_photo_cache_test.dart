import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/image/clock_photo_cache.dart';

void main() {
  test('ClockPhotoCache guarda fotos bajo el directorio persistente provisto', () async {
    final sourceRoot = await Directory.systemTemp.createTemp(
      'clock-photo-cache-source-',
    );
    final persistentRoot = await Directory.systemTemp.createTemp(
      'clock-photo-cache-persistent-',
    );

    try {
      final sourceFile = File(
        '${sourceRoot.path}${Platform.pathSeparator}photo.jpg',
      );
      await sourceFile.writeAsBytes(const <int>[1, 2, 3, 4]);

      final cache = ClockPhotoCache(
        rootDirectoryProvider: () async => persistentRoot,
      );

      final savedPath = await cache.saveFromPath(
        employeeId: 7,
        sourcePath: sourceFile.path,
      );

      expect(savedPath, isNotNull);
      expect(
        savedPath!,
        startsWith(
          '${persistentRoot.path}${Platform.pathSeparator}offline_clock_photos${Platform.pathSeparator}7',
        ),
      );
      expect(await File(savedPath).exists(), isTrue);
    } finally {
      if (await sourceRoot.exists()) {
        await sourceRoot.delete(recursive: true);
      }
      if (await persistentRoot.exists()) {
        await persistentRoot.delete(recursive: true);
      }
    }
  });
}
