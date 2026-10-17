import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/seguridad_external_dialog.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dialog keeps actions reachable with keyboard and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _CatalogApi();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.6),
            viewInsets: const EdgeInsets.only(bottom: 220),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SeguridadExternalDialog(
            api: api,
            token: 'token',
            onConfig: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cancelar').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.text('Crear persona nueva'));
    await tester.tap(find.text('Crear persona nueva'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cancelar').hitTestable(), findsOneWidget);
  });
  for (final width in [320.0, 800.0]) {
    testWidgets('loads catalog, searches and returns existing ID at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _CatalogApi();
      addTearDown(api.dispose);
      List<Map<String, dynamic>>? selected;
      var refreshed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showDialog<List<Map<String, dynamic>>>(
                    context: context,
                    builder: (_) => SeguridadExternalDialog(
                      api: api,
                      token: 'token',
                      onConfig: (_) => refreshed = true,
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      expect(refreshed, isTrue);
      expect(find.text('Juan Visitante'), findsOneWidget);
      expect(find.text('Nombre del externo'), findsNothing);
      await tester.tap(find.text('Juan Visitante'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Proveedor B');
      await tester.pumpAndSettle();
      expect(find.text('Juan Visitante'), findsNothing);
      await tester.tap(find.text('Ana Externa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Externa'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar (2)'), findsNothing);
      await tester.tap(find.text('Ana Externa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar (2)'));
      await tester.pumpAndSettle();
      expect(selected, [
        {'id': 7},
        {'id': 8},
      ]);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('already added people are checked and cannot be added again', (
    tester,
  ) async {
    final api = _CatalogApi();
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeguridadExternalDialog(
            api: api,
            token: 'token',
            onConfig: (_) {},
            existingIds: const {7},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final checkbox = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Juan Visitante'),
    );
    expect(checkbox.value, isTrue);
    expect(checkbox.onChanged, isNull);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Agregar'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('missing catalog and network errors are not an empty list', (
    tester,
  ) async {
    final api = _CatalogApi()..missing = true;
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SeguridadExternalDialog(
          api: api,
          token: 'token',
          onConfig: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('El servidor no está enviando el catálogo'),
      findsOneWidget,
    );
    api.missing = false;
    api.fail = true;
    await tester.tap(find.text('Actualizar lista'));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Juan Visitante'), findsOneWidget);
  });
}

class _CatalogApi extends MobileApiClient {
  _CatalogApi() : super(baseUrl: 'https://example.test');
  int calls = 0;
  bool missing = false;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> getSeguridad({
    required String token,
    String path = '/config',
  }) async {
    expect(token, 'token');
    expect(path, '/config');
    calls++;
    if (fail) throw ApiException(message: 'Sin conexión', statusCode: 503);
    return {
      if (!missing)
        'externos': [
          {'id': 7, 'nombre': 'Juan Visitante', 'empresa': 'Proveedor A'},
          {'id': 8, 'nombre': 'Ana Externa', 'empresa': 'Proveedor B'},
        ],
    };
  }
}
