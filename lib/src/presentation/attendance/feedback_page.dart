import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/feedback_api_models.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/utils/date_formatter.dart';

const Color _facebookBlue = Color(0xFF1877F2);
const Color _facebookBlueDark = Color(0xFF145DBF);
const Color _facebookBackground = Color(0xFFF0F2F5);
const Color _facebookSurface = Colors.white;
const Color _facebookPaleBlue = Color(0xFFE7F3FF);
const Color _facebookMuted = Color(0xFF65676B);
const Color _facebookText = Color(0xFF050505);
const Color _facebookBorder = Color(0xFFDADDE1);

ThemeData _buildFacebookFeedbackTheme(ThemeData base) {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: _facebookBlue,
        brightness: Brightness.light,
      ).copyWith(
        primary: _facebookBlue,
        secondary: _facebookBlue,
        surface: _facebookSurface,
        onPrimary: Colors.white,
        onSurface: _facebookText,
        onSurfaceVariant: _facebookMuted,
        outline: _facebookBorder,
        outlineVariant: _facebookBorder,
        primaryContainer: _facebookPaleBlue,
        onPrimaryContainer: _facebookBlueDark,
        secondaryContainer: _facebookPaleBlue,
        onSecondaryContainer: _facebookBlueDark,
        surfaceContainerLow: _facebookSurface,
        surfaceContainerHighest: const Color(0xFFF7F8FA),
      );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _facebookBackground,
    textTheme: base.textTheme.apply(
      fontFamily: 'Segoe UI',
      bodyColor: _facebookText,
      displayColor: _facebookText,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: _facebookSurface,
      foregroundColor: _facebookText,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: _facebookText),
      actionsIconTheme: const IconThemeData(color: _facebookText),
      titleTextStyle: const TextStyle(
        color: _facebookText,
        fontFamily: 'Segoe UI',
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: _facebookBlue,
      unselectedLabelColor: _facebookMuted,
      indicatorColor: _facebookBlue,
      dividerColor: _facebookBorder,
      labelStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: _facebookSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _facebookBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _facebookBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _facebookBlue, width: 1.5),
      ),
      labelStyle: const TextStyle(
        color: _facebookMuted,
        fontFamily: 'Segoe UI',
      ),
      hintStyle: const TextStyle(color: _facebookMuted, fontFamily: 'Segoe UI'),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: _facebookSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _facebookBorder),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: _facebookPaleBlue,
      labelStyle: const TextStyle(
        color: _facebookBlueDark,
        fontFamily: 'Segoe UI',
        fontWeight: FontWeight.w700,
      ),
      side: const BorderSide(color: Color(0xFFB7D7FF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _facebookBlue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Segoe UI',
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _facebookBlue,
        side: const BorderSide(color: _facebookBorder),
        textStyle: const TextStyle(
          fontFamily: 'Segoe UI',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _facebookBlue,
      foregroundColor: Colors.white,
    ),
  );
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, required this.apiClient, required this.token});

  final MobileApiClient apiClient;
  final String token;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const int _pageSize = 20;

  bool _loading = true;
  bool _loadingHistorialPage = false;
  bool _loadingBandejaPage = false;

  String? _dashboardError;
  String? _historialError;
  String? _bandejaError;

  FeedbackDashboardResponse? _dashboard;
  List<FeedbackItem> _historialItems = const [];
  List<FeedbackItem> _bandejaItems = const [];

  int _historialPage = 1;
  int _historialPerPage = _pageSize;
  int _historialTotal = 0;

  int _bandejaPage = 1;
  int _bandejaPerPage = _pageSize;
  int _bandejaTotal = 0;

  ThemeData _feedbackTheme(BuildContext context) {
    return _buildFacebookFeedbackTheme(Theme.of(context));
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _dashboardError = null;
      _historialError = null;
      _bandejaError = null;
    });

    try {
      await Future.wait([
        _loadDashboard(),
        _loadHistorialPage(page: 1),
        _loadBandejaPage(page: 1),
      ]);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadDashboard() async {
    try {
      final dashboard = await widget.apiClient.getFeedbackDashboard(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _dashboardError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _dashboardError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dashboardError = 'No se pudo cargar el dashboard de feedback.';
      });
    }
  }

  Future<void> _loadHistorialPage({required int page}) async {
    if (_loadingHistorialPage) return;
    setState(() => _loadingHistorialPage = true);
    try {
      final result = await widget.apiClient.getFeedbackHistorial(
        token: widget.token,
        page: page,
        perPage: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _historialItems = result.items;
        _historialPage = result.page;
        _historialPerPage = result.perPage;
        _historialTotal = result.total;
        _historialError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _historialError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historialError = 'No se pudo cargar el historial de feedback.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingHistorialPage = false);
      }
    }
  }

  Future<void> _loadBandejaPage({required int page}) async {
    if (_loadingBandejaPage) return;
    setState(() => _loadingBandejaPage = true);
    try {
      final result = await widget.apiClient.getFeedbackBandeja(
        token: widget.token,
        page: page,
        perPage: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _bandejaItems = result.items;
        _bandejaPage = result.page;
        _bandejaPerPage = result.perPage;
        _bandejaTotal = result.total;
        _bandejaError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _bandejaError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bandejaError = 'No se pudo cargar la bandeja de feedback.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingBandejaPage = false);
      }
    }
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  Future<void> _openCreateSheet() async {
    final theme = _feedbackTheme(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Theme(
        data: theme,
        child: FeedbackCreateSheet(
          apiClient: widget.apiClient,
          token: widget.token,
        ),
      ),
    );
    if (result == true && mounted) {
      await _loadAll();
    }
  }

  Future<void> _openDetail({
    required FeedbackItem item,
    required bool allowActions,
  }) async {
    final theme = _feedbackTheme(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Theme(
        data: theme,
        child: FeedbackDetailSheet(
          apiClient: widget.apiClient,
          token: widget.token,
          feedbackId: item.id ?? 0,
          initialItem: item,
          allowActions: allowActions,
        ),
      ),
    );
    if (result == true && mounted) {
      await _loadAll();
    }
  }

  bool _hasNextHistorial() {
    return _historialPage * _historialPerPage < _historialTotal;
  }

  bool _hasPrevHistorial() => _historialPage > 1;

  bool _hasNextBandeja() {
    return _bandejaPage * _bandejaPerPage < _bandejaTotal;
  }

  bool _hasPrevBandeja() => _bandejaPage > 1;

  @override
  Widget build(BuildContext context) {
    final theme = _feedbackTheme(context);
    return Theme(
      data: theme,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Feedback de calle'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Resumen'),
                Tab(text: 'Historial'),
                Tab(text: 'Bandeja'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Nuevo feedback',
                onPressed: _loading ? null : _openCreateSheet,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _buildSummaryTab(),
                    _buildHistorialTab(),
                    _buildBandejaTab(),
                  ],
                ),
          floatingActionButton: _loading
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openCreateSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear'),
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    final dashboard = _dashboard;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _ResponsiveTabList(
        children: [
          if (_dashboardError != null) ...[
            _ErrorCard(message: _dashboardError!, onRetry: _refresh),
            const SizedBox(height: 12),
          ],
          if (dashboard == null) ...[
            const _EmptyStateCard(
              icon: Icons.campaign_outlined,
              title: 'Sin datos de feedback',
              subtitle:
                  'Todavía no hay información disponible para mostrar en este módulo.',
            ),
          ] else ...[
            _FeedbackHeroCard(summary: dashboard.resumen),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Mi posición',
              icon: Icons.leaderboard_outlined,
              child: _PersonalSummaryCard(
                personal: dashboard.personal,
                totals: dashboard.totales,
                employee: dashboard.empleado,
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Resumen general',
              icon: Icons.query_stats_outlined,
              child: _SummaryGrid(summary: dashboard.resumen),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Top motivos',
              icon: Icons.label_important_outline,
              child: dashboard.topMotivos.isEmpty
                  ? const _EmptyInline(text: 'No hay motivos para mostrar.')
                  : Column(
                      children: [
                        for (final item in dashboard.topMotivos.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TopMotivoTile(item: item),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Ranking de carga',
              icon: Icons.bar_chart_outlined,
              child: dashboard.ranking.isEmpty
                  ? const _EmptyInline(text: 'Aún no hay ranking disponible.')
                  : Column(
                      children: [
                        for (final item in dashboard.ranking.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RankingTile(item: item),
                          ),
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar datos'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _ResponsiveTabList(
        children: [
          if (_historialError != null) ...[
            _ErrorCard(message: _historialError!, onRetry: _refresh),
            const SizedBox(height: 12),
          ],
          _ListHeader(
            title: 'Mis feedbacks',
            subtitle:
                'Pagina $_historialPage de ${(_historialTotal / _historialPerPage).ceil().clamp(1, 999)}',
            trailing: _loadingHistorialPage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (_historialItems.isEmpty)
            const _EmptyStateCard(
              icon: Icons.inbox_outlined,
              title: 'Sin historial',
              subtitle: 'Los feedbacks que cargues van a aparecer acá.',
            )
          else
            ..._historialItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FeedbackListTile(
                  item: item,
                  onTap: () => _openDetail(item: item, allowActions: false),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _PaginationRow(
            hasPrev: _hasPrevHistorial(),
            hasNext: _hasNextHistorial(),
            onPrev: _hasPrevHistorial() && !_loadingHistorialPage
                ? () => _loadHistorialPage(page: _historialPage - 1)
                : null,
            onNext: _hasNextHistorial() && !_loadingHistorialPage
                ? () => _loadHistorialPage(page: _historialPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBandejaTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _ResponsiveTabList(
        children: [
          if (_bandejaError != null) ...[
            _ErrorCard(message: _bandejaError!, onRetry: _refresh),
            const SizedBox(height: 12),
          ],
          _ListHeader(
            title: 'Bandeja del jefe directo',
            subtitle:
                'Pagina $_bandejaPage de ${(_bandejaTotal / _bandejaPerPage).ceil().clamp(1, 999)}',
            trailing: _loadingBandejaPage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (_bandejaItems.isEmpty)
            const _EmptyStateCard(
              icon: Icons.task_outlined,
              title: 'Bandeja vacia',
              subtitle: 'No tenes feedbacks pendientes de gestion.',
            )
          else
            ..._bandejaItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FeedbackListTile(
                  item: item,
                  onTap: () => _openDetail(item: item, allowActions: true),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _PaginationRow(
            hasPrev: _hasPrevBandeja(),
            hasNext: _hasNextBandeja(),
            onPrev: _hasPrevBandeja() && !_loadingBandejaPage
                ? () => _loadBandejaPage(page: _bandejaPage - 1)
                : null,
            onNext: _hasNextBandeja() && !_loadingBandejaPage
                ? () => _loadBandejaPage(page: _bandejaPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class FeedbackDetailSheet extends StatefulWidget {
  const FeedbackDetailSheet({
    super.key,
    required this.apiClient,
    required this.token,
    required this.feedbackId,
    required this.initialItem,
    required this.allowActions,
  });

  final MobileApiClient apiClient;
  final String token;
  final int feedbackId;
  final FeedbackItem initialItem;
  final bool allowActions;

  @override
  State<FeedbackDetailSheet> createState() => _FeedbackDetailSheetState();
}

class _FeedbackDetailSheetState extends State<FeedbackDetailSheet> {
  FeedbackItem? _item;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.feedbackId <= 0) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo identificar el feedback.';
        _loading = false;
      });
      return;
    }
    try {
      final item = await widget.apiClient.getFeedbackDetail(
        token: widget.token,
        feedbackId: widget.feedbackId,
      );
      if (!mounted) return;
      setState(() {
        _item = item;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el detalle del feedback.';
        _loading = false;
      });
    }
  }

  Future<void> _take() async {
    final item = _item;
    if (item == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.takeFeedback(
        token: widget.token,
        feedbackId: item.id ?? widget.feedbackId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo tomar el feedback.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    final item = _item;
    if (item == null || _busy) return;
    final controller = TextEditingController();
    final descripcion = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Resolver feedback'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 400,
            decoration: const InputDecoration(
              labelText: 'Descripción de la gestión',
              hintText: 'Contanos cómo se resolvió...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(dialogContext).pop(value.isEmpty ? null : value);
              },
              child: const Text('Resolver'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    final clean = descripcion?.trim();
    if (clean == null || clean.isEmpty) return;

    setState(() => _busy = true);
    try {
      await widget.apiClient.resolveFeedback(
        token: widget.token,
        feedbackId: item.id ?? widget.feedbackId,
        resolucionDescripcion: clean,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo resolver el feedback.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item ?? widget.initialItem;
    final status = item.estadoActual ?? item.estado ?? 'pendiente';
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                24,
                              ),
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        item.isResolved
                                            ? Icons.check_circle_outline
                                            : Icons.campaign_outlined,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Feedback #${item.id ?? widget.feedbackId}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _StatusChip(
                                                label: statusLabel,
                                                color: statusColor,
                                              ),
                                              if (item.resueltoEnSla != null)
                                                _StatusChip(
                                                  label: item.resueltoEnSla!
                                                      ? 'Resuelto en SLA'
                                                      : 'Fuera de SLA',
                                                  color: item.resueltoEnSla!
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  _ErrorCard(message: _error!, onRetry: _load),
                                ],
                                const SizedBox(height: 16),
                                _SectionCard(
                                  title: 'Descripción',
                                  icon: Icons.description_outlined,
                                  child: Text(
                                    item.descripcion?.trim().isNotEmpty == true
                                        ? item.descripcion!.trim()
                                        : 'Sin descripcion.',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _SectionCard(
                                  title: 'Datos',
                                  icon: Icons.info_outline,
                                  child: Column(
                                    children: [
                                      _DetailRow(
                                        label: 'Cliente',
                                        value: item.cliente?.displayName ?? '-',
                                      ),
                                      _DetailRow(
                                        label: 'Motivo',
                                        value: item.motivo?.displayName ?? '-',
                                      ),
                                      _DetailRow(
                                        label: 'Empleado',
                                        value:
                                            item.empleado?.displayName ?? '-',
                                      ),
                                      _DetailRow(
                                        label: 'Jefe directo',
                                        value:
                                            item.jefeDirecto?.displayName ??
                                            '-',
                                      ),
                                      _DetailRow(
                                        label: 'Creado',
                                        value:
                                            DateFormatter.formatApiDateForDisplay(
                                              item.createdAt,
                                            ),
                                      ),
                                      _DetailRow(
                                        label: 'Vence',
                                        value:
                                            DateFormatter.formatApiDateForDisplay(
                                              item.fechaVencimiento,
                                            ),
                                      ),
                                      _DetailRow(
                                        label: 'Actualizado',
                                        value:
                                            DateFormatter.formatApiDateForDisplay(
                                              item.updatedAt,
                                            ),
                                      ),
                                      _DetailRow(
                                        label: 'Resolución',
                                        value:
                                            item.resolucionDescripcion
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? item.resolucionDescripcion!.trim()
                                            : '-',
                                      ),
                                      _DetailRow(
                                        label: 'Resuelto por',
                                        value:
                                            item.resueltoPor?.displayName ??
                                            '-',
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.diasRestantes != null) ...[
                                  const SizedBox(height: 12),
                                  _SectionCard(
                                    title: 'SLA',
                                    icon: Icons.timer_outlined,
                                    child: Text(
                                      item.diasRestantes! >= 0
                                          ? 'Quedan ${item.diasRestantes} dias'
                                          : 'Vencido hace ${item.diasRestantes!.abs()} dias',
                                    ),
                                  ),
                                ],
                                if (widget.allowActions &&
                                    !item.isResolved) ...[
                                  const SizedBox(height: 12),
                                  _SectionCard(
                                    title: 'Acciones',
                                    icon: Icons.manage_search_outlined,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (status != 'en_proceso')
                                          FilledButton.icon(
                                            onPressed: _busy ? null : _take,
                                            icon: _busy
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(Icons.play_arrow),
                                            label: const Text('Tomar'),
                                          ),
                                        if (status != 'resuelto') ...[
                                          const SizedBox(height: 8),
                                          OutlinedButton.icon(
                                            onPressed: _busy ? null : _resolve,
                                            icon: const Icon(
                                              Icons.check_circle,
                                            ),
                                            label: const Text('Resolver'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    final normalized = status.trim().toLowerCase();
    return switch (normalized) {
      'resuelto' => Colors.green,
      'en_proceso' => Colors.blue,
      'vencido' => Colors.red,
      _ => Colors.orange,
    };
  }

  String _statusLabel(String status) {
    final normalized = status.trim().toLowerCase();
    return switch (normalized) {
      'resuelto' => 'Resuelto',
      'en_proceso' => 'En proceso',
      'vencido' => 'Vencido',
      _ => 'Pendiente',
    };
  }
}

class FeedbackCreateSheet extends StatefulWidget {
  const FeedbackCreateSheet({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<FeedbackCreateSheet> createState() => _FeedbackCreateSheetState();
}

class _FeedbackCreateSheetState extends State<FeedbackCreateSheet> {
  static const int _clientPageSize = 200;
  static const Duration _remoteSearchDelay = Duration(milliseconds: 350);

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();
  Timer? _searchDebounce;
  int _searchRequestVersion = 0;

  bool _loading = true;
  bool _searching = false;
  bool _saving = false;

  String? _error;
  String _searchQuery = '';
  List<FeedbackMotivo> _motivos = const [];
  List<FeedbackCliente> _catalogClientes = const [];
  List<FeedbackCliente> _clientes = const [];
  FeedbackMotivo? _selectedMotivo;
  FeedbackCliente? _selectedCliente;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final results = await Future.wait([
        widget.apiClient.getFeedbackMotivos(token: widget.token),
        widget.apiClient.getFeedbackClientes(
          token: widget.token,
          perPage: _clientPageSize,
        ),
      ]);
      if (!mounted) return;
      final motivos = results[0] as FeedbackMotivosResponse;
      final clientes = results[1] as FeedbackClientesResponse;
      setState(() {
        _searchQuery = '';
        _motivos = motivos.items;
        _catalogClientes = clientes.items;
        _clientes = clientes.items;
        _selectedMotivo = _motivos.isNotEmpty ? _motivos.first : null;
        _selectedCliente = _clientes.isNotEmpty ? _clientes.first : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo preparar el formulario de feedback.';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _applyLocalSearch(query);
    _searchDebounce?.cancel();

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      _searchRequestVersion++;
      return;
    }

    _searchDebounce = Timer(_remoteSearchDelay, () {
      if (!mounted) return;
      unawaited(_searchClientes(query: cleanQuery));
    });
  }

  void _applyLocalSearch(String query) {
    final normalizedQuery = query.trim();
    final filtered = _filterClientes(_catalogClientes, normalizedQuery);
    final selected = _preferredCliente(
      filtered,
      normalizedQuery,
      _selectedCliente?.id,
    );
    setState(() {
      _searchQuery = normalizedQuery;
      _clientes = filtered;
      _selectedCliente = selected;
    });
  }

  FeedbackCliente? _preferredCliente(
    List<FeedbackCliente> clientes,
    String query,
    int? selectedClienteId,
  ) {
    if (clientes.isEmpty) {
      return null;
    }

    final currentSelection = _clienteById(clientes, selectedClienteId);
    if (currentSelection != null) {
      return currentSelection;
    }

    if (query.isEmpty) {
      return clientes.first;
    }

    return _bestClientMatch(clientes, query) ?? clientes.first;
  }

  Future<void> _searchClientes({String? query}) async {
    _searchDebounce?.cancel();
    final effectiveQuery = (query ?? _searchCtrl.text).trim();
    final requestVersion = ++_searchRequestVersion;
    if (effectiveQuery.isEmpty) {
      _applyLocalSearch('');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await widget.apiClient.getFeedbackClientes(
        token: widget.token,
        q: effectiveQuery,
        perPage: _clientPageSize,
      );
      if (!mounted || requestVersion != _searchRequestVersion) return;
      if (_searchCtrl.text.trim() != effectiveQuery) return;
      // El backend ya filtró por `q` (y busca en más campos que el catálogo
      // local, como tipo_codigo/descripcion_localidad/descripcion_provincia).
      // Solo reordenamos por relevancia acá: volver a filtrar localmente con
      // _filterClientes descartaba resultados válidos que no calzaban con el
      // conjunto de campos/normalización del cliente.
      final clientes = _sortClientesByRelevance(result.items, effectiveQuery);
      setState(() {
        _searchQuery = effectiveQuery;
        _clientes = clientes;
        _selectedCliente = _preferredCliente(
          clientes,
          effectiveQuery,
          _selectedCliente?.id,
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron buscar clientes.');
    } finally {
      if (mounted && requestVersion == _searchRequestVersion) {
        setState(() => _searching = false);
      }
    }
  }

  List<FeedbackCliente> _filterClientes(
    List<FeedbackCliente> clientes,
    String query,
  ) {
    final terms = _searchTerms(query);
    if (terms.isEmpty) {
      return List<FeedbackCliente>.from(clientes);
    }

    final filtered = clientes
        .where((cliente) => _clienteMatches(cliente, terms))
        .toList(growable: false);

    return _sortByRelevance(filtered, terms);
  }

  /// Reordena resultados que el backend ya filtró por `q`, sin excluir
  /// ninguno. A diferencia de [_filterClientes], no vuelve a aplicar el
  /// matching local (que usa menos campos que la búsqueda del servidor).
  List<FeedbackCliente> _sortClientesByRelevance(
    List<FeedbackCliente> clientes,
    String query,
  ) {
    final terms = _searchTerms(query);
    if (terms.isEmpty) {
      return List<FeedbackCliente>.from(clientes);
    }
    return _sortByRelevance(List<FeedbackCliente>.from(clientes), terms);
  }

  List<FeedbackCliente> _sortByRelevance(
    List<FeedbackCliente> clientes,
    List<String> terms,
  ) {
    final sorted = List<FeedbackCliente>.from(clientes);
    sorted.sort((left, right) {
      final leftScore = _clientMatchScore(left, terms);
      final rightScore = _clientMatchScore(right, terms);
      if (leftScore != rightScore) {
        return rightScore.compareTo(leftScore);
      }
      return left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      );
    });
    return sorted;
  }

  bool _clienteMatches(FeedbackCliente cliente, List<String> terms) {
    final haystack = _clienteSearchHaystack(cliente);
    return terms.every(haystack.contains);
  }

  int _clientMatchScore(FeedbackCliente cliente, List<String> terms) {
    final fields = _clienteSearchFields(cliente);
    var score = 0;
    for (final term in terms) {
      var exact = false;
      var prefix = false;
      var contains = false;
      for (final field in fields) {
        if (field == term) {
          exact = true;
          break;
        }
        if (field.startsWith(term)) {
          prefix = true;
        }
        if (field.contains(term)) {
          contains = true;
        }
      }
      if (exact) {
        score += 3;
      } else if (prefix) {
        score += 2;
      } else if (contains) {
        score += 1;
      }
    }
    return score;
  }

  FeedbackCliente? _bestClientMatch(
    List<FeedbackCliente> clientes,
    String query,
  ) {
    final terms = _searchTerms(query);
    if (terms.isEmpty) {
      return clientes.isNotEmpty ? clientes.first : null;
    }

    for (final cliente in clientes) {
      if (_clienteSearchFields(cliente).any(terms.contains)) {
        return cliente;
      }
    }

    for (final cliente in clientes) {
      if (_clienteSearchFields(
        cliente,
      ).any((field) => terms.any((term) => field.startsWith(term)))) {
        return cliente;
      }
    }

    return clientes.length == 1 ? clientes.first : null;
  }

  FeedbackCliente? _clienteById(List<FeedbackCliente> clientes, int? id) {
    if (id == null) {
      return null;
    }
    for (final cliente in clientes) {
      if (cliente.id == id) {
        return cliente;
      }
    }
    return null;
  }

  List<String> _clienteSearchFields(FeedbackCliente cliente) {
    return [
      cliente.displayName,
      cliente.id?.toString(),
      cliente.codigo,
      cliente.razonSocial,
      cliente.nombreFantasia,
      cliente.tipo,
      cliente.sucursalOrigen,
      cliente.telefonos,
      cliente.movil,
      cliente.email,
      cliente.domicilio,
      cliente.localidad,
      cliente.provincia,
    ].map(_normalizeSearchValue).where((value) => value.isNotEmpty).toList();
  }

  String _clienteSearchHaystack(FeedbackCliente cliente) {
    return _clienteSearchFields(cliente).join(' ');
  }

  List<String> _searchTerms(String query) {
    final normalized = _normalizeSearchValue(query);
    if (normalized.isEmpty) {
      return const [];
    }
    return normalized
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
  }

  String _normalizeSearchValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    return normalized
        .replaceAll(RegExp(r'[áàäâãå]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _submit() async {
    final cliente = _selectedCliente;
    final motivo = _selectedMotivo;
    final descripcion = _descripcionCtrl.text.trim();
    if (cliente?.id == null) {
      setState(() => _error = 'Selecciona un cliente.');
      return;
    }
    if (motivo?.id == null) {
      setState(() => _error = 'Selecciona un motivo.');
      return;
    }
    if (descripcion.isEmpty) {
      setState(() => _error = 'La descripcion es obligatoria.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiClient.createFeedback(
        token: widget.token,
        clienteId: cliente!.id!,
        motivoId: motivo!.id!,
        descripcion: descripcion,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo crear el feedback.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.65,
        maxChildSize: 0.98,
        builder: (context, scrollController) {
          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                24,
                              ),
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Nuevo feedback',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _searchCtrl,
                                  textInputAction: TextInputAction.search,
                                  onChanged: _onSearchChanged,
                                  onSubmitted: (_) => _searchClientes(),
                                  decoration: InputDecoration(
                                    labelText: 'Buscar cliente',
                                    hintText:
                                        'Número, razón social o nombre del negocio',
                                    helperText:
                                        'La búsqueda consulta el catálogo mientras escribís.',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      onPressed: _searching
                                          ? null
                                          : _searchClientes,
                                      icon: _searching
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.search),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _SectionCard(
                                  title: 'Motivo',
                                  icon: Icons.label_outlined,
                                  child:
                                      DropdownButtonFormField<FeedbackMotivo>(
                                        initialValue: _selectedMotivo,
                                        isExpanded: true,
                                        items: [
                                          for (final motivo in _motivos)
                                            DropdownMenuItem(
                                              value: motivo,
                                              child: Text(
                                                motivo.displayName,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                        onChanged: (value) {
                                          setState(
                                            () => _selectedMotivo = value,
                                          );
                                        },
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 14),
                                _SectionCard(
                                  title: 'Cliente',
                                  icon: Icons.storefront_outlined,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_selectedCliente != null)
                                        _SelectedClientCard(
                                          cliente: _selectedCliente!,
                                        ),
                                      const SizedBox(height: 8),
                                      if (_clientes.isEmpty)
                                        _EmptyInline(
                                          text: _searchQuery.isEmpty
                                              ? 'No hay clientes para mostrar.'
                                              : 'No se encontraron clientes para "'
                                                    '$_searchQuery". Probá con otro término o tocá buscar para consultar todo el catálogo.',
                                        )
                                      else
                                        ..._clientes.map(
                                          (cliente) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: _ClientResultTile(
                                              cliente: cliente,
                                              selected:
                                                  _selectedCliente?.id ==
                                                  cliente.id,
                                              onTap: () {
                                                setState(() {
                                                  _selectedCliente = cliente;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _SectionCard(
                                  title: 'Descripción',
                                  icon: Icons.description_outlined,
                                  child: TextField(
                                    controller: _descripcionCtrl,
                                    maxLines: 5,
                                    maxLength: 400,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      alignLabelWithHint: true,
                                      hintText:
                                          'Contanos qué pasó en la calle...',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _saving ? null : _submit,
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send),
                                  label: const Text('Crear feedback'),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeedbackHeroCard extends StatelessWidget {
  const _FeedbackHeroCard({required this.summary});

  final FeedbackDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.campaign_outlined, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feedback de calle',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Seguí el estado de tus cargas y la respuesta de tu jefe directo.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStatChip(label: 'Total', value: summary.total),
              _MiniStatChip(label: 'Pendientes', value: summary.pendientes),
              _MiniStatChip(label: 'En proceso', value: summary.enProceso),
              _MiniStatChip(label: 'Resueltos', value: summary.resueltos),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final FeedbackDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = <_StatTileData>[
      _StatTileData('Total', summary.total, Icons.all_inbox_outlined),
      _StatTileData('Pendientes', summary.pendientes, Icons.pending_actions),
      _StatTileData('En proceso', summary.enProceso, Icons.timelapse),
      _StatTileData('Resueltos', summary.resueltos, Icons.check_circle_outline),
      _StatTileData('Vencidos', summary.vencidos, Icons.warning_amber_outlined),
      _StatTileData('En SLA', summary.resueltosEnSla, Icons.verified_outlined),
      _StatTileData(
        'Fuera SLA',
        summary.resueltosFueraSla,
        Icons.event_busy_outlined,
      ),
      _StatTileData('Motivos', summary.motivosDistintos, Icons.sell_outlined),
      _StatTileData(
        'Clientes',
        summary.clientesDistintos,
        Icons.storefront_outlined,
      ),
      _StatTileData(
        'Con carga',
        summary.empleadosConCarga,
        Icons.people_outline,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 700 ? 3 : 2;
        final spacing = 10.0;
        final tileWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: _StatTile(data: item),
              ),
          ],
        );
      },
    );
  }
}

class _PersonalSummaryCard extends StatelessWidget {
  const _PersonalSummaryCard({
    required this.personal,
    required this.totals,
    required this.employee,
  });

  final FeedbackPersonalStats? personal;
  final FeedbackTotals? totals;
  final FeedbackEmployeeSummary? employee;

  @override
  Widget build(BuildContext context) {
    if (personal == null && totals == null && employee == null) {
      return const _EmptyInline(text: 'No hay datos personales disponibles.');
    }

    final children = <Widget>[
      if (employee != null)
        _DetailRow(label: 'Empleado', value: employee!.displayName),
      if (personal != null) ...[
        _DetailRow(
          label: 'Posición',
          value: personal!.posicionRanking != null
              ? '#${personal!.posicionRanking}'
              : '-',
        ),
        _DetailRow(
          label: 'Total cargados',
          value: personal!.totalCargados?.toString() ?? '-',
        ),
        _DetailRow(
          label: 'Promedio',
          value: personal!.promedioPorEmpleado != null
              ? personal!.promedioPorEmpleado!.toStringAsFixed(2)
              : '-',
        ),
        _DetailRow(
          label: 'Porcentaje',
          value: personal!.porcentajeSobreTotal != null
              ? '${personal!.porcentajeSobreTotal!.toStringAsFixed(1)}%'
              : '-',
        ),
      ],
      if (totals != null) ...[
        _DetailRow(
          label: 'Activos',
          value: totals!.empleadosActivos?.toString() ?? '-',
        ),
        _DetailRow(
          label: 'Con carga',
          value: totals!.empleadosConCarga?.toString() ?? '-',
        ),
      ],
    ];

    return Column(children: children);
  }
}

class _TopMotivoTile extends StatelessWidget {
  const _TopMotivoTile({required this.item});

  final FeedbackTopMotivo item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_fire_department_outlined,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.motivoNombre ?? 'Motivo',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Resueltos: ${item.resueltos ?? 0}'),
              ],
            ),
          ),
          Text(
            '${item.total ?? 0}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.item});

  final FeedbackRankingItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: Text(
              '${item.total ?? 0}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Feedback cargados: ${item.total ?? 0}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackListTile extends StatelessWidget {
  const _FeedbackListTile({required this.item, required this.onTap});

  final FeedbackItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = item.estadoActual ?? item.estado ?? 'pendiente';
    final statusColor = _statusColor(status);
    final subtitle = <String>[
      if (item.cliente != null) item.cliente!.displayName,
      if (item.motivo != null) item.motivo!.displayName,
      if ((item.descripcion ?? '').trim().isNotEmpty) item.descripcion!.trim(),
    ].join(' - ');

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          foregroundColor: statusColor,
          child: Icon(
            item.isResolved
                ? Icons.check_circle_outline
                : Icons.campaign_outlined,
          ),
        ),
        title: Text(item.cliente?.displayName ?? 'Feedback #${item.id ?? '-'}'),
        subtitle: Text(
          subtitle.isEmpty ? 'Sin descripcion' : subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusChip(label: _statusLabel(status), color: statusColor),
            const SizedBox(height: 6),
            Text(
              DateFormatter.formatApiDateForDisplayShort(item.fechaVencimiento),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _ClientResultTile extends StatelessWidget {
  const _ClientResultTile({
    required this.cliente,
    required this.selected,
    required this.onTap,
  });

  final FeedbackCliente cliente;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: selected ? cs.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          Icons.storefront_outlined,
          color: selected ? cs.onPrimaryContainer : cs.primary,
        ),
        title: Text(cliente.displayName),
        subtitle: Text(
          [
            if ((cliente.codigo ?? '').trim().isNotEmpty)
              cliente.codigo!.trim(),
            if ((cliente.tipo ?? '').trim().isNotEmpty) cliente.tipo!.trim(),
            if ((cliente.localidad ?? '').trim().isNotEmpty)
              cliente.localidad!.trim(),
          ].join(' - '),
        ),
        trailing: selected ? const Icon(Icons.check_circle) : null,
      ),
    );
  }
}

class _SelectedClientCard extends StatelessWidget {
  const _SelectedClientCard({required this.cliente});

  final FeedbackCliente cliente;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: cs.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cliente.displayName,
              style: TextStyle(
                color: cs.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista con scroll usada en las 3 pestañas de Feedback. Centra el
/// contenido y limita su ancho en pantallas grandes (tablet/desktop/web)
/// para que no se estire de borde a borde, siguiendo el mismo patrón que
/// el resto de la app (ver security_events_page.dart / employee_stats_page.dart).
class _ResponsiveTabList extends StatelessWidget {
  const _ResponsiveTabList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 1200
            ? 1040.0
            : constraints.maxWidth >= 900
            ? 900.0
            : double.infinity;
        final hPad = constraints.maxWidth < 600 ? 16.0 : 24.0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(hPad),
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(color: cs.onErrorContainer)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationRow extends StatelessWidget {
  const _PaginationRow({
    required this.hasPrev,
    required this.hasNext,
    required this.onPrev,
    required this.onNext,
  });

  final bool hasPrev;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.sizeOf(context).width < 430;
    final prevButton = OutlinedButton.icon(
      onPressed: onPrev,
      icon: const Icon(Icons.chevron_left),
      label: const Text('Anterior'),
    );
    final nextButton = OutlinedButton.icon(
      onPressed: onNext,
      icon: const Icon(Icons.chevron_right),
      label: const Text('Siguiente'),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [prevButton, const SizedBox(height: 8), nextButton],
      );
    }

    return Row(
      children: [
        Expanded(child: prevButton),
        const SizedBox(width: 10),
        Expanded(child: nextButton),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _StatTileData {
  const _StatTileData(this.label, this.value, this.icon);

  final String label;
  final int? value;
  final IconData icon;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final _StatTileData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(data.icon, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '${data.value ?? 0}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$label: ${value ?? 0}',
        style: TextStyle(
          color: cs.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text),
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 40, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  final normalized = status.trim().toLowerCase();
  return switch (normalized) {
    'resuelto' => Colors.green,
    'en_proceso' => Colors.blue,
    'vencido' => Colors.red,
    _ => Colors.orange,
  };
}

String _statusLabel(String status) {
  final normalized = status.trim().toLowerCase();
  return switch (normalized) {
    'resuelto' => 'Resuelto',
    'en_proceso' => 'En proceso',
    'vencido' => 'Vencido',
    _ => 'Pendiente',
  };
}
