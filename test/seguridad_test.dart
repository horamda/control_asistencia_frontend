import 'dart:typed_data';
import 'dart:convert';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/seguridad_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test(
    'authenticated multipart preserves UUID and people through refresh',
    () async {
      final bodies = <String>[];
      final auth = <String?>[];
      final api = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          expect(r.url.path, '/api/v1/mobile/seguridad/eventos');
          bodies.add(r.body);
          auth.add(r.headers['Authorization']);
          return bodies.length == 1
              ? http.Response('{"error":"expired"}', 401)
              : http.Response(
                  '{"id":1,"estado":"pendiente","repetido":false}',
                  201,
                );
        }),
      );
      addTearDown(api.dispose);
      api.configureAuth(onUnauthorizedRefresh: (_) async => 'new');
      final result = await api.createSeguridad(
        token: 'old',
        fields: {'envio_id': 'stable-uuid', 'involucrados': '[10,11]'},
        fotos: [
          Uint8List.fromList([1, 2, 3]),
        ],
      );
      expect(result['id'], 1);
      expect(auth, ['Bearer old', 'Bearer new']);
      for (final body in bodies) {
        expect(body, contains('stable-uuid'));
        expect(body, contains('[10,11]'));
        expect(body, contains('name="fotos"'));
      }
    },
  );
  test('private photo sends bearer and propagates errors', () async {
    final api = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((r) async {
        expect(r.url.path, '/api/v1/mobile/seguridad/fotos/8');
        expect(r.headers['Authorization'], 'Bearer token');
        return http.Response('missing', 404);
      }),
    );
    addTearDown(api.dispose);
    await expectLater(
      api.getSeguridadFoto(token: 'token', id: 8),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });
  for (final width in [320.0, 800.0]) {
    testWidgets('form history and rankings fit width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _Api();
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SeguridadPage(apiClient: api, token: 'token'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Mi historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi historial'));
      await tester.pumpAndSettle();
      expect(find.text('Sin reportes para estos filtros.'), findsOneWidget);
      await tester.ensureVisible(find.text('Rankings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rankings'));
      await tester.pumpAndSettle();
      expect(find.text('Perez Ana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'selects people and retries without changing submission key; camera and gallery available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _Api()..failFirst = true;
      final picker = _Picker();
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SeguridadPage(
            apiClient: api,
            token: 'token',
            imagePicker: picker,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar personas (0)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EPP correcto').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Usa EPP correctamente.',
      );
      await tester.ensureVisible(find.text('Cámara'));
      await tester.tap(find.text('Cámara'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Galería'));
      await tester.pumpAndSettle();
      expect(picker.sources, [ImageSource.camera]);
      expect(picker.galleryCalls, 1);
      await tester.scrollUntilVisible(
        find.text('Enviar reporte'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(Form),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar reporte'));
      await tester.pumpAndSettle();
      expect(api.sent.length, 1);
      await tester.scrollUntilVisible(
        find.text('Enviar reporte'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(Form),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar reporte'));
      await tester.pumpAndSettle();
      expect(api.sent.length, 2);
      expect(api.sent[0]['envio_id'], api.sent[1]['envio_id']);
      expect(api.sent[0]['involucrados'], '[10]');
      expect(
        find.text('Reporte enviado, pendiente de aprobación.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 800.0]) {
    testWidgets(
      'external name required, company optional, no employee required at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1300));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = _Api();
        addTearDown(api.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: SeguridadPage(apiClient: api, token: 'token'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agregar persona externa'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Crear persona nueva'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agregar').last);
        await tester.pumpAndSettle();
        expect(find.text('Ingresá el nombre.'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre del externo'),
          'Visitante',
        );
        await tester.tap(find.text('Agregar').last);
        await tester.pumpAndSettle();
        expect(find.text('Visitante'), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EPP correcto').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Usa protección.',
        );
        await tester.scrollUntilVisible(
          find.text('Enviar reporte'),
          250,
          scrollable: find
              .descendant(
                of: find.byType(Form),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enviar reporte'));
        await tester.pumpAndSettle();
        expect(api.sent.length, 1);
        expect(api.sent.single['involucrados'], '[]');
        expect(jsonDecode(api.sent.single['externos']!), [
          {'nombre': 'Visitante', 'empresa': ''},
        ]);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Rankings'));
        await tester.tap(find.text('Rankings'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(find.text('Externo registrado'), findsOneWidget);
        expect(find.text('Perez Ana'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Api extends MobileApiClient {
  _Api() : super(baseUrl: 'https://example.test');
  bool failFirst = false;
  final sent = <Map<String, String>>[];
  @override
  Future<Map<String, dynamic>> getSeguridad({
    required String token,
    String path = '/config',
  }) async {
    if (path == '/config') {
      return {
        'fecha_actual': '2026-10-02',
        'empleados': [
          {'id': 10, 'legajo': '0010', 'nombre': 'Ana', 'apellido': 'Perez'},
        ],
        'externos': [
          {'id': 7, 'nombre': 'Externo registrado', 'empresa': ''},
        ],
        'catalogos': [
          {
            'id': 1,
            'clase': 'categoria',
            'tipo': 'seguro',
            'activo': 1,
            'nombre': 'EPP correcto',
          },
        ],
      };
    }
    if (path.startsWith('/ranking')) {
      return {
        'rankings_externos': {
          'seguro': [
            {
              'externo_id': 7,
              'nombre': 'Externo registrado',
              'empresa': '',
              'cantidad': 2,
              'posicion': 1,
            },
          ],
          'inseguro': [],
        },
        'rankings': {
          'seguro': [
            {
              'posicion': 1,
              'nombre': 'Perez Ana',
              'legajo': '0010',
              'cantidad': 3,
            },
          ],
          'inseguro': [],
        },
      };
    }
    return {'items': [], 'total': 0};
  }

  @override
  Future<Map<String, dynamic>> createSeguridad({
    required String token,
    required Map<String, String> fields,
    required List<Uint8List> fotos,
  }) async {
    sent.add(Map.of(fields));
    if (failFirst && sent.length == 1) {
      throw ApiException(message: 'Conexión interrumpida', statusCode: 503);
    }
    return {'id': 1, 'estado': 'pendiente', 'repetido': false};
  }
}

class _Picker extends ImagePicker {
  final sources = <ImageSource>[];
  int galleryCalls = 0;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sources.add(source);
    return null;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    galleryCalls++;
    return [];
  }
}
