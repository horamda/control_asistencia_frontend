import 'dart:convert';
import 'dart:typed_data';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/cargas_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  for (final width in [320.0, 768.0, 1280.0]) {
    testWidgets('responsive form and history at $width with enlarged text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/config')
                  ? {'habilitado': true, 'camiones': [], 'horarios': []}
                  : {
                      'total': 31,
                      'items': [
                        for (var id = 1; id <= 2; id++)
                          {
                            'id': id,
                            'camion_numero': 'CAMION-CON-NUMERO-LARGO-0001',
                            'camion_patente': 'AA123BB',
                            'consolidado': '000012345678901234567890',
                            'tipo': 'inicial',
                            'valida': 0,
                            'en_horario': 0,
                            'registrado_at': '2026-10-02T10:00:00Z',
                          },
                      ],
                    },
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CargasPage(apiClient: client, token: 'token'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.textContaining('Registrar validaci').last,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mi historial'));
      await tester.pumpAndSettle();
      expect(find.text('No valida'), findsNWidgets(2));
      expect(find.text('Fuera de horario'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Siguiente'),
        300,
        scrollable: find.descendant(
          of: find.byKey(const PageStorageKey('carga-history')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final status in [403, 404, 409, 500]) {
    testWidgets('recupera carga tras $status conservando el envío', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _ConflictApi(status);
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CargasPage(apiClient: api, token: 'token'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('01 · AAA').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '000123');
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí').last);
      await tester.pumpAndSettle();
      Future<void> submit() async {
        await tester.tap(find.text('Registrar validación'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enviar'));
        await tester.pumpAndSettle();
      }

      await submit();
      expect(api.sent.length, 1);
      expect(api.configReads, status == 500 ? 1 : 2);
      expect(api.historyReads, status == 500 ? 1 : 2);
      expect(find.textContaining('Error original $status'), findsOneWidget);
      if (status == 403) {
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Mi historial'), findsOneWidget);
        // La configuración se aplica aunque el historial falle.
        expect(
          find.textContaining('No se pudo actualizar el historial'),
          findsOneWidget,
        );
      } else {
        expect(find.text('000123'), findsOneWidget);
        if (status == 404) {
          expect(
            find.text('No hay vehículos activos. Contacte al administrador.'),
            findsOneWidget,
          );
        } else {
          await submit();
          expect(api.sent.length, 2);
          expect(api.sent[1], api.sent[0]);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('respeta cantidad, tamaño y cambios de límites del servidor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var maxFotos = 1;
    var maxBytes = 1000;
    final picker = _TestImagePicker();
    final client = MobileApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/config')
                ? {
                    'habilitado': true,
                    'max_fotos': maxFotos,
                    'max_foto_bytes': maxBytes,
                    'camiones': [
                      {
                        'id': 1,
                        'numero': '01',
                        'patente': 'AAA',
                        'sucursal_id': 1,
                        'tiene_inicial': 0,
                      },
                    ],
                    'horarios': [],
                  }
                : {'items': [], 'total': 0},
          ),
          200,
        ),
      ),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CargasPage(
          apiClient: client,
          token: 'token',
          imagePicker: picker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
    );
    final photo = XFile.fromData(png, name: 'foto.png');
    picker.files = [photo, photo];
    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();
    expect(find.text('Fotos opcionales (0/1)'), findsOneWidget);
    expect(
      find.textContaining('No se pudieron agregar las fotos.'),
      findsOneWidget,
    );
    maxBytes = png.length - 1;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    picker.files = [photo];
    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();
    expect(find.text('Fotos opcionales (0/1)'), findsOneWidget);
    expect(
      find.textContaining('No se pudieron agregar las fotos.'),
      findsOneWidget,
    );
    maxBytes = png.length;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();
    expect(find.text('Fotos opcionales (1/1)'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Galería'),
          )
          .onPressed,
      isNull,
    );
    maxFotos = 0;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('Fotos opcionales (1/0)'), findsOneWidget);
    await tester.tap(find.text('Registrar validación'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Las fotos seleccionadas superan'),
      findsOneWidget,
    );
    expect(find.text('Confirmar validación'), findsNothing);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(find.text('Fotos opcionales (0/0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'mobile form requires explicit yes/no and preserves consolidation text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var posts = 0;
      final client = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          if (request.method == 'POST') posts++;
          final data = request.url.path.endsWith('/config')
              ? {
                  'habilitado': true,
                  'camiones': [
                    {
                      'id': 1,
                      'numero': '01',
                      'patente': 'AA001AA',
                      'descripcion': 'Camion refrigerado para reparto',
                      'sucursal_nombre': 'Central',
                      'sucursal_id': 2,
                      'tiene_inicial': 0,
                    },
                  ],
                  'horarios': [
                    {
                      'tipo': 'inicial',
                      'nombre': 'Inicial',
                      'sucursal_id': null,
                      'desde_minuto': 0,
                      'hasta_minuto': 485,
                    },
                  ],
                }
              : {'items': [], 'total': 0};
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CargasPage(apiClient: client, token: 'token'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Validación de carga'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '000123');
      expect(find.text('000123'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('01 · AA001AA').last);
      await tester.pumpAndSettle();
      expect(find.text('Camion refrigerado para reparto'), findsOneWidget);
      expect(find.textContaining('Sucursal: Central'), findsOneWidget);
      await tester.ensureVisible(find.text('Registrar validación'));
      await tester.tap(find.text('Registrar validación'));
      await tester.pumpAndSettle();
      expect(find.text('Seleccione Sí o No.'), findsOneWidget);
      expect(posts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'employee without eligible position retains history without creation form',
    (tester) async {
      final client = MobileApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/config')
                  ? {
                      'habilitado': false,
                      'tiene_historial': true,
                      'camiones': [],
                      'horarios': [],
                    }
                  : {'items': [], 'total': 0},
            ),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CargasPage(apiClient: client, token: 'token'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Mi historial'), findsOneWidget);
    },
  );
}

class _TestImagePicker extends ImagePicker {
  List<XFile> files = [];
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => files;
}

class _ConflictApi extends MobileApiClient {
  _ConflictApi(this.status) : super(baseUrl: 'https://example.test');
  final int status;
  int configReads = 0;
  int historyReads = 0;
  final sent = <Map<String, String>>[];
  @override
  Future<Map<String, dynamic>> getCargas({
    required String token,
    String path = '',
  }) async {
    if (path == '/config') {
      configReads++;
      return {
        'habilitado': sent.isEmpty || status != 403,
        'tiene_historial': true,
        'camiones': sent.isNotEmpty && status == 404
            ? []
            : [
                {
                  'id': 1,
                  'numero': '01',
                  'patente': 'AAA',
                  'sucursal_id': 1,
                  'tiene_inicial': 0,
                },
              ],
        'horarios': [],
      };
    }
    historyReads++;
    if (sent.isNotEmpty && status == 403) {
      throw ApiException(
        message: 'Historial temporalmente no disponible',
        statusCode: 500,
      );
    }
    return {'items': [], 'total': 0};
  }

  @override
  Future<Map<String, dynamic>> createCarga({
    required String token,
    required Map<String, String> fields,
    required List<Uint8List> fotos,
  }) async {
    sent.add(Map.of(fields));
    throw ApiException(message: 'Error original $status', statusCode: status);
  }
}
