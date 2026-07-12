import '../network/feedback_api_models.dart';
import '../network/mobile_api_client.dart';

class EmployeeAlertsSnapshot {
  const EmployeeAlertsSnapshot({
    required this.adelantos,
    required this.adelantosError,
    required this.mercaderia,
    required this.mercaderiaError,
    required this.feedbackDashboard,
    required this.feedbackError,
    this.feedbackRecent = const <FeedbackItem>[],
  });

  final AdelantoResumenResponse? adelantos;
  final String? adelantosError;
  final PedidoMercaderiaResumenResponse? mercaderia;
  final String? mercaderiaError;
  final FeedbackDashboardResponse? feedbackDashboard;
  final String? feedbackError;
  final List<FeedbackItem> feedbackRecent;

  int get activeCount => countEmployeeAlerts(
    adelantos: adelantos,
    mercaderia: mercaderia,
    feedbackDashboard: feedbackDashboard,
  );

  bool get hasAnyError =>
      adelantosError != null ||
      mercaderiaError != null ||
      feedbackError != null;
}

int countEmployeeAlerts({
  AdelantoResumenResponse? adelantos,
  PedidoMercaderiaResumenResponse? mercaderia,
  FeedbackDashboardResponse? feedbackDashboard,
}) {
  var count = 0;

  if (_hasAdelantoSignal(adelantos)) {
    count++;
  }
  if (_hasMercaderiaSignal(mercaderia)) {
    count++;
  }
  final summary = feedbackDashboard?.resumen;
  if (summary != null) {
    count += (summary.pendientes ?? 0);
    count += (summary.enProceso ?? 0);
    count += (summary.vencidos ?? 0);
  }

  return count.clamp(0, 99).toInt();
}

bool _hasAdelantoSignal(AdelantoResumenResponse? data) {
  return data?.adelantoMesActual != null || data?.ultimoAdelanto != null;
}

bool _hasMercaderiaSignal(PedidoMercaderiaResumenResponse? data) {
  return data?.pedidoMesActual != null ||
      data?.ultimoPedido != null ||
      data?.ultimoPedidoAprobado != null;
}

class EmployeeAlertsRepository {
  const EmployeeAlertsRepository(this.apiClient);

  final MobileApiClient apiClient;

  Future<EmployeeAlertsSnapshot> loadOverview({required String token}) async {
    final adelantosFuture = _loadAdelantos(token);
    final mercaderiaFuture = _loadMercaderia(token);
    final feedbackDashboardFuture = _loadFeedbackDashboard(token);

    final adelantos = await adelantosFuture;
    final mercaderia = await mercaderiaFuture;
    final feedbackDashboard = await feedbackDashboardFuture;

    return EmployeeAlertsSnapshot(
      adelantos: adelantos.value,
      adelantosError: adelantos.error,
      mercaderia: mercaderia.value,
      mercaderiaError: mercaderia.error,
      feedbackDashboard: feedbackDashboard.value,
      feedbackError: feedbackDashboard.error,
    );
  }

  Future<EmployeeAlertsSnapshot> loadDetails({required String token}) async {
    final adelantosFuture = _loadAdelantos(token);
    final mercaderiaFuture = _loadMercaderia(token);
    final feedbackDashboardFuture = _loadFeedbackDashboard(token);
    final feedbackRecentFuture = _loadFeedbackRecent(token);

    final adelantos = await adelantosFuture;
    final mercaderia = await mercaderiaFuture;
    final feedbackDashboard = await feedbackDashboardFuture;
    final feedbackRecent = await feedbackRecentFuture;

    return EmployeeAlertsSnapshot(
      adelantos: adelantos.value,
      adelantosError: adelantos.error,
      mercaderia: mercaderia.value,
      mercaderiaError: mercaderia.error,
      feedbackDashboard: feedbackDashboard.value,
      feedbackError: feedbackDashboard.error,
      feedbackRecent: feedbackRecent.value ?? const <FeedbackItem>[],
    );
  }

  Future<_LoadResult<AdelantoResumenResponse>> _loadAdelantos(
    String token,
  ) async {
    return _guard(
      () => apiClient.getAdelantoResumen(token: token),
      fallback: 'No se pudieron cargar las alertas de adelantos.',
    );
  }

  Future<_LoadResult<PedidoMercaderiaResumenResponse>> _loadMercaderia(
    String token,
  ) async {
    return _guard(
      () => apiClient.getPedidosMercaderiaResumen(token: token),
      fallback: 'No se pudieron cargar las alertas de mercaderia.',
    );
  }

  Future<_LoadResult<FeedbackDashboardResponse>> _loadFeedbackDashboard(
    String token,
  ) async {
    return _guard(
      () => apiClient.getFeedbackDashboard(token: token),
      fallback: 'No se pudieron cargar las alertas de feedback.',
    );
  }

  Future<_LoadResult<List<FeedbackItem>>> _loadFeedbackRecent(
    String token,
  ) async {
    return _guard(() async {
      final historial = await apiClient.getFeedbackHistorial(
        token: token,
        page: 1,
        perPage: 5,
      );
      final recent = [...historial.items];
      recent.sort(_compareFeedbackByUpdatedAt);
      return recent;
    }, fallback: 'No se pudo cargar el historial reciente de feedback.');
  }

  Future<_LoadResult<T>> _guard<T>(
    Future<T> Function() loader, {
    required String fallback,
  }) async {
    try {
      return _LoadResult.success(await loader());
    } on ApiException catch (e) {
      return _LoadResult.failure(_fallbackMessage(e.message, fallback));
    } catch (_) {
      return _LoadResult.failure(fallback);
    }
  }
}

String _fallbackMessage(String? message, String fallback) {
  final value = message?.trim();
  return value == null || value.isEmpty ? fallback : value;
}

int _compareFeedbackByUpdatedAt(FeedbackItem left, FeedbackItem right) {
  final leftAt =
      _parseDateTime(left.updatedAt ?? left.resueltoAt ?? left.createdAt) ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final rightAt =
      _parseDateTime(right.updatedAt ?? right.resueltoAt ?? right.createdAt) ??
      DateTime.fromMillisecondsSinceEpoch(0);
  return rightAt.compareTo(leftAt);
}

DateTime? _parseDateTime(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

class _LoadResult<T> {
  const _LoadResult.success(this.value) : error = null;
  const _LoadResult.failure(this.error) : value = null;

  final T? value;
  final String? error;
}
