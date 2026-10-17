import 'package:ficharqr/src/core/permissions/device_permission_bootstrap.dart';
import 'package:ficharqr/src/presentation/attendance/camera_permission_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Permissions extends DevicePermissionBootstrap {
  bool granted = false;
  bool allowRequest = true;
  int settingsOpened = 0;

  @override
  Future<bool> isCameraGranted() async => granted;

  @override
  Future<bool> retryCameraAccess() async => granted = allowRequest;

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }
}

void main() {
  testWidgets('denied camera can be requested explicitly', (tester) async {
    final permissions = _Permissions();
    await tester.pumpWidget(
      MaterialApp(home: CameraPermissionPage(permissions: permissions)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No permitido'), findsOneWidget);
    await tester.tap(find.text('Habilitar cámara'));
    await tester.pumpAndSettle();
    expect(find.text('Permitido'), findsOneWidget);
    expect(find.text('Habilitar cámara'), findsNothing);
  });

  testWidgets('blocked permission opens settings and refreshes on resume', (
    tester,
  ) async {
    final permissions = _Permissions()..allowRequest = false;
    await tester.pumpWidget(
      MaterialApp(home: CameraPermissionPage(permissions: permissions)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Habilitar cámara'));
    await tester.pumpAndSettle();
    expect(find.textContaining('El permiso sigue desactivado'), findsOneWidget);
    await tester.ensureVisible(find.text('Abrir Ajustes'));
    await tester.tap(find.text('Abrir Ajustes'));
    await tester.pumpAndSettle();
    expect(permissions.settingsOpened, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    permissions.granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Permitido'), findsOneWidget);
  });
}
