import 'package:ficharqr/src/core/alerts/employee_alerts_repository.dart';
import 'package:ficharqr/src/core/network/feedback_api_models.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmployeeAlertsRepository helpers', () {
    test('counts active signals across adelantos, mercaderia and feedback', () {
      final adelantos = AdelantoResumenResponse(
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
          estado: 'pendiente',
        ),
        ultimoAdelanto: null,
      );

      final mercaderia = PedidoMercaderiaResumenResponse(
        periodo: '2026-06',
        periodoYear: 2026,
        periodoMonth: 6,
        yaSolicitado: true,
        totalHistorial: 2,
        historialAprobadosTotal: 1,
        pendientesTotal: 1,
        pedidoMesActual: PedidoMercaderiaItem(
          id: 20,
          estado: 'aprobado',
          items: const <PedidoMercaderiaItemLinea>[],
        ),
        ultimoPedido: null,
        ultimoPedidoAprobado: null,
      );

      final feedbackDashboard = FeedbackDashboardResponse(
        resumen: const FeedbackDashboardSummary(
          total: 8,
          resueltos: 2,
          pendientes: 3,
          enProceso: 1,
          vencidos: 2,
          resueltosEnSla: 1,
          resueltosFueraSla: 1,
          motivosDistintos: 0,
          clientesDistintos: 0,
          empleadosConCarga: 0,
        ),
        topMotivos: const <FeedbackTopMotivo>[],
        ranking: const <FeedbackRankingItem>[],
        personal: null,
        totales: const FeedbackTotals(),
        empleado: null,
      );

      expect(
        countEmployeeAlerts(
          adelantos: adelantos,
          mercaderia: mercaderia,
          feedbackDashboard: feedbackDashboard,
        ),
        8,
      );

      expect(
        EmployeeAlertsSnapshot(
          adelantos: adelantos,
          adelantosError: null,
          mercaderia: mercaderia,
          mercaderiaError: null,
          feedbackDashboard: feedbackDashboard,
          feedbackError: null,
        ).activeCount,
        8,
      );
    });

    test('returns zero when there are no alert sources', () {
      expect(countEmployeeAlerts(), 0);
    });
  });
}
