import 'dart:convert';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/reuniones/push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'inactive config never requests permission; active registers and logout removes token',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      setupFirebaseCoreMocks();
      FlutterSecureStorage.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'FichaYa',
        packageName: 'test',
        version: '1.23.0',
        buildNumber: '31',
        buildSignature: '',
      );
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'pendingNotificationRequests') return [];
          return null;
        },
      );
      final calls = <String>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_messaging'),
        (call) async {
          calls.add(call.method);
          if (call.method == 'Messaging#getNotificationSettings' ||
              call.method == 'Messaging#requestPermission') {
            return {'authorizationStatus': 1};
          }
          if (call.method == 'Messaging#getToken') {
            return {'token': 'device-token-12345678901234567890'};
          }
          return null;
        },
      );
      bool active = false;
      final requests = <http.Request>[];
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({'activo': active, 'registrado': true, 'quitado': true}),
            200,
          );
        }),
      );
      final service = PushService.instance;
      await service.bind(api, 'jwt-one', 7);
      expect(calls, isEmpty);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      active = true;
      await service.refresh();
      expect(service.status.value, 'Notificaciones conectadas');
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      await service.bind(api, 'jwt-two', 8);
      expect(
        requests
            .where((r) => r.method == 'DELETE')
            .last
            .headers['Authorization'],
        'Bearer jwt-one',
      );
      expect(
        requests.where((r) => r.method == 'POST').last.headers['Authorization'],
        'Bearer jwt-two',
      );
      await service.disconnect();
      expect(
        requests
            .where((r) => r.method == 'DELETE')
            .last
            .headers['Authorization'],
        'Bearer jwt-two',
      );
      expect(calls.where((c) => c == 'Messaging#deleteToken'), hasLength(2));
      final count = requests.length;
      await service.refresh();
      expect(requests, hasLength(count));
    },
  );
}
