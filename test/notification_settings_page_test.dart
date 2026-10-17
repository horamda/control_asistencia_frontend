import 'package:ficharqr/src/presentation/attendance/notification_settings_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'notification settings remain accessible across sizes and themes',
    (tester) async {
      for (final brightness in Brightness.values) {
        for (final size in [
          const Size(320, 568),
          const Size(740, 360),
          const Size(800, 1024),
        ]) {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var openedSettings = false;
          const channel = MethodChannel(
            'flutter.baseflow.com/permissions/methods',
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async {
              if (call.method == 'openAppSettings') {
                openedSettings = true;
                return true;
              }
              return 1;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const NotificationSettingsPage(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Permiso de Android: habilitado'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Ajustes de Android'), 150);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ajustes de Android'));
          await tester.pumpAndSettle();
          expect(openedSettings, isTrue);
          await tester.scrollUntilVisible(find.text('Con la app cerrada'), 150);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
