import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ficharqr/src/core/auth/session_manager.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/permissions/device_permission_bootstrap.dart';
import 'package:ficharqr/src/core/attendance/clock_gps_service.dart';
import 'package:ficharqr/src/core/offline/pending_queue_controller.dart';
import 'package:ficharqr/src/presentation/attendance/camera_permission_page.dart';
import 'package:ficharqr/src/presentation/attendance/gps_location_page.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/pending_queue_sheet.dart';
import 'package:ficharqr/src/presentation/auth/biometric_settings_page.dart';
import 'package:ficharqr/src/presentation/profile/profile_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

class _Permissions extends DevicePermissionBootstrap {
  @override
  Future<bool> isCameraGranted() async => false;
}

class _Api extends MobileApiClient {
  _Api() : super(baseUrl: 'https://example.test');
  @override
  Future<EmployeeProfile> getMe({required String token}) async =>
      EmployeeProfile(
        id: 1,
        nombre: 'María Alejandra',
        apellido: 'Fernández de la Vega',
        legajo: '0000123456789',
        email: 'maria.fernandez@example.test',
        telefono: '+54 11 12345678',
        direccion: 'Avenida Siempre Viva 1234',
      );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 568),
      const Size(740, 320),
      const Size(600, 960),
      const Size(1024, 768),
    ]) {
      for (final page in ['camera', 'gps', 'biometric', 'profile', 'queue']) {
        testWidgets('$page $brightness at $size with large text and keyboard', (
          tester,
        ) async {
          FlutterSecureStorage.setMockInitialValues({});
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final api = _Api();
          final manager = SessionManager(apiClient: api);
          final queue = ValueNotifier(const PendingQueueState());
          final body = switch (page) {
            'camera' => CameraPermissionPage(permissions: _Permissions()),
            'gps' => GpsLocationPage(
              gpsService: ClockGpsService(
                locationServiceEnabledProvider: () async => false,
                locationGrantedProvider: () async => false,
              ),
            ),
            'biometric' => BiometricSettingsPage(sessionManager: manager),
            'profile' => ProfilePage(apiClient: api, token: 'test'),
            _ => Scaffold(
              body: PendingQueueSheet(
                queueState: queue,
                formatDateTime: (date) => '$date',
                onSync: () async {},
                onClearAll: (_) async {},
                onRetry: (_) async {},
                onDelete: (_) async {},
              ),
            ),
          };
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 160),
                ),
                child: child!,
              ),
              home: body,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          final scrolls = find.byType(Scrollable);
          if (scrolls.evaluate().isNotEmpty) {
            await tester.drag(scrolls.first, const Offset(0, -500));
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          manager.dispose();
          api.dispose();
          queue.dispose();
        });
      }
    }
  }
}
