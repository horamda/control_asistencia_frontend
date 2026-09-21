import 'dart:io';

import 'package:ficharqr/src/presentation/attendance/widgets/skap_evaluations_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _preview = bool.fromEnvironment('SKAP_PREVIEW');
final _rows = <Map<String, dynamic>>[
  {
    'id': 1,
    'rol': 'Chofer',
    'anio': 2026,
    'sucursal_nombre': 'CASA CENTRAL',
    'resumen': {
      'cumplimiento_pct': 96.49,
      'evaluadas': 19,
      'brechas': 2,
      'faltantes': 0,
    },
  },
  {
    'id': 2,
    'rol': 'Operador de equipos y distribución',
    'anio': 2025,
    'sucursal_nombre': 'SUCURSAL DOLORES',
    'resumen': {
      'cumplimiento_pct': null,
      'parcial_pct': 0,
      'brechas': 1,
      'faltantes': 2,
    },
  },
];

void main() {
  setUpAll(() async {
    if (_preview) {
      await (FontLoader('Preview')..addFont(
            File(
              'C:/Windows/Fonts/segoeui.ttf',
            ).readAsBytes().then((b) => ByteData.sublistView(b)),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  for (final width in [360.0, 480.0, 1100.0]) {
    testWidgets('listado responsive $width filtra, abre y actualiza', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int? opened;
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: _preview ? 'Preview' : null,
            scaffoldBackgroundColor: const Color(0xFFF2F5F8),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF123B53),
            ),
          ),
          home: RepaintBoundary(
            key: const Key('list-preview'),
            child: Scaffold(
              appBar: AppBar(title: const Text('Mis evaluaciones')),
              body: SkapEvaluationsList(
                rows: _rows,
                onOpen: (r) => opened = r['id'] as int,
                onRefresh: () async {
                  refreshes++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Resultado incompleto · Parcial: 0.00 %'),
        findsOneWidget,
      );
      if (_preview) {
        await expectLater(
          find.byKey(const Key('list-preview')),
          matchesGoldenFile('../build/skap_list_${width.toInt()}.png'),
        );
      }
      await tester.ensureVisible(find.text('2026'));
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(find.text('Chofer · 2026'), findsOneWidget);
      expect(
        find.text('Operador de equipos y distribución · 2025'),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Ver mi evaluación'));
      await tester.tap(find.text('Ver mi evaluación'));
      expect(opened, 1);
      await tester.ensureVisible(find.text('Actualizar'));
      await tester.tap(find.text('Actualizar'));
      expect(refreshes, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('texto ampliado sin inventar porcentajes ausentes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: SkapEvaluationsList(
            rows: [
              {
                'id': 1,
                'rol': 'Operador de equipos y distribución',
                'anio': 2026,
                'resumen': {},
              },
            ],
            onOpen: (_) {},
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin datos suficientes'), findsOneWidget);
    expect(find.text('0.0%'), findsNothing);
    expect(find.text('Todos los años'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
