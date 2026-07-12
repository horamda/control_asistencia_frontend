import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/alerts/employee_alerts_repository.dart';
import '../../core/network/feedback_api_models.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/utils/date_formatter.dart';
import 'adelantos_page.dart';
import 'feedback_page.dart';
import 'pedidos_mercaderia_page.dart';

class EmployeeAlertsPage extends StatefulWidget {
  const EmployeeAlertsPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<EmployeeAlertsPage> createState() => _EmployeeAlertsPageState();
}

class _EmployeeAlertsPageState extends State<EmployeeAlertsPage> {
  late final EmployeeAlertsRepository _alertsRepository;

  bool _loading = true;
  String? _adelantosError;
  String? _mercaderiaError;
  String? _feedbackError;

  AdelantoResumenResponse? _adelantos;
  PedidoMercaderiaResumenResponse? _mercaderia;
  FeedbackDashboardResponse? _feedbackDashboard;
  List<FeedbackItem> _feedbackRecent = const [];

  @override
  void initState() {
    super.initState();
    _alertsRepository = EmployeeAlertsRepository(widget.apiClient);
    unawaited(_loadAll());
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _adelantosError = null;
      _mercaderiaError = null;
      _feedbackError = null;
    });

    final snapshot = await _alertsRepository.loadDetails(token: widget.token);

    if (mounted) {
      setState(() {
        _adelantos = snapshot.adelantos;
        _adelantosError = snapshot.adelantosError;
        _mercaderia = snapshot.mercaderia;
        _mercaderiaError = snapshot.mercaderiaError;
        _feedbackDashboard = snapshot.feedbackDashboard;
        _feedbackRecent = snapshot.feedbackRecent;
        _feedbackError = snapshot.feedbackError;
        _loading = false;
      });
    }
  }

  Future<void> _openAdelantos() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AdelantosPage(apiClient: widget.apiClient, token: widget.token),
      ),
    );
  }

  Future<void> _openMercaderia() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PedidosMercaderiaPage(
          apiClient: widget.apiClient,
          token: widget.token,
        ),
      ),
    );
  }

  Future<void> _openFeedback() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FeedbackPage(apiClient: widget.apiClient, token: widget.token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    final activeCount = _activeAlertsCount();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : () => unawaited(_loadAll()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _HeroCard(
                    activeCount: activeCount,
                    entriesCount: entries.length,
                  ),
                  const SizedBox(height: 12),
                  _ModuleSectionCard(
                    title: 'Adelantos',
                    icon: Icons.payments_outlined,
                    error: _adelantosError,
                    onOpen: _openAdelantos,
                    child: _buildAdelantosSection(),
                  ),
                  const SizedBox(height: 12),
                  _ModuleSectionCard(
                    title: 'Mercadería',
                    icon: Icons.inventory_2_outlined,
                    error: _mercaderiaError,
                    onOpen: _openMercaderia,
                    child: _buildMercaderiaSection(),
                  ),
                  const SizedBox(height: 12),
                  _ModuleSectionCard(
                    title: 'Feedback',
                    icon: Icons.campaign_outlined,
                    error: _feedbackError,
                    onOpen: _openFeedback,
                    child: _buildFeedbackSection(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cambios recientes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    const _EmptyStateCard(
                      icon: Icons.notifications_none_outlined,
                      title: 'Sin novedades',
                      subtitle:
                          'No hay aprobaciones, rechazos ni mensajes nuevos para mostrar.',
                    )
                  else
                    ...entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AlertEntryCard(entry: entry),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  int _activeAlertsCount() {
    return countEmployeeAlerts(
      adelantos: _adelantos,
      mercaderia: _mercaderia,
      feedbackDashboard: _feedbackDashboard,
    );
  }

  List<_AlertEntry> _buildEntries() {
    final entries = <_AlertEntry>[];

    final adelantos = _adelantos;
    if (adelantos != null) {
      final actual = adelantos.adelantoMesActual;
      final ultimo = adelantos.ultimoAdelanto;
      if (actual != null) {
        entries.add(
          _AlertEntry(
            module: 'Adelantos',
            title: _adelantoTitle(actual),
            statusLabel: _statusLabel(actual.estado),
            statusColor: _statusColor(actual.estado),
            icon: _statusIcon(actual.estado),
            message: _adelantoMessage(actual),
            details: _adelantoDetails(actual),
            timestamp: _parseDateTime(
              actual.resueltoAt ?? actual.fechaSolicitud ?? actual.createdAt,
            ),
          ),
        );
      } else if (ultimo != null) {
        entries.add(
          _AlertEntry(
            module: 'Adelantos',
            title: _adelantoTitle(ultimo),
            statusLabel: _statusLabel(ultimo.estado),
            statusColor: _statusColor(ultimo.estado),
            icon: _statusIcon(ultimo.estado),
            message: _adelantoMessage(ultimo),
            details: _adelantoDetails(ultimo),
            timestamp: _parseDateTime(ultimo.resueltoAt ?? ultimo.createdAt),
          ),
        );
      }
    }

    final mercaderia = _mercaderia;
    if (mercaderia != null) {
      final actual = mercaderia.pedidoMesActual;
      final ultimoAprobado = mercaderia.ultimoPedidoAprobado;
      final ultimo = mercaderia.ultimoPedido;
      if (actual != null) {
        entries.add(
          _AlertEntry(
            module: 'Mercadería',
            title: _pedidoTitle(actual),
            statusLabel: _statusLabel(actual.estado),
            statusColor: _statusColor(actual.estado),
            icon: _statusIcon(actual.estado),
            message: _pedidoMessage(actual),
            details: _pedidoDetails(actual),
            timestamp: _parseDateTime(
              actual.resueltaAt ?? actual.createdAt ?? actual.fechaPedido,
            ),
          ),
        );
      } else if (ultimo != null) {
        entries.add(
          _AlertEntry(
            module: 'Mercadería',
            title: _pedidoTitle(ultimo),
            statusLabel: _statusLabel(ultimo.estado),
            statusColor: _statusColor(ultimo.estado),
            icon: _statusIcon(ultimo.estado),
            message: _pedidoMessage(ultimo),
            details: _pedidoDetails(ultimo),
            timestamp: _parseDateTime(ultimo.resueltaAt ?? ultimo.createdAt),
          ),
        );
      }

      if (ultimoAprobado != null &&
          (actual == null || ultimoAprobado.id != actual.id)) {
        entries.add(
          _AlertEntry(
            module: 'Mercadería',
            title: 'Último pedido aprobado',
            statusLabel: 'Aprobado',
            statusColor: Colors.green.shade700,
            icon: Icons.check_circle_outline,
            message: _pedidoMessage(ultimoAprobado),
            details: _pedidoDetails(ultimoAprobado),
            timestamp: _parseDateTime(
              ultimoAprobado.resueltaAt ?? ultimoAprobado.createdAt,
            ),
          ),
        );
      }
    }

    final feedback = _feedbackDashboard;
    if (feedback != null) {
      final resumen = feedback.resumen;
      entries.add(
        _AlertEntry(
          module: 'Feedback',
          title: 'Resumen de feedback',
          statusLabel: _feedbackSummaryLabel(resumen),
          statusColor: _feedbackSummaryColor(resumen),
          icon: Icons.campaign_outlined,
          message: _feedbackSummaryMessage(resumen),
          details: _feedbackSummaryDetails(resumen),
          timestamp: _parseDateTime(_latestFeedbackTimestamp()),
        ),
      );
    }

    for (final item in _feedbackRecent.take(4)) {
      entries.add(
        _AlertEntry(
          module: 'Feedback',
          title: _feedbackTitle(item),
          statusLabel: _feedbackStatusLabel(item),
          statusColor: _feedbackStatusColor(item),
          icon: _feedbackStatusIcon(item),
          message: _feedbackMessage(item),
          details: _feedbackDetails(item),
          timestamp: _parseDateTime(
            item.updatedAt ?? item.resueltoAt ?? item.createdAt,
          ),
        ),
      );
    }

    entries.sort((a, b) {
      final left = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });

    return entries;
  }

  Widget _buildAdelantosSection() {
    final data = _adelantos;
    if (data == null) {
      return const _EmptyInline(
        text: 'No hay información de adelantos para mostrar.',
      );
    }

    final items = <Widget>[];
    if (data.adelantoMesActual != null) {
      items.add(
        _ModuleAlertTile(
          icon: _statusIcon(data.adelantoMesActual!.estado),
          color: _statusColor(data.adelantoMesActual!.estado),
          title: _adelantoTitle(data.adelantoMesActual!),
          statusLabel: _statusLabel(data.adelantoMesActual!.estado),
          message: _adelantoMessage(data.adelantoMesActual!),
          detail: _adelantoDetails(data.adelantoMesActual!),
        ),
      );
    } else if (data.ultimoAdelanto != null) {
      items.add(
        _ModuleAlertTile(
          icon: _statusIcon(data.ultimoAdelanto!.estado),
          color: _statusColor(data.ultimoAdelanto!.estado),
          title: _adelantoTitle(data.ultimoAdelanto!),
          statusLabel: _statusLabel(data.ultimoAdelanto!.estado),
          message: _adelantoMessage(data.ultimoAdelanto!),
          detail: _adelantoDetails(data.ultimoAdelanto!),
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const _EmptyInline(
          text: 'Todavía no hay adelantos cargados para este empleado.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricRow(
          items: [
            _MetricChip(label: 'Pendientes', value: data.pendientesTotal),
            _MetricChip(label: 'Historial', value: data.totalHistorial),
          ],
        ),
        const SizedBox(height: 12),
        ...items.expand((widget) => [widget, const SizedBox(height: 10)]),
      ],
    );
  }

  Widget _buildMercaderiaSection() {
    final data = _mercaderia;
    if (data == null) {
      return const _EmptyInline(
        text: 'No hay información de pedidos de mercaderia.',
      );
    }

    final items = <Widget>[];
    if (data.pedidoMesActual != null) {
      items.add(
        _ModuleAlertTile(
          icon: _statusIcon(data.pedidoMesActual!.estado),
          color: _statusColor(data.pedidoMesActual!.estado),
          title: _pedidoTitle(data.pedidoMesActual!),
          statusLabel: _statusLabel(data.pedidoMesActual!.estado),
          message: _pedidoMessage(data.pedidoMesActual!),
          detail: _pedidoDetails(data.pedidoMesActual!),
        ),
      );
    } else if (data.ultimoPedido != null) {
      items.add(
        _ModuleAlertTile(
          icon: _statusIcon(data.ultimoPedido!.estado),
          color: _statusColor(data.ultimoPedido!.estado),
          title: _pedidoTitle(data.ultimoPedido!),
          statusLabel: _statusLabel(data.ultimoPedido!.estado),
          message: _pedidoMessage(data.ultimoPedido!),
          detail: _pedidoDetails(data.ultimoPedido!),
        ),
      );
    }

    if (data.ultimoPedidoAprobado != null &&
        (data.pedidoMesActual == null ||
            data.ultimoPedidoAprobado!.id != data.pedidoMesActual!.id)) {
      items.add(
        _ModuleAlertTile(
          icon: Icons.check_circle_outline,
          color: Colors.green.shade700,
          title: 'Último pedido aprobado',
          statusLabel: 'Aprobado',
          message: _pedidoMessage(data.ultimoPedidoAprobado!),
          detail: _pedidoDetails(data.ultimoPedidoAprobado!),
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const _EmptyInline(
          text: 'Todavía no hay pedidos de mercaderia para mostrar.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricRow(
          items: [
            _MetricChip(label: 'Pendientes', value: data.pendientesTotal),
            _MetricChip(
              label: 'Aprobados',
              value: data.historialAprobadosTotal,
            ),
            _MetricChip(label: 'Historial', value: data.totalHistorial),
          ],
        ),
        const SizedBox(height: 12),
        ...items.expand((widget) => [widget, const SizedBox(height: 10)]),
      ],
    );
  }

  Widget _buildFeedbackSection() {
    final dashboard = _feedbackDashboard;
    if (dashboard == null) {
      return const _EmptyInline(
        text: 'No hay información de feedback para mostrar.',
      );
    }

    final resumen = dashboard.resumen;
    final recent = _feedbackRecent.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricRow(
          items: [
            _MetricChip(label: 'Pendientes', value: resumen.pendientes ?? 0),
            _MetricChip(label: 'En proceso', value: resumen.enProceso ?? 0),
            _MetricChip(label: 'Vencidos', value: resumen.vencidos ?? 0),
            _MetricChip(label: 'Resueltos', value: resumen.resueltos ?? 0),
          ],
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          const _EmptyInline(text: 'No hay feedback reciente para revisar.')
        else
          ...recent.expand(
            (item) => [
              _ModuleAlertTile(
                icon: _feedbackStatusIcon(item),
                color: _feedbackStatusColor(item),
                title: _feedbackTitle(item),
                statusLabel: _feedbackStatusLabel(item),
                message: _feedbackMessage(item),
                detail: _feedbackDetails(item),
              ),
              const SizedBox(height: 10),
            ],
          ),
      ],
    );
  }

  String _adelantoTitle(AdelantoItem item) {
    final periodo = item.periodo.trim().isNotEmpty
        ? item.periodo.trim()
        : _monthLabel(item.periodoMonth, item.periodoYear);
    return 'Adelanto $periodo';
  }

  String _adelantoMessage(AdelantoItem item) {
    return switch (_normalize(item.estado)) {
      'aprobado' => 'Tu solicitud fue aprobada y quedó lista para acreditarse.',
      'rechazado' =>
        'Tu solicitud fue rechazada. Revisá el motivo en el detalle.',
      'cancelado' => 'La solicitud fue cancelada.',
      'en_proceso' || 'en proceso' => 'Tu solicitud está siendo evaluada.',
      _ => 'Tu solicitud está pendiente de aprobación.',
    };
  }

  String _adelantoDetails(AdelantoItem item) {
    final parts = <String>[
      if (item.fechaSolicitud != null && item.fechaSolicitud!.trim().isNotEmpty)
        'Solicitado: ${DateFormatter.formatApiDateForDisplay(item.fechaSolicitud)}',
      if (item.resueltoAt != null && item.resueltoAt!.trim().isNotEmpty)
        'Resuelto: ${DateFormatter.formatApiDateForDisplay(item.resueltoAt)}',
      if (item.resueltoPor != null && item.resueltoPor!.trim().isNotEmpty)
        'Resuelto por ${item.resueltoPor!.trim()}',
    ];
    return parts.isEmpty ? 'Sin detalle adicional.' : parts.join(' • ');
  }

  String _pedidoTitle(PedidoMercaderiaItem item) {
    final periodo = item.periodo?.trim().isNotEmpty == true
        ? item.periodo!.trim()
        : _monthLabel(item.periodoMonth ?? 0, item.periodoYear ?? 0);
    return 'Pedido de mercadería $periodo';
  }

  String _pedidoMessage(PedidoMercaderiaItem item) {
    return switch (_normalize(item.estado)) {
      'aprobado' =>
        'Tu pedido fue aprobado y ya quedó registrado para entrega.',
      'rechazado' => 'Tu pedido fue rechazado. Revisá el motivo del rechazo.',
      'cancelado' => 'El pedido fue cancelado.',
      'en_proceso' || 'en proceso' => 'Tu pedido está siendo evaluado.',
      _ => 'Tu pedido está pendiente de aprobación.',
    };
  }

  String _pedidoDetails(PedidoMercaderiaItem item) {
    final parts = <String>[
      if (item.fechaPedido != null && item.fechaPedido!.trim().isNotEmpty)
        'Pedido: ${DateFormatter.formatApiDateForDisplay(item.fechaPedido)}',
      if (item.resueltaAt != null && item.resueltaAt!.trim().isNotEmpty)
        'Resuelto: ${DateFormatter.formatApiDateForDisplay(item.resueltaAt)}',
      if (item.resueltoByUsuario != null &&
          item.resueltoByUsuario!.trim().isNotEmpty)
        'Resuelto por ${item.resueltoByUsuario!.trim()}',
      if (item.motivoRechazo != null && item.motivoRechazo!.trim().isNotEmpty)
        'Motivo: ${item.motivoRechazo!.trim()}',
    ];
    return parts.isEmpty ? 'Sin detalle adicional.' : parts.join(' • ');
  }

  String _feedbackTitle(FeedbackItem item) {
    final cliente = item.cliente?.displayName.trim();
    if (cliente != null && cliente.isNotEmpty) {
      return 'Feedback para $cliente';
    }
    if (item.id != null && item.id! > 0) {
      return 'Feedback #${item.id}';
    }
    return 'Feedback';
  }

  String _feedbackMessage(FeedbackItem item) {
    final descripcion = item.descripcion?.trim();
    if (descripcion != null && descripcion.isNotEmpty) {
      return descripcion;
    }
    return switch (_normalize(item.estadoActual ?? item.estado)) {
      'resuelto' => 'El feedback ya fue resuelto.',
      'en_proceso' || 'en proceso' => 'El feedback está en proceso de gestión.',
      'vencido' => 'El feedback venció y requiere revisión.',
      _ => 'El feedback está pendiente de tratamiento.',
    };
  }

  String _feedbackDetails(FeedbackItem item) {
    final parts = <String>[
      if (item.createdAt != null && item.createdAt!.trim().isNotEmpty)
        'Creado: ${DateFormatter.formatApiDateForDisplay(item.createdAt)}',
      if (item.updatedAt != null && item.updatedAt!.trim().isNotEmpty)
        'Actualizado: ${DateFormatter.formatApiDateForDisplay(item.updatedAt)}',
      if (item.resueltoAt != null && item.resueltoAt!.trim().isNotEmpty)
        'Resuelto: ${DateFormatter.formatApiDateForDisplay(item.resueltoAt)}',
      if (item.resueltoPor?.displayName.trim().isNotEmpty == true)
        'Resuelto por ${item.resueltoPor!.displayName}',
      if (item.diasRestantes != null)
        item.diasRestantes! >= 0
            ? 'Quedan ${item.diasRestantes} dias'
            : 'Vencido hace ${item.diasRestantes!.abs()} dias',
    ];
    return parts.isEmpty ? 'Sin detalle adicional.' : parts.join(' • ');
  }

  String _feedbackSummaryLabel(FeedbackDashboardSummary summary) {
    final pending = summary.pendientes ?? 0;
    final process = summary.enProceso ?? 0;
    final overdue = summary.vencidos ?? 0;
    if (pending + process + overdue == 0) {
      return 'Sin pendientes';
    }
    return '$pending pendientes • $process en proceso • $overdue vencidos';
  }

  Color _feedbackSummaryColor(FeedbackDashboardSummary summary) {
    final pending = summary.pendientes ?? 0;
    final process = summary.enProceso ?? 0;
    final overdue = summary.vencidos ?? 0;
    if (overdue > 0) return Colors.red.shade700;
    if (pending > 0 || process > 0) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  String _feedbackSummaryMessage(FeedbackDashboardSummary summary) {
    final pending = summary.pendientes ?? 0;
    final process = summary.enProceso ?? 0;
    final overdue = summary.vencidos ?? 0;
    if (pending + process + overdue == 0) {
      return 'No hay feedback pendiente para revisar.';
    }
    return 'Hay novedades en feedback que conviene revisar.';
  }

  String _feedbackSummaryDetails(FeedbackDashboardSummary summary) {
    final resolved = summary.resueltos ?? 0;
    final total = summary.total ?? 0;
    return 'Resueltos: $resolved • Total: $total';
  }

  String? _latestFeedbackTimestamp() {
    final latest = _feedbackRecent.isEmpty ? null : _feedbackRecent.first;
    return latest == null
        ? null
        : latest.updatedAt ?? latest.resueltoAt ?? latest.createdAt;
  }

  DateTime? _parseDateTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  String _monthLabel(int month, int year) {
    const months = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    if (month < 1 || month > 12 || year <= 0) {
      return 'periodo actual';
    }
    return '${months[month]} $year';
  }

  String _normalize(String? raw) {
    return (raw ?? '').trim().toLowerCase();
  }

  IconData _statusIcon(String? status) {
    final normalized = _normalize(status);
    return switch (normalized) {
      'aprobado' => Icons.check_circle_outline,
      'rechazado' => Icons.cancel_outlined,
      'cancelado' => Icons.block_outlined,
      'resuelto' => Icons.verified_outlined,
      'en_proceso' || 'en proceso' => Icons.timelapse,
      'vencido' => Icons.warning_amber_outlined,
      _ => Icons.hourglass_empty_outlined,
    };
  }

  String _statusLabel(String? status) {
    final normalized = _normalize(status);
    return switch (normalized) {
      'aprobado' => 'Aprobado',
      'rechazado' => 'Rechazado',
      'cancelado' => 'Cancelado',
      'resuelto' => 'Resuelto',
      'en_proceso' || 'en proceso' => 'En proceso',
      'vencido' => 'Vencido',
      _ => 'Pendiente',
    };
  }

  Color _statusColor(String? status) {
    final normalized = _normalize(status);
    return switch (normalized) {
      'aprobado' => Colors.green.shade700,
      'rechazado' => Colors.red.shade700,
      'cancelado' => Colors.grey.shade600,
      'resuelto' => Colors.green.shade700,
      'en_proceso' || 'en proceso' => Colors.blue.shade700,
      'vencido' => Colors.red.shade700,
      _ => Colors.amber.shade800,
    };
  }

  String _feedbackStatusLabel(FeedbackItem item) {
    final status = _normalize(item.estadoActual ?? item.estado);
    return _statusLabel(status);
  }

  Color _feedbackStatusColor(FeedbackItem item) {
    final status = _normalize(item.estadoActual ?? item.estado);
    return _statusColor(status);
  }

  IconData _feedbackStatusIcon(FeedbackItem item) {
    final status = _normalize(item.estadoActual ?? item.estado);
    return _statusIcon(status);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.activeCount, required this.entriesCount});

  final int activeCount;
  final int entriesCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Novedades del empleado',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Revisá aprobaciones, rechazos y cambios recientes de adelantos, mercadería y feedback.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _CountPill(
              value: activeCount,
              label: entriesCount == 1 ? 'alerta' : 'alertas',
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleSectionCard extends StatelessWidget {
  const _ModuleSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.onOpen,
    this.error,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Future<void> Function() onOpen;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(onOpen()),
                  child: const Text('Abrir'),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              _SectionError(message: error!),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.items});

  final List<_MetricChip> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: items);
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ModuleAlertTile extends StatelessWidget {
  const _ModuleAlertTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.statusLabel,
    required this.message,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String statusLabel;
  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _StatusPill(label: statusLabel, color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertEntryCard extends StatelessWidget {
  const _AlertEntryCard({required this.entry});

  final _AlertEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: entry.statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(entry.icon, color: entry.statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(
                        label: entry.statusLabel,
                        color: entry.statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.module,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(entry.message),
                  const SizedBox(height: 6),
                  Text(
                    entry.details,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onPrimaryContainer,
            ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: cs.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: cs.onErrorContainer)),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertEntry {
  const _AlertEntry({
    required this.module,
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.icon,
    required this.message,
    required this.details,
    required this.timestamp,
  });

  final String module;
  final String title;
  final String statusLabel;
  final Color statusColor;
  final IconData icon;
  final String message;
  final String details;
  final DateTime? timestamp;
}
