import 'dart:io';

import 'package:ficharqr/src/core/network/feedback_api_models.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/feedback_summary_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _preview = bool.fromEnvironment('FEEDBACK_PREVIEW');

FeedbackDashboardResponse _data({Map<String, dynamic>? summary}) =>
    FeedbackDashboardResponse.fromJson({
      'resumen':
          summary ??
          {
            'total': 70,
            'resueltos': 66,
            'pendientes': 0,
            'en_proceso': 0,
            'vencidos': 4,
            'resueltos_en_sla': 58,
            'resueltos_fuera_sla': 8,
            'clientes_distintos': 23,
            'motivos_distintos': 6,
          },
      'personal': {
        'total_cargados': 3,
        'posicion_ranking': 7,
        'promedio_por_empleado': 2.8,
      },
      'empleado': {'nombre': 'Ana', 'apellido': 'López'},
      'totales': {'empleados_activos': 25, 'empleados_con_carga': 11},
      'top_motivos': [
        {
          'motivo_nombre': 'Demoras en la entrega',
          'total': 14,
          'resueltos': 12,
        },
      ],
    });

Future<void> _pump(
  WidgetTester tester,
  double width,
  FeedbackDashboardResponse data, {
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1300));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: _preview ? 'Preview' : null,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const Key('feedback-preview'),
        child: Scaffold(
          appBar: AppBar(title: const Text('Feedback de calle')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FeedbackSummaryDashboard(dashboard: data),
                FeedbackMotivosChart(
                  items: data.topMotivos,
                  total: data.resumen.total,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
    testWidgets('porcentajes con base explícita y responsive $width', (
      tester,
    ) async {
      await _pump(tester, width, _data());
      expect(find.text('94.3%'), findsOneWidget);
      expect(find.text('87.9 %'), findsOneWidget);
      expect(find.text('58 de 66 cierres con plazo evaluado'), findsOneWidget);
      expect(find.text('4.3 %'), findsOneWidget);
      expect(find.text('44.0 %'), findsOneWidget);
      expect(
        find.text('5.7 % del total · Vencidos sin resolver'),
        findsOneWidget,
      );
      expect(find.text('14 cargas · 20.0 % · 12 resueltos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (_preview) {
        await expectLater(
          find.byKey(const Key('feedback-preview')),
          matchesGoldenFile('../build/feedback_summary_${width.toInt()}.png'),
        );
      }
    });
  }

  testWidgets('sin datos no inventa resolución ni SLA', (tester) async {
    await _pump(tester, 320, _data(summary: {}), scale: 1.8);
    expect(find.text('94.3%'), findsNothing);
    expect(find.text('0.0%'), findsNothing);
    expect(find.text('Sin datos'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('total cero no divide por cero', (tester) async {
    await _pump(
      tester,
      480,
      _data(
        summary: {
          'total': 0,
          'resueltos': 0,
          'resueltos_en_sla': 0,
          'resueltos_fuera_sla': 0,
        },
      ),
    );
    expect(find.text('0 de 0 feedbacks resueltos'), findsOneWidget);
    expect(find.text('0.0%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SLA excluye cierres sin plazo evaluado', (tester) async {
    await _pump(
      tester,
      480,
      _data(
        summary: {
          'total': 10,
          'resueltos': 8,
          'resueltos_en_sla': 3,
          'resueltos_fuera_sla': 1,
        },
      ),
    );
    expect(find.text('75.0 %'), findsOneWidget);
    expect(find.text('3 de 4 cierres con plazo evaluado'), findsOneWidget);
    expect(find.text('80.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
