import 'dart:async';
import 'dart:io';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/seguridad_dashboard.dart';
import 'package:ficharqr/src/presentation/attendance/seguridad_page.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/attendance_dashboard_widgets.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('1.33.1 displays days without configured start or record', (
    tester,
  ) async {
    final api = _Api();
    addTearDown(api.dispose);
    final initial = _indicators();
    final own = initial['alcances']['propio'] as Map;
    own['inicio'] = null;
    own['record_dias_sin_accidentes'] = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeguridadIndicators(
              api: api,
              token: 'one',
              today: DateTime(2026, 10, 6),
              initial: initial,
            ),
          ),
        ),
      ),
    );
    expect(find.text('12 días sin accidentes'), findsOneWidget);
    expect(find.text('Récord: no disponible'), findsOneWidget);
    expect(find.text('Inicio del registro: Sin configurar'), findsOneWidget);
    expect(find.text('Último accidente: 2026-09-24'), findsOneWidget);
    await tester.ensureVisible(find.text('Cómo se calcula'));
    await tester.tap(find.text('Cómo se calcula'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('último accidente pendiente o aprobado'),
      findsOneWidget,
    );
    expect(api.paths, isEmpty);
    expect(tester.takeException(), isNull);
  });
  test(
    'missing summary uses indicators and missing both gives actionable message',
    () async {
      final api = _Api()..missingSummary = true;
      final controller = SeguridadDashboardController(api: api, token: 'one');
      await Future<void>.delayed(Duration.zero);
      expect(controller.fallbackIndicators?['hasta'], '2026-10-06');
      expect(api.paths, ['/resumen', '/indicadores']);
      api.missingIndicators = true;
      await controller.refresh();
      expect(controller.fallbackIndicators, isNull);
      expect(controller.errorMessage, contains('Solicitá la actualización'));
      controller.dispose();
      api.dispose();
    },
  );

  test('summary network and server failures still load indicators', () async {
    for (final failure in [
      ApiException(message: 'connection failed'),
      ApiException(message: 'server failed', statusCode: 500),
      const FormatException('invalid summary'),
    ]) {
      final api = _Api()..summaryFailure = failure;
      final controller = SeguridadDashboardController(api: api, token: 'one');
      await Future<void>.delayed(Duration.zero);
      expect(controller.fallbackIndicators?['hasta'], '2026-10-06');
      expect(controller.errorMessage, contains('disponibles'));
      expect(api.paths, ['/resumen', '/indicadores']);
      controller.dispose();
      api.dispose();
    }
  });
  test('authorization failure does not request indicators', () async {
    final api = _Api()
      ..summaryFailure = ApiException(message: 'denied', statusCode: 403);
    final controller = SeguridadDashboardController(api: api, token: 'one');
    await Future<void>.delayed(Duration.zero);
    expect(api.paths, ['/resumen']);
    expect(controller.fallbackIndicators, isNull);
    controller.dispose();
    api.dispose();
  });

  testWidgets('missing config capabilities still exposes API indicators', (
    tester,
  ) async {
    final api = _Api()..capabilities = false;
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SeguridadPage(apiClient: api, token: 'one'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi seguridad'));
    await tester.pumpAndSettle();
    expect(find.text('12 días sin accidentes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'accident-free days and cutoff come from API, not device calculations',
    (tester) async {
      final api = _Api();
      addTearDown(api.dispose);
      final initial = _indicators();
      (initial['alcances']['propio'] as Map)['dias_sin_accidentes'] = 73;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SeguridadIndicators(
                api: api,
                token: 'one',
                today: DateTime(2026, 10, 10),
                initial: initial,
              ),
            ),
          ),
        ),
      );
      expect(find.text('73 días sin accidentes'), findsOneWidget);
      expect(find.text('Último accidente: 2026-09-24'), findsOneWidget);
      expect(find.text('Hasta: 2026-10-06'), findsOneWidget);
      expect(api.paths, isEmpty);
      await tester.tap(find.byTooltip('Actualizar indicadores'));
      await tester.pumpAndSettle();
      expect(api.paths.single, '/indicadores?hasta=2026-10-06');
      expect(find.text('12 días sin accidentes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  const previewFont = String.fromEnvironment('UI_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isEmpty) return;
    await (FontLoader('Preview')..addFont(
          File(
            previewFont,
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test(
    'summary ignores older successes/errors and disposal during a request',
    () async {
      final api = _Api()..holdSummary = true;
      final controller = SeguridadDashboardController(api: api, token: 'one');
      controller.select(2025, 2);
      api.pending[1].complete(_summary(year: 2025));
      await Future<void>.delayed(Duration.zero);
      api.pending[0].completeError(
        ApiException(message: 'old failure', statusCode: 500),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.data!['anio'], 2025);
      expect(controller.error, isNull);
      controller.select(2024, null);
      expect(controller.data, isNull);
      controller.dispose();
      api.pending.last.complete(_summary(year: 2024));
      await Future<void>.delayed(Duration.zero);
      api.dispose();
    },
  );

  for (final size in [
    const Size(320, 740),
    const Size(440, 956),
    const Size(800, 900),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('dashboard and ranking at $size text $scale', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = _Api();
        addTearDown(api.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: previewFont.isEmpty
                ? buildAppTheme()
                : buildAppTheme().copyWith(
                    appBarTheme: buildAppTheme().appBarTheme.copyWith(
                      titleTextStyle: buildAppTheme().appBarTheme.titleTextStyle
                          ?.copyWith(fontFamily: 'Preview'),
                    ),
                    textTheme: buildAppTheme().textTheme.apply(
                      fontFamily: 'Preview',
                    ),
                  ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const Key('security-preview'),
              child: SeguridadPage(apiClient: api, token: 'one'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mi seguridad'), findsOneWidget);
        expect(api.paths.where((p) => p.startsWith('/indicadores')), isEmpty);
        expect(api.paths.where((p) => p.startsWith('/ranking')), isEmpty);
        expect(tester.takeException(), isNull);
        if (previewFont.isNotEmpty && scale == 1) {
          await expectLater(
            find.byKey(const Key('security-preview')),
            matchesGoldenFile('../build/security_${size.width.toInt()}.png'),
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('security-type-accidente')),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(SeguridadDashboard),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await Scrollable.ensureVisible(
            tester.element(
              find.byKey(const ValueKey('security-type-accidente')),
            ),
            alignment: .2,
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(const Key('security-preview')),
            matchesGoldenFile(
              '../build/security_cards_${size.width.toInt()}.png',
            ),
          );
          await tester.scrollUntilVisible(
            find.byType(SeguridadMonthlySeries),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(SeguridadDashboard),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(const Key('security-preview')),
            matchesGoldenFile(
              '../build/security_chart_${size.width.toInt()}.png',
            ),
          );
        }
        await tester.ensureVisible(find.text('Rankings'));
        await tester.tap(find.text('Rankings'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Alcance'));
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mi sucursal').last);
        await tester.pumpAndSettle();
        expect(api.paths.last, contains('alcance=sucursal'));
        expect(find.text('Ranking de personas externas'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'capabilities absent preserves old UI and session changes clear data',
    (tester) async {
      final api = _Api()..capabilities = false;
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SeguridadPage(apiClient: api, token: 'one'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mi seguridad'), findsOneWidget);
      expect(find.text('Seleccionar personas (0)'), findsOneWidget);
      api.capabilities = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SeguridadPage(apiClient: api, token: 'two'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mi seguridad'), findsOneWidget);
      expect(api.tokens.last, 'two');
    },
  );

  testWidgets('summary card opens approved history with the selected period', (
    tester,
  ) async {
    final api = _Api();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SeguridadPage(apiClient: api, token: 'one'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('security-type-seguro')),
      180,
      scrollable: find
          .descendant(
            of: find.byType(SeguridadDashboard),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('security-type-seguro'))),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('security-type-seguro'));
    final title = find.descendant(
      of: card,
      matching: find.text('Comportamiento seguro'),
    );
    final count = find.descendant(of: card, matching: find.text('2'));
    expect(tester.getCenter(title).dx, closeTo(tester.getCenter(card).dx, 1));
    expect(tester.getCenter(count).dx, closeTo(tester.getCenter(card).dx, 1));
    await tester.tap(card);
    await tester.pumpAndSettle();
    final request = Uri.parse(api.paths.last);
    expect(request.queryParameters, containsPair('vista', 'propio'));
    expect(request.queryParameters, containsPair('tipo', 'seguro'));
    expect(request.queryParameters, containsPair('desde', '2026-01-01'));
    expect(request.queryParameters, containsPair('hasta', '2026-12-31'));
    expect(find.text('Sin reportes para estos filtros.'), findsOneWidget);
  });

  testWidgets('sent history filters state with enlarged text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _Api()..capabilities = false;
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: SeguridadPage(apiClient: api, token: 'one'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mis reportes'));
    await tester.tap(find.text('Mis reportes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('rechazado').last);
    await tester.pumpAndSettle();
    expect(api.paths.last, contains('estado=rechazado'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unavailable scopes show reasons instead of zero; no duplicate fetch',
    (tester) async {
      final api = _Api();
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SeguridadIndicators(
                api: api,
                token: 'one',
                today: DateTime(2026, 10, 6),
                initial: _indicators(),
              ),
            ),
          ),
        ),
      );
      expect(find.text('No tenés una sucursal asignada.'), findsOneWidget);
      expect(
        find.text(
          'No hay accidentes registrados ni una fecha de inicio confiable para calcular los días. Administración puede configurar el inicio del registro.',
        ),
        findsOneWidget,
      );
      expect(find.text('0 días sin accidentes'), findsNothing);
      expect(api.paths, isEmpty);
    },
  );

  testWidgets(
    'monthly chart wraps months within mobile width and preserves future null',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SeguridadMonthlySeries(
              values: [0, 1, 2, 0, 3, 0, 1, 0, 0, 4, null, null],
              year: 2026,
              cutoff: DateTime(2026, 10, 6),
            ),
          ),
        ),
      );
      expect(find.text('0'), findsWidgets);
      expect(find.text('—'), findsWidgets);
      expect(find.text('Oct*'), findsOneWidget);
      for (final label in ['Ene', 'Jul', 'Dic']) {
        final bounds = tester.getRect(find.text(label));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(320));
      }
      expect(
        tester.getTopLeft(find.text('Dic')).dy,
        greaterThan(tester.getTopLeft(find.text('Ene')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home cards retain readable values with large text at 320px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 740),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: AttendanceStatsCarousel(
                items: [
                  AttendanceStatItem(
                    title: 'A tiempo esta semana',
                    value: '100 / 100',
                    icon: Icons.schedule_rounded,
                    accent: Colors.blue,
                  ),
                  AttendanceStatItem(
                    title: 'Última fichada',
                    value: '18:00',
                    icon: Icons.schedule_rounded,
                    accent: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
  });
}

Map<String, dynamic> _indicators() => {
  'hasta': '2026-10-06',
  'sucursal_id': null,
  'criterio': 'aprobados',
  'alcances': {
    'empresa': {'disponible': false, 'motivo': 'sin_inicio_configurado'},
    'sucursal': {'disponible': false, 'motivo': 'sin_sucursal'},
    'propio': <String, dynamic>{
      'disponible': true,
      'dias_sin_accidentes': 12,
      'record_dias_sin_accidentes': 20,
      'ultimo_accidente': '2026-09-24',
      'accidentes_registrados': 2,
      'inicio': '2026-01-01',
    },
  },
};

Map<String, dynamic> _summary({int year = 2026}) => {
  'anio': year,
  'mes': null,
  'fecha_corte': '2026-10-06',
  'total': 2,
  'por_tipo': {for (final type in seguridadTipos.keys) type: 2},
  'series_mensuales': {
    for (final type in seguridadTipos.keys)
      type: [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, null, null],
  },
  'comparativo_anual': {
    for (final type in seguridadTipos.keys)
      type: [
        {
          'anio': 2026,
          'valores': [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, null, null],
        },
      ],
  },
  'indicadores': _indicators(),
  'actualizado_at': '2026-10-06T12:00:00-03:00',
};

class _Api extends MobileApiClient {
  _Api() : super(baseUrl: 'https://example.test');
  final paths = <String>[];
  final tokens = <String>[];
  final pending = <Completer<Map<String, dynamic>>>[];
  bool holdSummary = false;
  bool capabilities = true;
  bool missingSummary = false;
  Object? summaryFailure;
  bool missingIndicators = false;
  @override
  Future<Map<String, dynamic>> getSeguridad({
    required String token,
    String path = '/config',
  }) async {
    paths.add(path);
    tokens.add(token);
    if (path.startsWith('/indicadores')) {
      if (missingIndicators) {
        throw ApiException(message: 'missing', statusCode: 404);
      }
      return _indicators();
    }
    if (path.startsWith('/resumen')) {
      if (summaryFailure != null) throw summaryFailure!;
      if (missingSummary) {
        throw ApiException(message: 'missing', statusCode: 404);
      }
      if (!holdSummary) return _summary();
      final completer = Completer<Map<String, dynamic>>();
      pending.add(completer);
      return completer.future;
    }
    if (path == '/config') {
      return {
        'fecha_actual': '2026-10-06',
        'empleados': [],
        'externos': [],
        'catalogos': [],
        if (capabilities)
          'dashboard': {
            'historial_propio': true,
            'indicadores': true,
            'ranking_alcances': ['empresa', 'sucursal'],
            'sucursal_id': 1,
          },
      };
    }
    if (path.startsWith('/ranking')) {
      return {
        'rankings': {
          'seguro': [
            {
              'empleado_id': 1,
              'nombre': 'Ana',
              'legajo': '001',
              'cantidad': 2,
              'posicion': 1,
            },
          ],
          'inseguro': [],
        },
        'mi_posicion': {
          'seguro': {'empleado_id': 1, 'cantidad': 2, 'posicion': 1},
          'inseguro': null,
        },
      };
    }
    return {'items': [], 'total': 0, 'per_page': 30};
  }
}
