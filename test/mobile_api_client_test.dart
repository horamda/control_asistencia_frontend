import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ficharqr/src/core/network/mobile_api_client.dart';

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
