import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/reuniones_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

const _name = 'Reunión de seguridad y coordinación del equipo';
const _stats = {
  'convocatorias': 20,
  'presentes': 15,
  'tarde': 2,
  'ausentes': 2,
  'justificados': 1,
  'asistidas': 17,
  'asistencia_pct': 89.5,
  'puntualidad_pct': 88.2,
};
Map<String, dynamic> get _occurrence => {
  'reunion_id': 3,
  'nombre': _name,
  'fecha': '2026-10-21',
  'inicio': '2026-10-21T09:00:00-03:00',
  'fin': '2026-10-21T09:45:00-03:00',
  'ventana_desde': '2026-10-21T08:45:00-03:00',
  'estado': 'abierta',
  'cancelada': false,
  'sucursal_nombre': 'Casa central',
  'lugar': 'Sala de capacitación',
  'motivo_cambio': 'Pospuesta del martes 20/10 por día no laborable.',
};
Map<String, dynamic> get _definition => {
  'id': 3,
  'nombre': _name,
  'descripcion_frecuencia': 'Todos los miércoles a las 09:00 (45 min)',
  'proxima_fecha': '2026-10-21',
  'mis_estadisticas': _stats,
  'sucursal_nombre': 'Casa central',
};

void main() {
  var previewFontAvailable = false;
  setUpAll(() async {
    final windows = Platform.environment['WINDIR'];
    if (windows != null) {
      final file = File('$windows/Fonts/arial.ttf');
      if (await file.exists()) {
        final loader = FontLoader('PreviewSans')
          ..addFont(file.readAsBytes().then(ByteData.sublistView));
        await loader.load();
        previewFontAvailable = true;
      }
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final brightness in Brightness.values) {
    for (final (size, scale) in [
      (const Size(320, 568), 1.0),
      (const Size(390, 844), 1.5),
      (const Size(740, 360), 2.0),
      (const Size(800, 1100), 1.0),
      (const Size(1024, 768), 1.5),
    ]) {
      testWidgets(
        'Reuniones agenda, historial, estadísticas y detalle $brightness $size text $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = MobileApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient((r) async {
              final path = r.url.path;
              final Object body;
              if (path.endsWith('/proximas')) {
                body = {
                  'items': [
                    _occurrence,
                    {
                      ..._occurrence,
                      'reunion_id': 4,
                      'nombre': 'Coordinación de operaciones',
                      'estado': 'pendiente',
                    },
                  ],
                };
              } else if (path.endsWith('/estadisticas')) {
                body = {
                  'periodo': {'desde': '2026-07-18', 'hasta': '2026-10-15'},
                  'totales': _stats,
                  'por_reunion': [
                    {..._stats, 'nombre': _name},
                    {..._stats, 'nombre': 'Operaciones'},
                  ],
                };
              } else if (path.endsWith('/historial')) {
                body = {
                  'items': [
                    {
                      ..._occurrence,
                      'estado': 'justificado',
                      'observaciones': 'Vacaciones autorizadas',
                      'inicio': '09:00',
                      'fin': '09:45',
                    },
                  ],
                  'page': 1,
                  'per_page': 20,
                  'total': 1,
                };
              } else if (path.endsWith('/3')) {
                body = {
                  ..._definition,
                  'activa': true,
                  'qr_modo': 'ambos',
                  'feriado_accion': 'posponer',
                  'proximas_fechas': ['2026-10-21', '2026-10-28'],
                  'historial': [],
                };
              } else {
                body = {
                  'items': [_definition],
                };
              }
              return http.Response(
                jsonEncode(body),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          );
          const boundaryKey = ValueKey('reuniones-preview');
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: previewFontAvailable
                    ? buildAppTheme(brightness: brightness).copyWith(
                        textTheme: buildAppTheme(
                          brightness: brightness,
                        ).textTheme.apply(fontFamily: 'PreviewSans'),
                        primaryTextTheme: buildAppTheme(
                          brightness: brightness,
                        ).primaryTextTheme.apply(fontFamily: 'PreviewSans'),
                      )
                    : buildAppTheme(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: ReunionesPage(
                  api: api,
                  token: 'jwt',
                  onChanged: () async {},
                  onClockQr: (_) async {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (size.width == 390 || size.width == 800) {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(boundaryKey),
              );
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(
                '.dart_tool/reuniones_previews',
              ).create(recursive: true);
              await File(
                '.dart_tool/reuniones_previews/agenda_${brightness.name}_${size.width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          for (final tab in ['Historial', 'Estadísticas', 'Mis reuniones']) {
            tester
                .state<ScrollableState>(
                  find
                      .descendant(
                        of: find.byType(ListView).last,
                        matching: find.byType(Scrollable),
                      )
                      .first,
                )
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            final target = find.widgetWithText(ChoiceChip, tab);
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
            // Scroll the inner content to exercise natural card heights and FAB clearance.
            await tester.drag(
              find.byType(ListView).last,
              const Offset(0, -550),
            );
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.text(_name));
          await tester.pumpAndSettle();
          await tester.tap(find.text(_name));
          await tester.pumpAndSettle();
          expect(find.text('Detalle de reunión'), findsOneWidget);
          await tester.drag(find.byType(ListView).last, const Offset(0, -500));
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
