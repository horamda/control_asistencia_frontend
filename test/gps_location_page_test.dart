import 'package:ficharqr/src/core/attendance/clock_gps_service.dart';
import 'package:ficharqr/src/core/attendance/qr_clock_submission_service.dart';
import 'package:ficharqr/src/presentation/attendance/gps_location_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows real GPS coordinates after loading', (tester) async {
    final gpsService = ClockGpsService(
      locationServiceEnabledProvider: () async => true,
      locationGrantedProvider: () async => true,
      lastKnownGpsProvider: () async => null,
      currentGpsProvider: (_) async => ClockGpsPoint(
        lat: -34.603722,
        lon: -58.381592,
        accuracyM: 12.3,
        capturedAt: DateTime(2026, 6, 16, 10, 15),
      ),
      nowProvider: () => DateTime(2026, 6, 16, 10, 15),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: GpsLocationPage(gpsService: gpsService),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Mi ubicacion GPS'), findsOneWidget);
    expect(find.textContaining('-34.603722, -58.381592'), findsOneWidget);
    expect(find.textContaining('12.3 m'), findsOneWidget);
    expect(find.textContaining('16/06/2026 10:15'), findsOneWidget);
    expect(find.textContaining('GPS: activo'), findsOneWidget);
    expect(find.textContaining('Permiso: concedido'), findsOneWidget);
  });
}
