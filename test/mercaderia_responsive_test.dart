import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/pedidos_mercaderia_page.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(740, 360),
    const Size(800, 1024),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('merchandise history and editing $size $brightness', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final item = {
          'id': 1,
          'periodo': 'Octubre 2026',
          'estado': 'pendiente',
          'total_bultos': 12,
          'total_unidades': 144,
          'items': [
            {
              'articulo_id': 1,
              'descripcion':
                  'Artículo de prueba con una descripción extensa para comprobar lectura',
              'cantidad_bultos': 12,
              'cantidad_unidades': 0,
              'unidades_por_bulto': 12,
            },
          ],
        };
        final api = MobileApiClient(
          baseUrl: 'https://test.invalid',
          httpClient: MockClient((r) async {
            final path = r.url.path;
            final Object data = path.endsWith('/estado')
                ? {'periodo': '2026-10', 'ya_solicitado': true, 'pedido': item}
                : path.endsWith('/resumen')
                ? {}
                : path.endsWith('/articulos')
                ? {
                    'items': [
                      {
                        'id': 1,
                        'descripcion':
                            'Artículo de prueba con una descripción extensa para comprobar lectura',
                        'unidades_por_bulto': 12,
                      },
                    ],
                    'total': 1,
                  }
                : {
                    'items': [item],
                    'total': 1,
                  };
            return http.Response(
              jsonEncode(data),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        addTearDown(api.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: PedidosMercaderiaPage(apiClient: api, token: 'test'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Editar').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Editar').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byTooltip('Agregar Bultos'),
          150,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Agregar Bultos'));
        await tester.pumpAndSettle();
        expect(find.text('13'), findsOneWidget);
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();
        expect(find.text('Confirmar cambios'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Revisar pedido'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Revisar pedido'));
        await tester.pumpAndSettle();
        expect(find.text('Confirmar cambios'), findsNothing);
        expect(find.text('13'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
