import 'package:ficharqr/src/core/network/feedback_api_models.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/feedback_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filters visible clients while typing', (tester) async {
    final apiClient = _FakeFeedbackApiClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: FeedbackCreateSheet(apiClient: apiClient, token: 'token'),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('OLIMPIADAS UNIVERSITARIAS'), findsAtLeastNWidgets(1));
    expect(find.text('ALFA LOGISTICA'), findsAtLeastNWidgets(1));

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Buscar cliente',
    );

    await tester.enterText(searchField, 'olim');
    await tester.pumpAndSettle();

    expect(find.text('OLIMPIADAS UNIVERSITARIAS'), findsAtLeastNWidgets(1));
    expect(find.text('ALFA LOGISTICA'), findsNothing);
  });

  testWidgets('falls back to remote search outside the local cache', (
    tester,
  ) async {
    final apiClient = _FakeFeedbackApiClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: FeedbackCreateSheet(apiClient: apiClient, token: 'token'),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Buscar cliente',
    );

    await tester.enterText(searchField, 'delta');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('CLIENTE DELTA'), findsWidgets);
  });

  testWidgets('searches clients by number while typing', (tester) async {
    final apiClient = _FakeFeedbackApiClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: FeedbackCreateSheet(apiClient: apiClient, token: 'token'),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Buscar cliente',
    );

    await tester.enterText(searchField, '55');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('NUMERO CINCUENTA Y CINCO'), findsWidgets);
  });

  testWidgets('clears stale selected client when the search has no matches', (
    tester,
  ) async {
    final apiClient = _FakeFeedbackApiClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: FeedbackCreateSheet(apiClient: apiClient, token: 'token'),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('OLIMPIADAS UNIVERSITARIAS'), findsAtLeastNWidgets(1));

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Buscar cliente',
    );

    await tester.enterText(searchField, 'super');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No se encontraron clientes para "super"'),
      findsOneWidget,
    );
    expect(find.text('OLIMPIADAS UNIVERSITARIAS'), findsNothing);
  });
}

class _FakeFeedbackApiClient extends MobileApiClient {
  _FakeFeedbackApiClient() : super(baseUrl: 'https://example.com');

  @override
  void dispose() {}

  @override
  Future<FeedbackMotivosResponse> getFeedbackMotivos({
    required String token,
  }) async {
    return const FeedbackMotivosResponse(
      items: [
        FeedbackMotivo(id: 1, nombre: 'Seguridad', descripcion: 'Seguridad'),
      ],
      total: 1,
    );
  }

  @override
  Future<FeedbackClientesResponse> getFeedbackClientes({
    required String token,
    String? q,
    int page = 1,
    int perPage = 20,
  }) async {
    final query = (q ?? '').trim().toLowerCase();
    if (query == 'super') {
      return const FeedbackClientesResponse(
        items: [],
        page: 1,
        perPage: 20,
        total: 0,
      );
    }
    if (query == 'delta') {
      return const FeedbackClientesResponse(
        items: [
          FeedbackCliente(
            id: 11,
            nombreFantasia: 'CLIENTE DELTA',
            razonSocial: 'CLIENTE DELTA SA',
            codigo: 'DEL-002',
            tipo: 'Cliente',
          ),
        ],
        page: 1,
        perPage: 20,
        total: 1,
      );
    }
    if (query == '55') {
      return const FeedbackClientesResponse(
        items: [
          FeedbackCliente(
            id: 55,
            nombreFantasia: 'NUMERO CINCUENTA Y CINCO',
            razonSocial: 'CLIENTE 55 SA',
            codigo: '55',
            tipo: 'Cliente',
          ),
        ],
        page: 1,
        perPage: 20,
        total: 1,
      );
    }
    return const FeedbackClientesResponse(
      items: [
        FeedbackCliente(
          id: 10,
          nombreFantasia: 'OLIMPIADAS UNIVERSITARIAS',
          razonSocial: 'OLIMPIADAS UNIVERSITARIAS SA',
          codigo: 'OLI-001',
          tipo: 'Cliente',
        ),
        FeedbackCliente(
          id: 12,
          nombreFantasia: 'ALFA LOGISTICA',
          razonSocial: 'ALFA LOGISTICA SRL',
          codigo: 'ALF-002',
          tipo: 'Cliente',
        ),
      ],
      page: 1,
      perPage: 20,
      total: 2,
    );
  }
}
