import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:ficharqr/src/core/permissions/device_permission_bootstrap.dart';
import 'package:ficharqr/src/presentation/widgets/browser_permission_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePermissions extends DevicePermissionBootstrap {
  bool allow = false;
  int cameraCalls = 0;
  int locationCalls = 0;
  Completer<bool>? pendingCamera;
  @override
  Future<bool> isCameraGranted() async => false;
  @override
  Future<bool> isLocationGranted() async => false;
  @override
  Future<bool> requestCameraAccess() async {
    cameraCalls++;
    return pendingCamera == null ? allow : await pendingCamera!.future;
  }

  @override
  Future<bool> requestLocationAccess() async {
    locationCalls++;
    return allow;
  }
}

void main() {
  test(
    'distinguishes blocked location from timeout and unavailable position',
    () {
      expect(
        DevicePermissionBootstrap.describeLocationError(
          const PermissionDeniedException('denied'),
        ),
        contains('GEO_PERMISSION_DENIED'),
      );
      expect(
        DevicePermissionBootstrap.describeLocationError(
          TimeoutException('timeout'),
        ),
        contains('GEO_TIMEOUT'),
      );
      expect(
        DevicePermissionBootstrap.describeLocationError(
          const PositionUpdateException('unavailable'),
        ),
        contains('GEO_UNAVAILABLE'),
      );
    },
  );
  Future<void> open(
    WidgetTester tester,
    FakePermissions permissions, {
    bool camera = true,
    double textScale = 1,
    double keyboardHeight = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ensureBrowserPermissions(
                context,
                permissions,
                camera: camera,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0, keyboard: 0.0),
    (size: const Size(390, 700), scale: 2.0, keyboard: 0.0),
    (size: const Size(740, 320), scale: 1.5, keyboard: 0.0),
    (size: const Size(360, 640), scale: 1.0, keyboard: 260.0),
    (size: const Size(1280, 800), scale: 1.0, keyboard: 0.0),
  ]) {
    testWidgets(
      'responsive dialog ${scenario.size} scale ${scenario.scale} keyboard ${scenario.keyboard}',
      (tester) async {
        await tester.binding.setSurfaceSize(scenario.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await open(
          tester,
          FakePermissions(),
          textScale: scenario.scale,
          keyboardHeight: scenario.keyboard,
        );
        expect(tester.takeException(), isNull);
        final primary = find.widgetWithText(FilledButton, 'Activar cámara');
        expect(primary.hitTestable(), findsOneWidget);
        await tester.tap(primary);
        await tester.pumpAndSettle();
        expect(find.text('Reintentar').hitTestable(), findsOneWidget);
        final help = find.text('¿Necesitás ayuda?');
        await tester.ensureVisible(help);
        await tester.tap(help);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Reintentar').hitTestable(), findsOneWidget);
        expect(find.text('Ahora no').hitTestable(), findsOneWidget);
        expect(
          tester.getBottomRight(find.widgetWithText(TextButton, 'Ahora no')).dy,
          lessThanOrEqualTo(scenario.size.height - scenario.keyboard),
        );
      },
    );
  }

  testWidgets('requests only after tap, denied permissions can be retried', (
    tester,
  ) async {
    final permissions = FakePermissions();
    await open(tester, permissions);
    expect(permissions.cameraCalls, 0);
    await tester.tap(find.text('Activar cámara'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    permissions.allow = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(permissions.locationCalls, 0);
    await tester.tap(find.text('Activar ubicación'));
    await tester.pumpAndSettle();
    expect(find.text('Permisos del navegador'), findsNothing);
    expect(permissions.cameraCalls, 2);
    expect(permissions.locationCalls, 1);
  });

  testWidgets('GPS action does not request camera', (tester) async {
    final permissions = FakePermissions()..allow = true;
    await open(tester, permissions, camera: false);
    await tester.tap(find.text('Activar ubicación'));
    await tester.pumpAndSettle();
    expect(permissions.cameraCalls, 0);
    expect(permissions.locationCalls, 1);
  });

  testWidgets('can close while browser prompt is pending', (tester) async {
    final permissions = FakePermissions()..pendingCamera = Completer<bool>();
    await open(tester, permissions);
    await tester.tap(find.text('Activar cámara'));
    await tester.pump();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    permissions.pendingCamera!.complete(true);
    await tester.pumpAndSettle();
    expect(permissions.locationCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
