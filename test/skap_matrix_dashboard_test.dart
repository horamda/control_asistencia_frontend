import 'dart:io';

import 'package:ficharqr/src/presentation/attendance/widgets/skap_matrix_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _preview = bool.fromEnvironment('SKAP_PREVIEW');

Map<String, dynamic> _fixture() => {
  'rol': 'Chofer',
  'anio': 2026,
  'sucursal': 'CASA CENTRAL',
  'resumen': {
    'cumplimiento_pct': null,
    'parcial_pct': 88.89,
    'evaluadas': 3,
    'brechas': 1,
    'faltantes': 1,
    'no_aplica': 1,
    'acreditado': 8,
    'esperado': 9,
    'criticas': {'cumplimiento_pct': 66.67, 'evaluadas': 1, 'brechas': 1},
    'bloques': {
      'Seguridad': {'cumplimiento_pct': 66.67, 'brechas': 1},
    },
  },
  'respuestas': [
    {
      'competencia':
          'Control preventivo del vehículo y de los elementos de seguridad',
      'bloque': 'Seguridad',
      'criticidad': 'A',
      'estado': 'evaluado',
      'puntaje': 2,
      'estandar': 3,
    },
    {
      'competencia': 'Procedimiento ante rotura de productos',
      'bloque': 'Calidad',
      'criticidad': 'B',
      'estado': 'evaluado',
      'puntaje': 3,
      'estandar': 3,
    },
    {
      'competencia': 'Gestión de rechazos',
      'bloque': 'Gestión',
      'criticidad': 'B',
      'estado': 'evaluado',
      'puntaje': 4,
      'estandar': 3,
    },
    {
      'competencia': 'Manejo de equipo especial',
      'bloque': 'Seguridad',
      'criticidad': null,
      'estado': 'no_aplica',
      'puntaje': null,
      'estandar': 3,
    },
    {
      'competencia': 'Documentación de entrega',
      'bloque': 'Gestión',
      'criticidad': 'C',
      'estado': 'sin_evaluar',
      'puntaje': null,
      'estandar': 2,
    },
  ],
  'acciones': [
    {
      'accion': 'Repasar la lista de control antes de salir',
      'estado': 'propuesta',
      'progreso': 0,
      'responsable': null,
    },
  ],
};

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  double scale = 1,
  Map<String, dynamic>? data,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: _preview ? 'Preview' : null,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF123B53)),
        scaffoldBackgroundColor: const Color(0xFFF2F5F8),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const Key('preview'),
        child: Scaffold(
          appBar: AppBar(title: const Text('Mi evaluación')),
          body: SkapMatrixDashboard(data: data ?? _fixture()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (_preview) {
      final loader = FontLoader('Preview')
        ..addFont(
          File(
            'C:/Windows/Fonts/segoeui.ttf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  for (final width in [360.0, 480.0, 1100.0]) {
    testWidgets('tarjetas sin overflow a $width px y filtro de brechas', (
      tester,
    ) async {
      await _pump(tester, Size(width, 1100));
      expect(tester.takeException(), isNull);
      if (_preview) {
        await expectLater(
          find.byKey(const Key('preview')),
          matchesGoldenFile('../build/skap_preview_${width.toInt()}.png'),
        );
      }
      await tester.ensureVisible(find.text('A mejorar (1)'));
      await tester.tap(find.text('A mejorar (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Te falta 1 punto para el objetivo.'), findsOneWidget);
      expect(find.text('Crítica · A'), findsOneWidget);
      expect(find.text('Gestión de rechazos'), findsNothing);
      await tester.ensureVisible(
        find.text(
          'Control preventivo del vehículo y de los elementos de seguridad',
        ),
      );
      if (_preview) {
        await expectLater(
          find.byKey(const Key('preview')),
          matchesGoldenFile('../build/skap_cards_${width.toInt()}.png'),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sin evaluar (1)'));
      await tester.tap(find.text('Sin evaluar (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Documentación de entrega'), findsOneWidget);
      expect(find.text('Puntaje: Sin evaluar'), findsOneWidget);
      expect(find.text('Puntaje: 0'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('texto ampliado y acciones de consulta', (tester) async {
    await _pump(tester, const Size(360, 800), scale: 1.8);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.text('Repasar la lista de control antes de salir'),
    );
    await tester.tap(find.text('Repasar la lista de control antes de salir'));
    await tester.pumpAndSettle();
    expect(find.text('Responsable: Sin asignar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un porcentaje fuera de contrato no aparece como logro', (
    tester,
  ) async {
    final data = _fixture();
    data['resumen'] = {
      'cumplimiento_pct': 133.33,
      'bloques': {
        'Gestión': {'cumplimiento_pct': 133.33},
      },
    };
    await _pump(tester, const Size(480, 1100), data: data);
    expect(
      find.textContaining(
        'Resultado por revisar: el servidor informó 133.33 %',
      ),
      findsNWidgets(2),
    );
    expect(find.text('133.3%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
