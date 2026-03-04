import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:control_asistencia_mobile/src/app.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const EmployeeAttendanceApp());

    expect(find.byType(EmployeeAttendanceApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
