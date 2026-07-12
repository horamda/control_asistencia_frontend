import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ficharqr/src/core/network/feedback_api_models.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/core/network/skap_api_models.dart';

void main() {
  test(
    'updatePerfilConFotoFile refresca token y reintenta upload multipart',
    () async {
      final sourceRoot = await Directory.systemTemp.createTemp(
        'mobile-api-client-upload-',
      );

      try {
        final file = File(
          '${sourceRoot.path}${Platform.pathSeparator}profile.jpg',
        );
        await file.writeAsBytes(const <int>[1, 2, 3, 4]);

        final client = _QueuedClient([
          _QueuedReply(
            statusCode: 401,
            body: const <String, dynamic>{'error': 'Sesion vencida.'},
            inspect: (request) {
              expect(request.method, 'PUT');
              expect(request.url.path, '/api/v1/mobile/me/perfil');
              expect(request.headers['Authorization'], 'Bearer expired-token');
            },
          ),
          _QueuedReply(
            statusCode: 200,
            body: const <String, dynamic>{
              'id': 7,
              'telefono': '1234',
              'direccion': 'Calle 1',
            },
            inspect: (request) {
              expect(request.method, 'PUT');
              expect(request.url.path, '/api/v1/mobile/me/perfil');
              expect(request.headers['Authorization'], 'Bearer fresh-token');
            },
          ),
        ]);

        final apiClient = MobileApiClient(
          baseUrl: 'https://example.com',
          httpClient: client,
        );
        String? refreshedToken;
        apiClient.configureAuth(
          onUnauthorizedRefresh: (expiredToken) async {
            refreshedToken = expiredToken;
            return 'fresh-token';
          },
        );

        final result = await apiClient.updatePerfilConFotoFile(
          token: 'expired-token',
          fotoPath: file.path,
          telefono: '1234',
          direccion: 'Calle 1',
        );

        expect(refreshedToken, 'expired-token');
        expect(result.id, 7);
        expect(result.telefono, '1234');
        expect(client.callCount, 2);
        apiClient.dispose();
      } finally {
        if (await sourceRoot.exists()) {
          await sourceRoot.delete(recursive: true);
        }
      }
    },
  );

  test(
    'createJustificacion con adjuntos envia multipart y parsea adjuntos',
    () async {
      final sourceRoot = await Directory.systemTemp.createTemp(
        'mobile-api-client-justificacion-',
      );

      try {
        final file = File(
          '${sourceRoot.path}${Platform.pathSeparator}certificado.pdf',
        );
        await file.writeAsBytes(const <int>[1, 2, 3, 4, 5, 6]);

        final client = _QueuedClient([
          _QueuedReply(
            statusCode: 201,
            body: const <String, dynamic>{
              'id': 10,
              'fecha': '2026-06-01',
              'asistencia_id': 8,
              'asistencia_fecha': '2026-06-01',
              'motivo': 'Enfermedad con certificado',
              'adjuntos_count': 1,
              'adjuntos': [
                {
                  'id': 88,
                  'evento_id': 8,
                  'nombre_original': 'certificado.pdf',
                  'mime_type': 'application/pdf',
                  'extension': 'pdf',
                  'tamano_bytes': 6,
                  'estado': 'activo',
                  'created_at': '2026-06-01T09:00:00',
                  'download_url':
                      '/api/v1/mobile/me/justificaciones/10/adjuntos/88',
                },
              ],
              'estado': 'pendiente',
              'created_at': '2026-06-01T08:30:00',
            },
            inspect: (request) {
              expect(request, isA<http.MultipartRequest>());
              final multipart = request as http.MultipartRequest;
              expect(multipart.method, 'POST');
              expect(multipart.url.path, '/api/v1/mobile/me/justificaciones');
              expect(multipart.headers['Authorization'], 'Bearer abc');
              expect(multipart.fields['motivo'], 'Enfermedad con certificado');
              expect(multipart.fields['fecha'], '2026-06-01');
              expect(multipart.fields['asistencia_id'], '8');
              expect(multipart.files, hasLength(1));
              expect(multipart.files.single.field, 'adjuntos');
              expect(multipart.files.single.filename, 'certificado.pdf');
              expect(multipart.files.single.contentType.type, 'application');
              expect(multipart.files.single.contentType.subtype, 'pdf');
            },
          ),
        ]);

        final apiClient = MobileApiClient(
          baseUrl: 'https://example.com',
          httpClient: client,
        );

        final result = await apiClient.createJustificacion(
          token: 'abc',
          motivo: '  Enfermedad con certificado  ',
          fecha: '2026-06-01',
          asistenciaId: 8,
          adjuntos: [
            JustificacionAdjuntoUpload(
              filename: 'certificado.pdf',
              path: file.path,
              sizeBytes: await file.length(),
            ),
          ],
        );

        expect(result.id, 10);
        expect(result.fecha, '2026-06-01');
        expect(result.motivo, 'Enfermedad con certificado');
        expect(result.adjuntosCount, 1);
        expect(result.hasAdjuntos, isTrue);
        expect(result.adjuntos.single.displayName, 'certificado.pdf');
        expect(client.callCount, 1);
        apiClient.dispose();
      } finally {
        if (await sourceRoot.exists()) {
          await sourceRoot.delete(recursive: true);
        }
      }
    },
  );

  test(
    'createJustificacion con rango envia fecha_desde y fecha_hasta',
    () async {
      final client = _QueuedClient([
        _QueuedReply(
          statusCode: 201,
          body: const <String, dynamic>{
            'id': 12,
            'fecha': '2026-06-01',
            'fecha_desde': '2026-06-01',
            'fecha_hasta': '2026-06-03',
            'asistencia_id': null,
            'asistencia_fecha': null,
            'motivo': 'Reposo prolongado',
            'adjuntos_count': 0,
            'adjuntos': <Map<String, dynamic>>[],
            'estado': 'pendiente',
            'created_at': '2026-06-01T08:30:00',
          },
          inspect: (request) {
            expect(request, isA<http.Request>());
            final httpRequest = request as http.Request;
            final payload = jsonDecode(httpRequest.body) as Map<String, dynamic>;
            expect(payload['motivo'], 'Reposo prolongado');
            expect(payload['fecha_desde'], '2026-06-01');
            expect(payload['fecha_hasta'], '2026-06-03');
            expect(payload.containsKey('fecha'), isFalse);
          },
        ),
      ]);

      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: client,
      );

      final result = await apiClient.createJustificacion(
        token: 'abc',
        motivo: 'Reposo prolongado',
        fechaDesde: '2026-06-01',
        fechaHasta: '2026-06-03',
      );

      expect(result.id, 12);
      expect(result.fechaDesde, '2026-06-01');
      expect(result.fechaHasta, '2026-06-03');
      expect(result.hasFechaRange, isTrue);
      expect(client.callCount, 1);
      apiClient.dispose();
    },
  );

  test(
    'createJustificacion con bytes sanitiza el nombre del adjunto',
    () async {
      final client = _QueuedClient([
        _QueuedReply(
          statusCode: 201,
          body: const <String, dynamic>{
            'id': 11,
            'fecha': '2026-07-09',
            'asistencia_id': null,
            'asistencia_fecha': null,
            'motivo': 'Con evidencia',
            'adjuntos_count': 1,
            'adjuntos': [],
            'estado': 'pendiente',
            'created_at': '2026-07-09T12:00:00',
          },
          inspect: (request) {
            expect(request, isA<http.MultipartRequest>());
            final multipart = request as http.MultipartRequest;
            expect(multipart.files, hasLength(1));
            expect(
              multipart.files.single.filename,
              'WhatsApp_Image_2026_07_09_at_12_56_05.jpeg',
            );
            expect(multipart.files.single.contentType.type, 'image');
            expect(multipart.files.single.contentType.subtype, 'jpeg');
          },
        ),
      ]);

      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: client,
      );

      final result = await apiClient.createJustificacion(
        token: 'abc',
        motivo: 'Con evidencia',
        fecha: '2026-07-09',
        adjuntos: [
          JustificacionAdjuntoUpload(
            filename: 'WhatsApp Image 2026-07-09 at 12.56.05.jpeg',
            bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
            sizeBytes: 4,
          ),
        ],
      );

      expect(result.id, 11);
      expect(client.callCount, 1);
      apiClient.dispose();
    },
  );

  test('usa el prefijo movil configurable para construir endpoints', () async {
    final client = _QueuedClient([
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{'id': 1},
        inspect: (request) {
          expect(request.method, 'GET');
          expect(request.url.path, '/custom/mobile/me');
        },
      ),
    ]);

    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com',
      mobileApiPrefix: '/custom/mobile',
      httpClient: client,
    );

    final profile = await apiClient.getMe(token: 'abc');

    expect(profile.id, 1);
    expect(client.callCount, 1);
    apiClient.dispose();
  });

  test('buildEmpleadoImagenUrl elimina el prefijo movil del baseUrl', () {
    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com/custom/mobile',
      mobileApiPrefix: '/custom/mobile',
      httpClient: _QueuedClient(const <_QueuedReply>[]),
    );

    final imageUrl = apiClient.buildEmpleadoImagenUrl(
      dni: '30111222',
      version: 3,
    );

    expect(imageUrl, 'https://example.com/empleados/imagen/30111222?v=3');
    apiClient.dispose();
  });

  test('getLegajoEventos envia filtros del contrato 1.18', () async {
    final client = _QueuedClient([
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{
          'ok': true,
          'items': [
            {'id': 45, 'tipo_codigo': 'llamado_atencion', 'adjuntos_count': 1},
          ],
          'total': 1,
          'page': 2,
          'per_page': 10,
          'pagination': {
            'page': 2,
            'per_page': 10,
            'total': 1,
            'has_more': false,
          },
        },
        inspect: (request) {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/mobile/me/legajo/eventos');
          expect(request.url.queryParameters['tipo_id'], '3');
          expect(request.url.queryParameters['estado'], 'vigente');
          expect(request.url.queryParameters['severidad'], 'leve');
          expect(request.url.queryParameters['desde'], '2026-01-01');
          expect(request.url.queryParameters['hasta'], '2026-12-31');
          expect(request.url.queryParameters['q'], 'tarde');
        },
      ),
    ]);

    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: client,
    );

    final result = await apiClient.getLegajoEventos(
      token: 'abc',
      page: 2,
      per: 10,
      tipoId: 3,
      estado: 'vigente',
      severidad: 'leve',
      desde: '2026-01-01',
      hasta: '2026-12-31',
      queryText: 'tarde',
    );

    expect(result.ok, isTrue);
    expect(result.items.single.tipoCodigo, 'llamado_atencion');
    expect(result.page, 2);
    expect(result.perPage, 10);
    expect(result.hasMore, isFalse);
    apiClient.dispose();
  });

  test(
    'getLegajoEventoDetalle parsea campos basicos de LegajoEventoItem',
    () async {
      final client = _QueuedClient([
        _QueuedReply(
          statusCode: 200,
          body: const <String, dynamic>{
            'ok': true,
            'id': 45,
            'tipo_nombre': 'Llamado de atencion',
            'tipo_codigo': 'llamado_atencion',
            'estado': 'vigente',
            'severidad': 'leve',
          },
          inspect: (request) {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/mobile/me/legajo/eventos/45');
          },
        ),
      ]);

      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: client,
      );

      final evento = await apiClient.getLegajoEventoDetalle(
        token: 'abc',
        id: 45,
      );

      expect(evento.id, 45);
      expect(evento.tipoNombre, 'Llamado de atencion');
      expect(evento.estado, 'vigente');
      expect(evento.severidad, 'leve');
      apiClient.dispose();
    },
  );

  test('login envia telemetria cuando se proporcionan los campos', () async {
    final client = _QueuedClient([
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{
          'token': 'jwt-abc',
          'empleado': {
            'id': 5,
            'dni': '30111222',
            'nombre': 'Ana',
            'apellido': 'Lopez',
          },
        },
        inspect: (request) {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/mobile/auth/login');
          final body = jsonDecode((request as http.Request).body) as Map;
          expect(body['dni'], '30111222');
          expect(body['platform'], 'android');
          expect(body['device_model'], 'Samsung Galaxy S23');
          expect(body['app_version'], '1.20.4');
        },
      ),
    ]);

    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: client,
    );

    final session = await apiClient.login(
      dni: '30111222',
      password: 'secret',
      platform: 'android',
      deviceModel: 'Samsung Galaxy S23',
      appVersion: '1.20.4',
    );

    expect(session.token, 'jwt-abc');
    expect(session.empleado.id, 5);
    apiClient.dispose();
  });

  test('login omite telemetria cuando los campos son null', () async {
    final client = _QueuedClient([
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{
          'token': 'jwt-xyz',
          'empleado': {
            'id': 7,
            'dni': '20999888',
            'nombre': 'Carlos',
            'apellido': null,
          },
        },
        inspect: (request) {
          final body = jsonDecode((request as http.Request).body) as Map;
          expect(body.containsKey('platform'), isFalse);
          expect(body.containsKey('device_model'), isFalse);
          expect(body.containsKey('app_version'), isFalse);
        },
      ),
    ]);

    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: client,
    );

    final session = await apiClient.login(dni: '20999888', password: 'pass');

    expect(session.token, 'jwt-xyz');
    apiClient.dispose();
  });

  test('getKpisSectorResumen usa contrato 1.21 y parsea vistas', () async {
    final client = _QueuedClient([
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{
          'anio': 2026,
          'sector': {'id': 3, 'nombre': 'Entrega'},
          'vista_actual': {
            'kpis': [
              {
                'kpi_id': 1,
                'codigo': 'BULTOS_ENT',
                'nombre': 'Bultos entregados',
                'unidad': 'bultos',
                'tipo_acumulacion': 'suma',
                'mayor_es_mejor': true,
                'condicion': 'gte',
                'condicion_simbolo': '>=',
                'objetivo_anual': 1200.0,
                'resultado_acumulado': 450.0,
                'progreso_pct': 37.5,
                'progreso_esperado_pct': 30.0,
                'semaforo': 'verde',
              },
            ],
          },
          'ultimo_cargado': {
            'kpi_id': 1,
            'codigo': 'BULTOS_ENT',
            'nombre': 'Bultos entregados',
            'unidad': 'bultos',
            'tipo_acumulacion': 'suma',
            'objetivo_anual': 1200.0,
            'objetivo_periodo': 98.6,
            'resultado': 38.0,
            'valor': 38.0,
            'progreso_pct': 38.5,
            'semaforo': 'verde',
            'fecha_resultado': '2026-04-30',
            'cargado_at': '2026-05-01T08:15:00',
          },
          'meses_cerrados': [
            {
              'periodo': '2026-04',
              'periodo_year': 2026,
              'periodo_month': 4,
              'mes_nombre': 'Abril',
              'desde': '2026-04-01',
              'hasta': '2026-04-30',
              'cerrado': true,
              'resumen': {
                'total': 1,
                'verde': 1,
                'amarillo': 0,
                'rojo': 0,
                'gris': 0,
              },
              'kpis': [
                {
                  'kpi_id': 1,
                  'codigo': 'BULTOS_ENT',
                  'nombre': 'Bultos entregados',
                  'unidad': 'bultos',
                  'tipo_acumulacion': 'suma',
                  'mayor_es_mejor': true,
                  'condicion': 'gte',
                  'condicion_simbolo': '>=',
                  'objetivo_anual': 1200.0,
                  'objetivo_mes': 98.6,
                  'resultado_mes': 120.0,
                  'progreso_pct': 121.7,
                  'semaforo': 'verde',
                  'registros': 20,
                  'fecha_ultimo_resultado': '2026-04-30',
                },
              ],
            },
          ],
          'meta': {'limit_meses': 3},
        },
        inspect: (request) {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/mobile/me/kpis-sector/resumen');
          expect(request.url.queryParameters['anio'], '2026');
          expect(request.url.queryParameters['limit_meses'], '3');
          expect(request.headers['Authorization'], 'Bearer abc');
        },
      ),
    ]);

    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: client,
    );

    final result = await apiClient.getKpisSectorResumen(
      token: 'abc',
      anio: 2026,
      limitMeses: 3,
    );

    expect(result.anio, 2026);
    expect(result.sector.nombre, 'Entrega');
    expect(result.kpis.single.codigo, 'BULTOS_ENT');
    expect(result.ultimoCargado?.resultado, 38.0);
    expect(result.ultimoCargado?.fechaResultado, '2026-04-30');
    expect(result.mesesCerrados.single.resumen.verde, 1);
    expect(result.historyFor(1).single.resultadoMes, 120.0);
    expect(result.limitMeses, 3);
    apiClient.dispose();
  });

  test(
    'marcarTodasNotificacionesTriviaLeidas POST al endpoint correcto',
    () async {
      final client = _QueuedClient([
        _QueuedReply(
          statusCode: 200,
          body: const <String, dynamic>{'ok': true},
          inspect: (request) {
            expect(request.method, 'POST');
            expect(
              request.url.path,
              '/api/v1/trivia/notificaciones/leer-todas',
            );
            expect(request.headers['Authorization'], 'Bearer my-token');
          },
        ),
      ]);

      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: client,
      );

      await apiClient.marcarTodasNotificacionesTriviaLeidas(token: 'my-token');

      expect(client.callCount, 1);
      apiClient.dispose();
    },
  );

  test('feedback usa endpoints complementarios y parsea respuestas', () async {
    final client = _QueuedClient([
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{
          'resumen': {'total': 2, 'pendientes': 1, 'resueltos': 1},
          'top_motivos': [
            {'motivo_id': 1, 'motivo_nombre': 'Entrega', 'total': 2},
          ],
          'ranking': [
            {
              'empleado_id': 7,
              'legajo': '1020',
              'apellido': 'Perez',
              'nombre': 'Ana',
              'total': 2,
            },
          ],
          'personal': {
            'empleado_id': 7,
            'total_cargados': 2,
            'posicion_ranking': 1,
          },
          'totales': {'empleados_activos': 10, 'empleados_con_carga': 3},
          'empleado': {'id': 7, 'nombre': 'Ana', 'apellido': 'Perez'},
        },
        inspect: (request) {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/feedback/dashboard');
          expect(request.headers['Authorization'], 'Bearer abc');
        },
      ),
      _QueuedReply(
        statusCode: 201,
        body: const <String, dynamic>{
          'ok': true,
          'feedback': {
            'id': 123,
            'estado': 'pendiente',
            'estado_actual': 'pendiente',
            'cliente': {'id': 55, 'nombre_fantasia': 'Cliente Centro'},
            'motivo': {'id': 1, 'nombre': 'Entrega'},
          },
        },
        inspect: (request) {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/feedback');
          final body = jsonDecode((request as http.Request).body) as Map;
          expect(body['cliente_id'], 55);
          expect(body['motivo_id'], 1);
          expect(body['descripcion'], 'Falta producto');
        },
      ),
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{
          'items': [
            {'id': 124, 'estado': 'en_proceso'},
          ],
          'page': 2,
          'per_page': 10,
          'total': 11,
        },
        inspect: (request) {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/feedback/bandeja');
          expect(request.url.queryParameters['page'], '2');
          expect(request.url.queryParameters['per_page'], '10');
          expect(request.url.queryParameters['estado'], 'pendiente');
          expect(request.url.queryParameters['q'], 'cliente');
        },
      ),
    ]);

    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: client,
    );

    final FeedbackDashboardResponse dashboard = await apiClient
        .getFeedbackDashboard(token: 'abc');
    expect(dashboard.resumen.total, 2);
    expect(dashboard.topMotivos.single.motivoNombre, 'Entrega');
    expect(dashboard.ranking.single.displayName, 'Perez Ana - Legajo 1020');

    final FeedbackItem created = await apiClient.createFeedback(
      token: 'abc',
      clienteId: 55,
      motivoId: 1,
      descripcion: '  Falta producto  ',
    );
    expect(created.id, 123);
    expect(created.cliente?.displayName, 'Cliente Centro');

    final FeedbackListResponse bandeja = await apiClient.getFeedbackBandeja(
      token: 'abc',
      page: 2,
      perPage: 10,
      estado: 'pendiente',
      q: 'cliente',
    );
    expect(bandeja.items.single.id, 124);
    expect(bandeja.page, 2);
    expect(bandeja.perPage, 10);
    expect(bandeja.total, 11);
    expect(client.callCount, 3);
    apiClient.dispose();
  });

  test('skap usa envelope data y ranking embebido de mi desarrollo', () async {
    final client = _QueuedClient([
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{
          'success': true,
          'data': {
            'empleado': {
              'id': 7,
              'legajo': '1020',
              'dni': '30111222',
              'nombre': 'Ana Perez',
            },
            'anio_evaluado': 2026,
            'evaluacion': {
              'id': 77,
              'anio': 2026,
              'promedios': {'general': 4.1},
              'nivel': 'Destacado',
            },
            'categoria_cards': [
              {
                'categoria': 'S',
                'label': 'Skills',
                'promedio': 4.2,
                'esperado': 4.0,
                'nivel': 'Destacado',
                'respuestas': 5,
              },
            ],
            'historial': [],
            'plan': {
              'id': 30,
              'anio': 2026,
              'acciones': [],
              'avance_pct': 50.0,
            },
            'ranking': {'posicion': 3, 'total': 25, 'puntaje': 4.1},
            'badge': 'Plata',
          },
        },
        inspect: (request) {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/skap/mi_desarrollo');
          expect(request.url.queryParameters['anio'], '2026');
        },
      ),
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{
          'success': true,
          'data': {
            'sector_id': 3,
            'items': [
              {
                'id': 10,
                'sector_id': 3,
                'sector_nombre': 'Ventas',
                'categoria': 'S',
                'categoria_label': 'Skills',
                'descripcion': 'Gestiona objeciones.',
                'peso': 1.0,
                'puntaje_esperado': 4.0,
                'requiere_observacion': false,
                'requiere_evidencia': false,
              },
            ],
            'total': 1,
          },
        },
        inspect: (request) {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/skap/preguntas');
          expect(request.url.queryParameters['sector_id'], '3');
          expect(request.url.queryParameters['empleado_id'], '7');
          expect(request.url.queryParameters['categoria'], 'S');
          expect(request.url.queryParameters['activo'], '1');
        },
      ),
    ]);

    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: client,
    );

    final SkapMiDesarrolloResponse desarrollo = await apiClient
        .getSkapMiDesarrollo(token: 'abc', anio: 2026);
    expect(desarrollo.empleado.displayName, 'Ana Perez - Legajo 1020');
    expect(desarrollo.anioEvaluado, 2026);
    expect(desarrollo.ranking?.posicion, 3);
    expect(desarrollo.ranking?.puntaje, 4.1);
    expect(desarrollo.plan?.avancePct, 50.0);

    final SkapPreguntasResponse preguntas = await apiClient.getSkapPreguntas(
      token: 'abc',
      sectorId: 3,
      empleadoId: 7,
      categoria: 'S',
      activo: true,
    );
    expect(preguntas.sectorId, 3);
    expect(preguntas.items.single.descripcion, 'Gestiona objeciones.');
    expect(preguntas.items.single.requiereEvidencia, isFalse);
    expect(client.callCount, 2);
    apiClient.dispose();
  });
}

class _QueuedClient extends http.BaseClient {
  _QueuedClient(this.replies);

  final List<_QueuedReply> replies;
  int callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (callCount >= replies.length) {
      throw StateError(
        'No hay respuesta preparada para ${request.method} ${request.url}',
      );
    }
    final reply = replies[callCount];
    callCount += 1;
    reply.inspect?.call(request);
    final bytes = utf8.encode(jsonEncode(reply.body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      reply.statusCode,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

class _QueuedReply {
  const _QueuedReply({
    required this.statusCode,
    required this.body,
    this.inspect,
  });

  final int statusCode;
  final Map<String, dynamic> body;
  final void Function(http.BaseRequest request)? inspect;
}
