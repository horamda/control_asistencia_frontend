import 'package:ficharqr/src/presentation/attendance/adelantos_page.dart';
import 'package:ficharqr/src/presentation/attendance/historial_adelantos_page.dart';
import 'package:ficharqr/src/presentation/attendance/vacaciones_page.dart';
import 'package:ficharqr/src/presentation/attendance/francos_page.dart';
import 'package:ficharqr/src/presentation/attendance/premios_page.dart';
import 'package:ficharqr/src/presentation/attendance/legajo_page.dart';
import 'package:ficharqr/src/presentation/attendance/marks_history_page.dart';
import 'package:ficharqr/src/presentation/attendance/employee_stats_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

const longText =
    'Registro de prueba con descripcion extensa y detalles para verificar el contenido completo';
final record = <String, dynamic>{
  'id': 1,
  'estado': 'aprobado',
  'periodo': '2026-10',
  'periodo_year': 2026,
  'periodo_month': 10,
  'monto': 1234567.89,
  'fecha': '2026-10-18',
  'fecha_evento': '2026-10-18',
  'fecha_hora': '2026-10-18T08:00:00',
  'motivo': longText,
  'observaciones': longText,
  'descripcion': longText,
  'titulo': longText,
  'tipo_nombre': longText,
  'tipo': 'vacaciones',
  'dias': 5,
  'fecha_desde': '2026-10-01',
  'fecha_hasta': '2026-10-05',
  'observacion': longText,
  'accion': 'ingreso',
  'metodo': 'qr',
  'severidad': 'leve',
  'ranking': 1,
  'concurso': {'id': 1, 'nombre': longText},
  'sector_empleado': {'nombre': longText},
};
final listing = {
  'items': [record],
  'total': 1,
  'page': 1,
  'per_page': 20,
};

void main() {
  for (final vacaciones in [false]) {
    testWidgets('solicitud dialogo horizontal vacaciones=$vacaciones', (
      tester,
    ) async {
      final api = _Api();
      addTearDown(api.dispose);
      await tester.binding.setSurfaceSize(const Size(740, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: vacaciones
              ? VacacionesPage(apiClient: api, token: 'test')
              : AdelantosPage(apiClient: api, token: 'test'),
        ),
      );
      await tester.pumpAndSettle();
      final trigger = find.text(
        vacaciones ? 'Solicitar' : 'Solicitar adelanto',
      );
      await tester.ensureVisible(trigger);
      await tester.pumpAndSettle();
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(320, 640));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
  for (final dark in [false, true]) {
    for (final module in [
      'adelantos',
      'historial_adelantos',
      'vacaciones',
      'francos',
      'premios',
      'legajo',
      'marks_history',
      'employee_stats',
    ]) {
      testWidgets('$module loaded data, scroll and rotation dark=$dark', (
        tester,
      ) async {
        final api = _Api();
        addTearDown(api.dispose);
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final page = switch (module) {
          'adelantos' => AdelantosPage(apiClient: api, token: 'test'),
          'historial_adelantos' => HistorialAdelantosPage(
            apiClient: api,
            token: 'test',
          ),
          'vacaciones' => VacacionesPage(apiClient: api, token: 'test'),
          'francos' => FrancosPage(apiClient: api, token: 'test'),
          'premios' => PremiosPage(apiClient: api, token: 'test'),
          'legajo' => LegajoPage(apiClient: api, token: 'test'),
          'marks_history' => MarksHistoryPage(apiClient: api, token: 'test'),
          'employee_stats' => EmployeeStatsPage(apiClient: api, token: 'test'),
          _ => throw StateError(module),
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Error inesperado'), findsNothing);
        for (final size in [
          const Size(320, 640),
          const Size(740, 360),
          const Size(800, 1024),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scrolls = find.byType(Scrollable);
          for (final element in scrolls.evaluate()) {
            final state = (element as StatefulElement).state as ScrollableState;
            if (state.axisDirection == AxisDirection.down) {
              state.position.jumpTo(0);
            }
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 12 && scrolls.evaluate().isNotEmpty; i++) {
            final vertical = scrolls.evaluate().where(
              (e) =>
                  (e.widget as Scrollable).axisDirection == AxisDirection.down,
            );
            if (vertical.isEmpty) break;
            await tester.drag(
              find.byWidget(vertical.first.widget),
              const Offset(0, -250),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
        if (module == 'legajo') {
          await tester.tap(find.text('Eventos'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.textContaining(longText), findsWidgets);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

class _Api extends MobileApiClient {
  _Api() : super(baseUrl: 'https://test.invalid');
  @override
  Future<Map<String, dynamic>> getVacationWorkflow({
    required String token,
    String path = '/semanas',
    bool team = false,
    Map<String, String>? query,
  }) async => team
      ? {'alcance': 'sin_equipo', 'items': []}
      : {
          'saldo': {
            'semanas_disponibles': 2,
            'dias_disponibles': 14,
            'dias_pendientes': 0,
          },
          'reglas': longText,
          'semanas': [],
          'items': [],
        };
  @override
  Future<AdelantoResumenResponse> getAdelantoResumen({
    required String token,
  }) async => AdelantoResumenResponse.fromJson({
    'periodo': '2026-10',
    'periodo_year': 2026,
    'periodo_month': 10,
    'ya_solicitado': false,
    'ultimo_adelanto': record,
    'total_historial': 1,
  });
  @override
  Future<AdelantosPageResult> getAdelantos({
    required String token,
    int page = 1,
    int per = 20,
    String? estado,
  }) async => AdelantosPageResult.fromJson(listing);
  @override
  Future<VacacionesResumenResponse> getVacacionesResumen({
    required String token,
    int? anio,
  }) async => VacacionesResumenResponse.fromJson({
    'anio': 2026,
    'empleado': {'nombre_completo': longText},
    'vacaciones': {
      'dias_disponibles': 14,
      'dias_disponibles_con_pendientes': 12,
      'dias_corresponden': 21,
      'dias_pendientes': 2,
      'dias_tomados': 7,
    },
  });
  @override
  Future<VacacionesMovimientosResponse> getVacacionesMovimientos({
    required String token,
    int? anio,
  }) async => VacacionesMovimientosResponse.fromJson({
    'anio': 2026,
    'movimientos': [record],
  });
  @override
  Future<FrancosPageResult> getFrancos({
    required String token,
    int page = 1,
    int per = 20,
  }) async => FrancosPageResult.fromJson(listing);
  @override
  Future<LegajoResumenResponse> getLegajoResumen({
    required String token,
    String? periodo,
    String? desde,
    String? hasta,
  }) async => LegajoResumenResponse.fromJson({
    'periodo': {'desde': '2026-10-01', 'hasta': '2026-10-31'},
    'resumen': {
      'historico': {'total': 1, 'vigentes': 1},
      'recientes': [record],
    },
  });
  @override
  Future<List<LegajoHistorialPorTipoItem>> getLegajoHistorialPorTipo({
    required String token,
  }) async => [
    LegajoHistorialPorTipoItem.fromJson({
      'tipo_id': 1,
      'nombre': longText,
      'codigo': 'prueba',
      'total': 1,
      'vigentes': 1,
    }),
  ];
  @override
  Future<LegajoEventosPageResult> getLegajoEventos({
    required String token,
    int page = 1,
    int per = 20,
    int? tipoId,
    String? estado,
    String? severidad,
    String? desde,
    String? hasta,
    String? queryText,
  }) async => LegajoEventosPageResult.fromJson(listing);
  @override
  Future<PremiosResponse> getPremios({
    required String token,
    int? anio,
  }) async => PremiosResponse.fromJson({
    'anio': 2026,
    'sector': {'nombre': longText},
    'resumen': {
      'total_premios': 1,
      'mejor_ranking': 1,
      'primeros_puestos': 1,
      'podios': 1,
    },
    'meses': [
      {
        'mes': 10,
        'nombre': 'Octubre',
        'premios': [record],
      },
    ],
  });
  @override
  Future<MarcasPageResult> getMarcas({
    required String token,
    int page = 1,
    int per = 20,
    String? desde,
    String? hasta,
  }) async => MarcasPageResult.fromJson(listing);
  @override
  Future<EmployeeStatsResponse> getEstadisticas({
    required String token,
    String? desde,
    String? hasta,
  }) async => EmployeeStatsResponse.fromJson({
    'periodo': {'desde': '2026-10-01', 'hasta': '2026-10-31', 'dias': 31},
    'totales': {'registros': 21, 'ok': 18, 'tarde': 2, 'ausente': 1},
    'kpis': {
      'puntualidad_pct': 90,
      'horas_totales': 160,
      'horas_promedio': 8,
      'dias_laborables': 21,
      'dias_con_registro': 20,
      'racha_ok': 5,
    },
    'jornadas': {'completas': 19, 'con_marca': 20, 'incompletas': 1},
  });
}
