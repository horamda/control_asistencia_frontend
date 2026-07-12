import 'package:ficharqr/src/core/network/feedback_api_models.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/employee_alerts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders employee alerts overview and recent changes', (
    tester,
  ) async {
    final apiClient = _FakeAlertsApiClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: EmployeeAlertsPage(apiClient: apiClient, token: 'token'),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Alertas'), findsOneWidget);
    expect(find.textContaining('Novedades del empleado'), findsOneWidget);
    expect(find.textContaining('Adelantos'), findsWidgets);
    expect(find.textContaining('Mercader'), findsWidgets);

    await tester.scrollUntilVisible(
      find.textContaining('Falta revisar el reclamo'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Cliente Uno'), findsWidgets);
    expect(find.textContaining('Falta revisar el reclamo'), findsWidgets);
  });
}

class _FakeAlertsApiClient extends MobileApiClient {
  _FakeAlertsApiClient() : super(baseUrl: 'https://example.com');

  @override
  void dispose() {}

  @override
  Future<AdelantoResumenResponse> getAdelantoResumen({
    required String token,
  }) async {
    return AdelantoResumenResponse(
      periodo: '2026-06',
      periodoYear: 2026,
      periodoMonth: 6,
      yaSolicitado: true,
      totalHistorial: 1,
      pendientesTotal: 1,
      adelantoMesActual: AdelantoItem(
        id: 10,
        periodo: 'Junio 2026',
        periodoYear: 2026,
        periodoMonth: 6,
        fechaSolicitud: '2026-06-15',
        estado: 'aprobado',
        createdAt: '2026-06-15T09:00:00',
        resueltoAt: '2026-06-16T10:00:00',
        resueltoPor: 'RRHH',
      ),
      ultimoAdelanto: null,
    );
  }

  @override
  Future<PedidoMercaderiaResumenResponse> getPedidosMercaderiaResumen({
    required String token,
  }) async {
    return PedidoMercaderiaResumenResponse(
      periodo: '2026-06',
      periodoYear: 2026,
      periodoMonth: 6,
      yaSolicitado: true,
      totalHistorial: 3,
      historialAprobadosTotal: 2,
      pendientesTotal: 1,
      pedidoMesActual: PedidoMercaderiaItem(
        id: 20,
        estado: 'en_proceso',
        fechaPedido: '2026-06-14',
        createdAt: '2026-06-14T08:00:00',
        items: const <PedidoMercaderiaItemLinea>[],
      ),
      ultimoPedido: null,
      ultimoPedidoAprobado: PedidoMercaderiaItem(
        id: 21,
        estado: 'aprobado',
        fechaPedido: '2026-06-10',
        createdAt: '2026-06-10T08:00:00',
        resueltaAt: '2026-06-11T12:00:00',
        resueltoByUsuario: 'Compras',
        items: const <PedidoMercaderiaItemLinea>[],
      ),
    );
  }

  @override
  Future<FeedbackDashboardResponse> getFeedbackDashboard({
    required String token,
  }) async {
    return const FeedbackDashboardResponse(
      resumen: FeedbackDashboardSummary(
        total: 4,
        resueltos: 1,
        pendientes: 2,
        enProceso: 1,
        vencidos: 1,
        resueltosEnSla: 1,
        resueltosFueraSla: 0,
        motivosDistintos: 1,
        clientesDistintos: 1,
        empleadosConCarga: 1,
      ),
      topMotivos: <FeedbackTopMotivo>[],
      ranking: <FeedbackRankingItem>[],
      personal: null,
      totales: FeedbackTotals(empleadosActivos: 1, empleadosConCarga: 1),
      empleado: null,
    );
  }

  @override
  Future<FeedbackListResponse> getFeedbackHistorial({
    required String token,
    int page = 1,
    int perPage = 20,
    String? estado,
    String? q,
  }) async {
    return FeedbackListResponse(
      items: [
        FeedbackItem(
          id: 44,
          estado: 'pendiente',
          estadoActual: 'pendiente',
          descripcion: 'Falta revisar el reclamo',
          createdAt: '2026-06-15T09:30:00',
          updatedAt: '2026-06-15T10:00:00',
          cliente: const FeedbackCliente(nombreFantasia: 'Cliente Uno'),
        ),
      ],
      page: page,
      perPage: perPage,
      total: 1,
    );
  }
}
