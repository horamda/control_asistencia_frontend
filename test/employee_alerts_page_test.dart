import 'package:ficharqr/src/core/network/feedback_api_models.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/attendance/employee_alerts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ficharqr/src/core/alerts/employee_alerts_read_state.dart';
import 'package:ficharqr/src/core/alerts/employee_alerts_repository.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'reading survives duplicate summary records and reordered feedback',
    () async {
      final api = _FakeAlertsApiClient();
      final initial = await EmployeeAlertsRepository(
        api,
      ).loadDetails(token: 'token');
      final state = EmployeeAlertsReadState(server: api.baseUrl, employeeId: 1);
      final other = FeedbackItem(
        id: 45,
        estado: 'pendiente',
        updatedAt: '2026-06-15T10:00:00',
      );
      EmployeeAlertsSnapshot snapshot({required bool reversed}) =>
          EmployeeAlertsSnapshot(
            adelantos: AdelantoResumenResponse(
              periodo: '2026-06',
              periodoYear: 2026,
              periodoMonth: 6,
              yaSolicitado: true,
              totalHistorial: 1,
              pendientesTotal: 0,
              adelantoMesActual: initial.adelantos!.adelantoMesActual,
              ultimoAdelanto: reversed
                  ? initial.adelantos!.adelantoMesActual
                  : null,
            ),
            adelantosError: null,
            mercaderia: initial.mercaderia,
            mercaderiaError: null,
            feedbackDashboard: initial.feedbackDashboard,
            feedbackError: null,
            feedbackRecent: reversed
                ? [other, ...initial.feedbackRecent]
                : [...initial.feedbackRecent, other],
          );
      await state.markViewed(snapshot(reversed: false));
      expect(await state.unreadCount(snapshot(reversed: true)), 0);
    },
  );
  test('viewed modules persist and new status changes become unread', () async {
    final api = _FakeAlertsApiClient();
    final repo = EmployeeAlertsRepository(api);
    final state = EmployeeAlertsReadState(server: api.baseUrl, employeeId: 1);
    final initial = await repo.loadDetails(token: 'token');
    expect(await state.unreadCount(initial), 3);
    await state.markViewed(initial);
    final reopened = EmployeeAlertsReadState(
      server: api.baseUrl,
      employeeId: 1,
    );
    expect(
      await reopened.unreadCount(await repo.loadDetails(token: 'new-token')),
      0,
    );
    expect(
      await EmployeeAlertsReadState(
        server: api.baseUrl,
        employeeId: 2,
      ).unreadCount(initial),
      3,
    );
    api.advanceState = 'rechazado';
    expect(
      await reopened.unreadCount(await repo.loadDetails(token: 'token')),
      1,
    );
  });

  testWidgets('mark viewed clears badge without resolving requests', (
    tester,
  ) async {
    final api = _FakeAlertsApiClient();
    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeAlertsPage(apiClient: api, token: 'token', employeeId: 1),
      ),
    );
    await tester.pumpAndSettle();
    final mark = find.text('Marcar como vistas');
    await tester.ensureVisible(mark);
    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(find.text('Sin novedades pendientes'), findsOneWidget);
    expect(find.text('Adelantos'), findsNothing);
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('Sin novedades pendientes'), findsOneWidget);
    expect(find.text('Adelantos'), findsNothing);
    await tester.tap(find.text('Ver vistas'));
    await tester.pumpAndSettle();
    expect(find.text('Adelantos'), findsOneWidget);
    await tester.tap(find.text('Ver pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('Adelantos'), findsNothing);
    api.advanceState = 'rechazado';
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('Adelantos'), findsOneWidget);
    expect(find.text('Mercadería'), findsNothing);
    expect(find.text('Marcar como vistas'), findsOneWidget);
    final snapshot = await EmployeeAlertsRepository(
      api,
    ).loadDetails(token: 'token');
    expect(snapshot.mercaderia!.pedidoMesActual!.estado, 'en_proceso');
    expect(tester.takeException(), isNull);
  });
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
  String advanceState = 'aprobado';

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
        estado: advanceState,
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
