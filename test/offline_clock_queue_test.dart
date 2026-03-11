import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';

void main() {
  group('OfflineClockRecord', () {
    test('copyWith permite limpiar campos nullable con null explicito', () {
      final now = DateTime(2026, 3, 11, 10, 0, 0);
      final record = OfflineClockRecord(
        id: 'abc',
        employeeId: 10,
        qrToken: 'token',
        eventAt: now,
        createdAt: now,
        lastAttemptAt: now,
        lastError: 'fallo',
        lat: -34.6,
        lon: -58.4,
        foto: 'base64',
        fotoPath: '/tmp/foto.jpg',
      );

      final updated = record.copyWith(
        lastAttemptAt: null,
        lastError: null,
        lat: null,
        lon: null,
        foto: null,
        fotoPath: null,
      );

      expect(updated.lastAttemptAt, isNull);
      expect(updated.lastError, isNull);
      expect(updated.lat, isNull);
      expect(updated.lon, isNull);
      expect(updated.foto, isNull);
      expect(updated.fotoPath, isNull);
    });

    test('compactPhotoPayload elimina foto inline cuando existe fotoPath', () {
      final now = DateTime(2026, 3, 11, 10, 0, 0);
      final record = OfflineClockRecord(
        id: 'abc',
        employeeId: 10,
        qrToken: 'token',
        eventAt: now,
        createdAt: now,
        foto: 'base64',
        fotoPath: '/tmp/foto.jpg',
      );

      final compacted = record.compactPhotoPayload();

      expect(compacted.foto, isNull);
      expect(compacted.fotoPath, '/tmp/foto.jpg');
    });

    test('isValid rechaza registros con datos clave vacios', () {
      final now = DateTime(2026, 3, 11, 10, 0, 0);
      final invalid = OfflineClockRecord(
        id: '',
        employeeId: 0,
        qrToken: '',
        eventAt: now,
        createdAt: now,
      );

      expect(invalid.isValid, isFalse);
    });
  });
}
