import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ficharqr/src/core/reuniones/reunion_navigation.dart';
import 'package:ficharqr/src/core/reuniones/comunicados_navigation.dart';

import 'package:ficharqr/src/app.dart';

void main() {
  testWidgets('Comunicado deep link waits for authentication', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.platformDispatcher.defaultRouteNameTestValue = '/comunicados/12';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    ComunicadosNavigation.pending.value = null;
    await tester.pumpWidget(
      const EmployeeAttendanceApp(entryPage: Scaffold(body: Text('Ingresar'))),
    );
    await tester.pumpAndSettle();
    expect(ComunicadosNavigation.pending.value, 12);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(Navigator.of(tester.element(find.text('Ingresar'))).canPop(), false);
    ComunicadosNavigation.pending.value = null;
  });
  testWidgets('App boots', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      const EmployeeAttendanceApp(
        entryPage: Scaffold(body: Text('Inicio listo')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmployeeAttendanceApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Inicio listo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Meeting deep link waits at the authentication entry without duplicate routes',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.platformDispatcher.defaultRouteNameTestValue = '/reuniones/42';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      ReunionNavigation.pending.value = null;
      await tester.pumpWidget(
        const EmployeeAttendanceApp(
          entryPage: Scaffold(body: Text('Inicio listo')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inicio listo'), findsOneWidget);
      expect(ReunionNavigation.pending.value, 42);
      expect(
        Navigator.of(tester.element(find.text('Inicio listo'))).canPop(),
        false,
      );
      expect(tester.takeException(), isNull);
      ReunionNavigation.pending.value = null;
    },
  );
}
