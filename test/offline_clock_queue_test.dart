import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('OfflineClockQueue', () {
    late Map<String, String> data;

    setUp(() {
      data = <String, String>{};
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        data,
      );
    });

    test('enqueue falla cuando la cola llega al limite', () async {
      final queue = OfflineClockQueue();
      final now = DateTime(2026, 3, 11, 10, 0, 0);

      for (var i = 0; i < 40; i++) {
        await queue.enqueue(
          employeeId: 10,
          qrToken: 'token-$i',
          eventAt: now.add(Duration(minutes: i)),
        );
      }

      await expectLater(
        () => queue.enqueue(
          employeeId: 10,
          qrToken: 'token-40',
          eventAt: now.add(const Duration(minutes: 40)),
        ),
        throwsA(isA<OfflineClockQueueFullException>()),
      );

      final items = await queue.readForEmployee(10);
      expect(items, hasLength(40));
      expect(items.first.qrToken, 'token-0');
      expect(items.last.qrToken, 'token-39');
    });
  });
}
