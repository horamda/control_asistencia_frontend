import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ficharqr/src/app.dart';

void main() {
  testWidgets(
    'App boots',
    (WidgetTester tester) async {
      await tester.pumpWidget(const EmployeeAttendanceApp());

      expect(find.byType(EmployeeAttendanceApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    },
    skip: true,
  );
}
