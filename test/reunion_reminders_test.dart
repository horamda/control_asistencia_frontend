import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/network/reuniones_models.dart';
import 'package:ficharqr/src/core/reuniones/reunion_reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'refresh replaces reminders, preserves other modules, logout rejects stale session',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final pending = <int, Map<String, dynamic>>{
        8: {'id': 8, 'title': 'Otro módulo', 'body': '', 'payload': 'other:8'},
        9: {
          'id': 9,
          'title': 'Anterior',
          'body': '',
          'payload': 'reunion:1:old',
        },
      };
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            final args = call.arguments;
            switch (call.method) {
              case 'initialize':
                return true;
              case 'pendingNotificationRequests':
                return pending.values.toList();
              case 'cancel':
                pending.remove(args['id']);
                return null;
              case 'zonedSchedule':
                pending[args['id']] = {
                  'id': args['id'],
                  'title': args['title'],
                  'body': args['body'],
                  'payload': args['payload'],
                };
                return null;
              case 'requestNotificationsPermission':
                return true;
              default:
                return null;
            }
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final service = ReunionReminders.instance;
      await service.setOwner(100);
      expect(pending.keys, [8]);
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      final item = ReunionOccurrence({
        'reunion_id': 3,
        'fecha': future.toIso8601String().substring(0, 10),
        'nombre': 'Seguridad',
        'estado': 'pendiente',
        'inicio': future.toIso8601String(),
      });
      await service.replace([item], employeeId: 100);
      expect(pending, hasLength(2));
      expect(calls.where((c) => c.method == 'zonedSchedule'), hasLength(1));
      await service.replace([
        ReunionOccurrence({...item.data, 'cancelada': true}),
      ], employeeId: 100);
      expect(pending.keys, [8]);
      await service.replace([item], employeeId: 100);
      await service.setOwner(null);
      await service.replace([item], employeeId: 100);
      expect(pending.keys, [8]);
      await service.setOwner(200);
      await service.replace([item], employeeId: 100);
      expect(pending.keys, [8]);
      await service.replace([item], employeeId: 200);
      expect(pending, hasLength(2));
      await service.setPushActive(true);
      expect(pending.keys, [8]);
      await service.replace([item], employeeId: 200);
      expect(pending.keys, [8]);
      await service.setPushActive(false);
      await service.replace([item], employeeId: 200);
      expect(pending, hasLength(2));
      await service.clear();
      await service.showPush(
        123,
        'Comunicado',
        'Aviso',
        null,
        route: '/comunicados/12',
      );
      expect(
        calls.lastWhere((c) => c.method == 'show').arguments['payload'],
        'comunicado:200:12:push',
      );
    },
  );
}
