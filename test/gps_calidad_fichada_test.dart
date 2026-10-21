import 'dart:convert';
import 'dart:io';

import 'package:ficharqr/src/core/attendance/qr_clock_submission_service.dart';
import 'package:ficharqr/src/core/image/clock_photo_cache.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/offline/offline_clock_queue.dart';
import 'package:ficharqr/src/core/offline/pending_clock_sync_service.dart';
import 'package:ficharqr/src/core/reuniones/notifications_navigation.dart';
import 'package:ficharqr/src/core/reuniones/push_service.dart';
import 'package:ficharqr/src/core/reuniones/reunion_navigation.dart';
import 'package:ficharqr/src/core/reuniones/reunion_reminders.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _gpsKeys = {'gps_precision_m', 'gps_simulada', 'gps_edad_s'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Calidad del GPS (contrato 1.54.0)', () {
    test('solo manda valores dentro de los rangos del servidor', () {
      expect(
        MobileApiClient.gpsQualityPayload(
          precisionM: 12.345,
          simulada: false,
          edadS: 30,
        ),
        {'gps_precision_m': 12.3, 'gps_simulada': false, 'gps_edad_s': 30},
      );
      expect(MobileApiClient.gpsQualityPayload(), isEmpty);
      for (final precision in [-1.0, 100000.5, double.nan, double.infinity]) {
        expect(
          MobileApiClient.gpsQualityPayload(precisionM: precision),
          isEmpty,
        );
      }
      expect(MobileApiClient.gpsQualityPayload(edadS: -1), isEmpty);
      expect(MobileApiClient.gpsQualityPayload(edadS: 604801), isEmpty);
      expect(MobileApiClient.gpsQualityPayload(edadS: 604800), {
        'gps_edad_s': 604800,
      });
    });

    test('la antiguedad se mide contra la hora de la fichada', () {
      final eventAt = DateTime(2026, 10, 20, 8, 0, 0);
      ClockGpsPoint at(DateTime? capturedAt) =>
          ClockGpsPoint(lat: -36.3, lon: -57.6, capturedAt: capturedAt);
      expect(
        gpsAgeSeconds(
          at(eventAt.subtract(const Duration(minutes: 4))),
          eventAt,
        ),
        240,
      );
      expect(
        gpsAgeSeconds(at(eventAt.add(const Duration(seconds: 5))), eventAt),
        0,
      );
      expect(
        gpsAgeSeconds(at(eventAt.add(const Duration(hours: 3))), eventAt),
        isNull,
      );
      expect(gpsAgeSeconds(at(null), eventAt), isNull);
    });
  });

  group('Fichada con calidad del GPS', () {
    late Map<String, String> storage;
    late Directory photos;
    late ClockPhotoCache photoCache;
    late OfflineClockQueue queue;

    setUp(() async {
      storage = <String, String>{};
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        storage,
      );
      photos = await Directory.systemTemp.createTemp('gps-calidad-');
      photoCache = ClockPhotoCache(rootDirectoryProvider: () async => photos);
      queue = OfflineClockQueue();
    });

    tearDown(() async {
      if (await photos.exists()) await photos.delete(recursive: true);
    });

    QrClockSubmissionService service(MobileApiClient api) =>
        QrClockSubmissionService(
          apiClient: api,
          pendingClockSyncService: PendingClockSyncService(
            offlineClockQueue: queue,
            clockPhotoCache: photoCache,
            apiClient: api,
          ),
          clockPhotoCache: photoCache,
        );

    http.Response ok() => http.Response(
      jsonEncode({'id': 1, 'accion': 'ingreso', 'estado': 'ok'}),
      201,
    );

    final eventAt = DateTime(2026, 10, 20, 8, 0, 0);
    final gps = ClockGpsPoint(
      lat: -36.3,
      lon: -57.6,
      accuracyM: 8.04,
      capturedAt: eventAt.subtract(const Duration(seconds: 90)),
      mocked: true,
    );

    test('online: manda precision, simulada y antiguedad', () async {
      final bodies = <Map<String, dynamic>>[];
      final api = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return ok();
        }),
      );
      final result = await service(api).submit(
        employeeId: 7,
        token: 'jwt',
        qrToken: 'qr-1',
        eventAt: eventAt,
        requiresPhoto: false,
        capturePhotoToCache: () async => null,
        captureGps: () async => gps,
      );
      expect(result.status, QrClockSubmissionStatus.success);
      expect(bodies.single['lat'], -36.3);
      expect(bodies.single['gps_precision_m'], 8.0);
      expect(bodies.single['gps_simulada'], true);
      expect(bodies.single['gps_edad_s'], 90);
      api.dispose();
    });

    test('sin datos de calidad: el pedido es el de siempre', () async {
      final bodies = <Map<String, dynamic>>[];
      final api = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return ok();
        }),
      );
      await service(api).submit(
        employeeId: 7,
        token: 'jwt',
        qrToken: 'qr-1',
        eventAt: eventAt,
        requiresPhoto: false,
        capturePhotoToCache: () async => null,
        captureGps: () async => const ClockGpsPoint(lat: -36.3, lon: -57.6),
      );
      expect(bodies.single.keys.toSet().intersection(_gpsKeys), isEmpty);
      expect(bodies.single.keys.toSet(), {
        'fecha',
        'hora',
        'qr_token',
        'lat',
        'lon',
      });
      api.dispose();
    });

    test(
      'sin conexion: la cola guarda la calidad y la manda al sincronizar',
      () async {
        final offline = MobileApiClient(
          baseUrl: 'https://example.com',
          httpClient: MockClient(
            (_) async => throw const SocketException('sin red'),
          ),
        );
        final result = await service(offline).submit(
          employeeId: 7,
          token: 'jwt',
          qrToken: 'qr-2',
          eventAt: eventAt,
          requiresPhoto: false,
          capturePhotoToCache: () async => null,
          captureGps: () async => gps,
        );
        expect(result.status, QrClockSubmissionStatus.offlineQueued);
        final queued = (await queue.readForEmployee(7)).single;
        expect(queued.gpsPrecisionM, 8.04);
        expect(queued.gpsSimulada, true);
        expect(queued.gpsEdadS, 90);
        offline.dispose();

        final bodies = <Map<String, dynamic>>[];
        final online = MobileApiClient(
          baseUrl: 'https://example.com',
          httpClient: MockClient((request) async {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return ok();
          }),
        );
        final sync = await PendingClockSyncService(
          offlineClockQueue: queue,
          clockPhotoCache: photoCache,
          apiClient: online,
        ).syncAll(employeeId: 7, token: 'jwt');
        expect(sync.syncedCount, 1);
        // La antiguedad es la del momento de fichar, no la del envio.
        expect(bodies.single['gps_edad_s'], 90);
        expect(bodies.single['gps_simulada'], true);
        expect(bodies.single['gps_precision_m'], 8.0);
        online.dispose();
      },
    );

    test(
      'registros guardados por versiones anteriores se envian igual',
      () async {
        final record = OfflineClockRecord.fromJson({
          'id': 'viejo',
          'employee_id': 7,
          'qr_token': 'qr-3',
          'event_at': eventAt.toIso8601String(),
          'created_at': eventAt.toIso8601String(),
          'status': 'pending',
          'lat': -36.3,
          'lon': -57.6,
        });
        expect(record.isValid, true);
        expect(record.gpsPrecisionM, isNull);
        expect(record.gpsSimulada, isNull);
        expect(record.gpsEdadS, isNull);
        expect(record.toJson().keys.toSet().intersection(_gpsKeys), isEmpty);
        final roto = OfflineClockRecord.fromJson({
          ...record.toJson(),
          'gps_simulada': 'quizas',
          'gps_edad_s': 'mucho',
        });
        expect(roto.gpsSimulada, isNull);
        expect(roto.gpsEdadS, isNull);

        await queue.saveForEmployee(employeeId: 7, records: [record]);
        final bodies = <Map<String, dynamic>>[];
        final api = MobileApiClient(
          baseUrl: 'https://example.com',
          httpClient: MockClient((request) async {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return ok();
          }),
        );
        final sync = await PendingClockSyncService(
          offlineClockQueue: queue,
          clockPhotoCache: photoCache,
          apiClient: api,
        ).syncAll(employeeId: 7, token: 'jwt');
        expect(sync.syncedCount, 1);
        expect(bodies.single.keys.toSet().intersection(_gpsKeys), isEmpty);
        api.dispose();
      },
    );
  });

  group('Avisos de ingreso sin fichar', () {
    test('la app los reconoce y los muestra como urgentes', () {
      for (final tipo in ['ingreso_pendiente', 'ingreso_equipo']) {
        expect(pushTypes, contains(tipo));
        expect(urgentPushTypes, contains(tipo));
      }
      expect(
        urgentPushTypes,
        containsAll(['salida_pendiente', 'recordatorio']),
      );
    });

    test('al tocar un aviso de fichada se vuelve a la pantalla principal', () {
      for (final tipo in [
        'ingreso_pendiente',
        'ingreso_equipo',
        'salida_pendiente',
      ]) {
        NotificationsNavigation.pending.value = null;
        final home = NotificationsNavigation.home.value;
        ReunionNavigation.fromLocal(
          jsonEncode({
            'owner': 7,
            'data': {'tipo': tipo, 'ruta': '/asistencia'},
          }),
          7,
        );
        expect(NotificationsNavigation.home.value, home + 1, reason: tipo);
        expect(NotificationsNavigation.pending.value, isNull, reason: tipo);
      }
    });

    test('los demas avisos sin destino siguen abriendo la bandeja', () {
      NotificationsNavigation.pending.value = null;
      final home = NotificationsNavigation.home.value;
      ReunionNavigation.fromLocal(
        jsonEncode({
          'owner': 7,
          'data': {'tipo': 'reintegro_recordatorio'},
        }),
        7,
      );
      expect(NotificationsNavigation.pending.value, 0);
      expect(NotificationsNavigation.home.value, home);
      NotificationsNavigation.pending.value = null;

      ReunionNavigation.fromLocal(
        jsonEncode({
          'owner': 7,
          'data': {'tipo': 'justificacion', 'notificacion_id': 12},
        }),
        7,
      );
      expect(NotificationsNavigation.pending.value, 12);
      NotificationsNavigation.pending.value = null;
    });

    test('un aviso de otro empleado no hace nada', () {
      final home = NotificationsNavigation.home.value;
      ReunionNavigation.fromLocal(
        jsonEncode({
          'owner': 8,
          'data': {'tipo': 'ingreso_pendiente'},
        }),
        7,
      );
      expect(NotificationsNavigation.home.value, home);
    });
  });
}
