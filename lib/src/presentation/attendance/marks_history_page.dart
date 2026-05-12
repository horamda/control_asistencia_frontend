import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import '../../core/utils/date_formatter.dart';

class MarksHistoryPage extends StatefulWidget {
  const MarksHistoryPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<MarksHistoryPage> createState() => _MarksHistoryPageState();
}

class _MarksHistoryPageState extends State<MarksHistoryPage> {
  bool _loading = true;
  bool _loadingPage = false;
  String? _error;

  int _page = 1;
  int _perPage = 20;
  int _total = 0;
  List<MarcaItem> _items = const [];

  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _loadPage(page: 1);
  }

  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate({required bool isDesde}) async {
    final today = _todayDate();
    final current = (isDesde ? _desde : _hasta) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: isDesde ? 'Desde' : 'Hasta',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isDesde) {
        _desde = picked;
        if (_hasta != null && _hasta!.isBefore(picked)) _hasta = picked;
      } else {
        _hasta = picked;
        if (_desde != null && _desde!.isAfter(picked)) _desde = picked;
      }
    });
  }

  Future<void> _loadPage({required int page}) async {
    if (_loadingPage) return;
    setState(() {
      _loadingPage = true;
      if (_items.isEmpty) _loading = true;
    });
    try {
      final data = await widget.apiClient.getMarcas(
        token: widget.token,
        page: page,
        per: _perPage,
        desde: _desde != null ? DateFormatter.formatApiDate(_desde!) : null,
        hasta: _hasta != null ? DateFormatter.formatApiDate(_hasta!) : null,
      );
      if (!mounted) return;
      setState(() {
        _items = data.items;
        _page = data.page;
        _perPage = data.perPage;
        _total = data.total;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado al consultar marcas.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingPage = false;
        });
      }
    }
  }

  void _applyFilters() => _loadPage(page: 1);

  void _clearFilters() {
    setState(() {
      _desde = null;
      _hasta = null;
    });
    _loadPage(page: 1);
  }

  void _showDetail(MarcaItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MarcaDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPrev = _page > 1;
    final hasNext = (_page * _perPage) < _total;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de marcas'),
        bottom: _loadingPage
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: _loading
          ? const _MarksSkeleton()
          : RefreshIndicator(
              onRefresh: () => _loadPage(page: _page),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  // ── Filter row ──────────────────────────────────────
                  _DateRangeFilterBar(
                    desde: _desde,
                    hasta: _hasta,
                    loading: _loadingPage,
                    onPickDesde: () => _pickDate(isDesde: true),
                    onPickHasta: () => _pickDate(isDesde: false),
                    onApply: _applyFilters,
                    onClear: _clearFilters,
                  ),
                  const SizedBox(height: 8),

                  // ── Summary chip ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      '$_total marca${_total == 1 ? '' : 's'} — página $_page',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── Error ───────────────────────────────────────────
                  if (_error != null) ...[
                    _ErrorBanner(
                      message: _error!,
                      onRetry: () => _loadPage(page: _page),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── Items ───────────────────────────────────────────
                  if (_items.isEmpty)
                    _EmptyCard(
                      hasFilters: _desde != null || _hasta != null,
                    ),
                  ...(_items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => _showDetail(item),
                        child: _MarcaCard(item: item),
                      ),
                    ),
                  )),

                  // ── Pagination ──────────────────────────────────────
                  if (_total > _perPage) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (!hasPrev || _loadingPage)
                                ? null
                                : () => _loadPage(page: _page - 1),
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Anterior'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (!hasNext || _loadingPage)
                                ? null
                                : () => _loadPage(page: _page + 1),
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Siguiente'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// ─── Date range filter bar ─────────────────────────────────────────────────────

class _DateRangeFilterBar extends StatelessWidget {
  const _DateRangeFilterBar({
    required this.desde,
    required this.hasta,
    required this.loading,
    required this.onPickDesde,
    required this.onPickHasta,
    required this.onApply,
    required this.onClear,
  });

  final DateTime? desde;
  final DateTime? hasta;
  final bool loading;
  final VoidCallback onPickDesde;
  final VoidCallback onPickHasta;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFilter = desde != null || hasta != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filtrar por fecha',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (hasFilter) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: loading ? null : onClear,
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Limpiar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Desde',
                    value: desde,
                    onTap: loading ? null : onPickDesde,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateButton(
                    label: 'Hasta',
                    value: hasta,
                    onTap: loading ? null : onPickHasta,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: loading ? null : onApply,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Buscar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_month, size: 16),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
        child: Text(
          value != null
              ? DateFormatter.formatDisplayDate(value!)
              : '–',
          style: TextStyle(
            color: value != null ? cs.onSurface : cs.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Marca card ────────────────────────────────────────────────────────────────

class _MarcaCard extends StatelessWidget {
  const _MarcaCard({required this.item});

  final MarcaItem item;

  Color _accionColor(BuildContext context, String? accion) {
    final cs = Theme.of(context).colorScheme;
    return switch ((accion ?? '').toLowerCase()) {
      'entrada' => cs.primary,
      'salida' => Colors.orange.shade800,
      _ => cs.outline,
    };
  }

  IconData _accionIcon(String? accion) {
    return switch ((accion ?? '').toLowerCase()) {
      'entrada' => Icons.login_outlined,
      'salida' => Icons.logout_outlined,
      _ => Icons.swap_horiz_outlined,
    };
  }

  Color _estadoColor(BuildContext context, String? estado) {
    final cs = Theme.of(context).colorScheme;
    return switch ((estado ?? '').toLowerCase()) {
      'ok' || 'valido' || 'validado' => Colors.green.shade700,
      'rechazado' || 'error' || 'invalido' => cs.error,
      _ => Colors.grey.shade600,
    };
  }

  IconData _metodoIcon(String? metodo) {
    return switch ((metodo ?? '').toLowerCase()) {
      'qr' => Icons.qr_code_outlined,
      'biometrico' || 'huella' || 'biometric' => Icons.fingerprint,
      'manual' => Icons.edit_outlined,
      _ => Icons.touch_app_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _accionColor(context, item.accion);
    final estadoColor = _estadoColor(context, item.estado);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _accionIcon(item.accion),
                            size: 16,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _accionLabel(item.accion),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                DateFormatter.formatApiDateForDisplay(
                                  item.fecha,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        // Hora
                        if ((item.hora ?? '').isNotEmpty)
                          Text(
                            item.hora!,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Estado badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: estadoColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _capitalize(item.estado ?? 'pendiente'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: estadoColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Método badge
                        if ((item.metodo ?? '').isNotEmpty) ...[
                          Icon(
                            _metodoIcon(item.metodo),
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _capitalize(item.metodo!),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // GPS chip
                        if (item.gpsDistanciaM != null &&
                            item.gpsToleranciaM != null) ...[
                          Icon(
                            Icons.my_location_outlined,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.gpsDistanciaM!.toStringAsFixed(0)} m',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: cs.outlineVariant,
                        ),
                      ],
                    ),
                    if ((item.observaciones ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.observaciones!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _accionLabel(String? accion) {
    return switch ((accion ?? '').toLowerCase()) {
      'entrada' => 'Entrada',
      'salida' => 'Salida',
      _ => _capitalize(accion ?? 'Marca'),
    };
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Marca detail sheet ────────────────────────────────────────────────────────

class _MarcaDetailSheet extends StatelessWidget {
  const _MarcaDetailSheet({required this.item});

  final MarcaItem item;

  Color _accionColor(BuildContext context, String? accion) {
    final cs = Theme.of(context).colorScheme;
    return switch ((accion ?? '').toLowerCase()) {
      'entrada' => cs.primary,
      'salida' => Colors.orange.shade800,
      _ => cs.outline,
    };
  }

  IconData _accionIcon(String? accion) {
    return switch ((accion ?? '').toLowerCase()) {
      'entrada' => Icons.login_outlined,
      'salida' => Icons.logout_outlined,
      _ => Icons.swap_horiz_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _accionColor(context, item.accion);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_accionIcon(item.accion),
                            color: color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _accionLabel(item.accion),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              DateFormatter.formatApiDateForDisplay(item.fecha),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if ((item.hora ?? '').isNotEmpty)
                        Text(
                          item.hora!,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  _DetailGrid(children: [
                    if ((item.accion ?? '').isNotEmpty)
                      _DetailCell(
                        icon: Icons.swap_horiz_outlined,
                        label: 'Acción',
                        value: _capitalize(item.accion!),
                      ),
                    if ((item.tipoMarca ?? '').isNotEmpty)
                      _DetailCell(
                        icon: Icons.label_outline,
                        label: 'Tipo',
                        value: _capitalize(item.tipoMarca!),
                      ),
                    if ((item.metodo ?? '').isNotEmpty)
                      _DetailCell(
                        icon: Icons.touch_app_outlined,
                        label: 'Método',
                        value: _capitalize(item.metodo!),
                      ),
                    if ((item.estado ?? '').isNotEmpty)
                      _DetailCell(
                        icon: Icons.info_outline,
                        label: 'Estado',
                        value: _capitalize(item.estado!),
                        valueColor: _estadoColor(context, item.estado),
                      ),
                    if (item.gpsDistanciaM != null)
                      _DetailCell(
                        icon: Icons.my_location_outlined,
                        label: 'GPS distancia',
                        value:
                            '${item.gpsDistanciaM!.toStringAsFixed(1)} m',
                      ),
                    if (item.gpsToleranciaM != null)
                      _DetailCell(
                        icon: Icons.radar_outlined,
                        label: 'GPS tolerancia',
                        value:
                            '${item.gpsToleranciaM!.toStringAsFixed(1)} m',
                      ),
                    if (item.lat != null && item.lon != null)
                      _DetailCell(
                        icon: Icons.pin_drop_outlined,
                        label: 'Coordenadas',
                        value:
                            '${item.lat!.toStringAsFixed(5)}, ${item.lon!.toStringAsFixed(5)}',
                      ),
                  ]),

                  if ((item.observaciones ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Observaciones',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        item.observaciones!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _estadoColor(BuildContext context, String? estado) {
    final cs = Theme.of(context).colorScheme;
    return switch ((estado ?? '').toLowerCase()) {
      'ok' || 'valido' || 'validado' => Colors.green.shade700,
      'rechazado' || 'error' || 'invalido' => cs.error,
      _ => Colors.grey.shade600,
    };
  }

  String _accionLabel(String? accion) {
    return switch ((accion ?? '').toLowerCase()) {
      'entrada' => 'Entrada',
      'salida' => 'Salida',
      _ => _capitalize(accion ?? 'Marca'),
    };
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Shared detail grid / cell ─────────────────────────────────────────────────

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: children.map((c) => SizedBox(width: 160, child: c)).toList(),
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline_outlined, size: 56, color: cs.outlineVariant),
            const SizedBox(height: 14),
            Text(
              hasFilters
                  ? 'Sin marcas en el rango seleccionado'
                  : 'Sin marcas registradas',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Reintentar',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton loader ──────────────────────────────────────────────────────────

class _MarksSkeleton extends StatefulWidget {
  const _MarksSkeleton();

  @override
  State<_MarksSkeleton> createState() => _MarksSkeletonState();
}

class _MarksSkeletonState extends State<_MarksSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _SkeletonBox(
            color: base,
            height: 56,
            radius: 12,
            opacity: _fade.value,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < 8; i++) ...[
            _SkeletonBox(
              color: base,
              height: 64,
              radius: 12,
              opacity: _fade.value,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.color,
    required this.height,
    required this.radius,
    required this.opacity,
  });

  final Color color;
  final double height;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
