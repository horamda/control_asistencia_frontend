import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/justificaciones_page.dart';

void main() {
  testWidgets(
    'la edicion carga el detalle completo y muestra adjuntos reales',
    (WidgetTester tester) async {
      final client = _JustificacionesTestClient();

      final apiClient = MobileApiClient(
        baseUrl: 'https://example.com',
        httpClient: client,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JustificacionesPage(apiClient: apiClient, token: 'abc'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Justificación #10'), findsOneWidget);
      await tester.tap(find.text('Justificación #10'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(client.detailRequested, isTrue);

      apiClient.dispose();
    },
  );
}

class _JustificacionesTestClient extends http.BaseClient {
  bool _listServed = false;
  final Set<String> _countStatesServed = <String>{};
  bool _detailServed = false;

  bool get detailRequested => _detailServed;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') {
      throw StateError('Metodo inesperado: ${request.method}');
    }

    if (request.url.path == '/api/v1/mobile/me/justificaciones/10') {
      if (_detailServed) {
        throw StateError('Detalle solicitado mas de una vez.');
      }
      _detailServed = true;
      return _jsonResponse(const <String, dynamic>{
        'id': 10,
        'asistencia_id': null,
        'asistencia_fecha': null,
        'motivo': 'Enfermo',
        'archivo': null,
        'legajo_evento_id': 99,
        'adjuntos_count': 1,
        'adjuntos': const <Map<String, dynamic>>[
          {
            'id': 88,
            'evento_id': 99,
            'nombre_original': 'certificado.pdf',
            'mime_type': 'application/pdf',
            'extension': 'pdf',
            'tamano_bytes': 1234,
            'estado': 'activo',
            'created_at': '2026-06-08T18:06:51',
            'download_url': '/api/v1/mobile/me/justificaciones/10/adjuntos/88',
          },
        ],
        'estado': 'pendiente',
        'created_at': '2026-06-08T18:06:51',
      });
    }

    if (request.url.path == '/api/v1/mobile/me/justificaciones') {
      final estado = request.url.queryParameters['estado'];
      if (estado == null || estado.trim().isEmpty) {
        if (_listServed) {
          throw StateError('Listado principal solicitado mas de una vez.');
        }
        _listServed = true;
        return _jsonResponse(const <String, dynamic>{
          'items': const <Map<String, dynamic>>[
            {
              'id': 10,
              'asistencia_id': null,
              'asistencia_fecha': null,
              'motivo': 'Enfermo',
              'archivo': null,
              'adjuntos_count': 1,
              'adjuntos': <Map<String, dynamic>>[],
              'estado': 'pendiente',
              'created_at': '2026-06-08T18:06:51',
            },
          ],
          'page': 1,
          'per_page': 20,
          'total': 1,
        });
      }

      if (_countStatesServed.contains(estado)) {
        throw StateError('Conteo para estado $estado solicitado mas de una vez.');
      }
      _countStatesServed.add(estado);
      final total = switch (estado) {
        'pendiente' => 1,
        'aprobada' => 0,
        'rechazada' => 0,
        _ => throw StateError('Estado inesperado: $estado'),
      };
      return _jsonResponse(<String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'per_page': 20,
        'total': total,
      });
    }

    throw StateError('Ruta inesperada: ${request.method} ${request.url}');
  }

  Future<http.StreamedResponse> _jsonResponse(Map<String, dynamic> body) async {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}
