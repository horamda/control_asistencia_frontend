import 'dart:convert';

import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/kpis_sector_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets('KpisSectorPage cae al endpoint anterior si falla resumen', (
    tester,
  ) async {
    final client = _QueuedClient([
      _QueuedReply(
        statusCode: 500,
        body: const <String, dynamic>{'error': 'summary failed'},
        inspect: (request) {
          expect(request.url.path, '/api/v1/mobile/me/kpis-sector/resumen');
        },
      ),
      _QueuedReply(
        statusCode: 200,
        body: const <String, dynamic>{
          'anio': 2026,
          'sector': {'id': 3, 'nombre': 'Entrega'},
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
        inspect: (request) {
          expect(request.url.path, '/api/v1/mobile/me/kpis-sector');
        },
      ),
    ]);
    final apiClient = MobileApiClient(
      baseUrl: 'https://example.com',
      httpClient: client,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KpisSectorPage(apiClient: apiClient, token: 'abc'),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.callCount, 2);
    expect(find.text('Entrega'), findsOneWidget);
    expect(find.text('Bultos entregados'), findsOneWidget);
    expect(find.textContaining('summary failed'), findsNothing);
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
