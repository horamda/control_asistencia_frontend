import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import '../../core/utils/date_formatter.dart';

class JustificacionesPage extends StatefulWidget {
  const JustificacionesPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<JustificacionesPage> createState() => _JustificacionesPageState();
}

class _JustificacionesPageState extends State<JustificacionesPage> {
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final List<JustificacionItem> _items = [];
  int _page = 1;
  int _total = 0;
  String? _filtroEstado;
  Map<String, int> _counts = {};

  static const _estados = ['pendiente', 'aprobada', 'rechazada'];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final results = await Future.wait([
        widget.apiClient.getJustificaciones(
          token: widget.token,
          page: 1,
          estado: 'pendiente',
        ),
        widget.apiClient.getJustificaciones(
          token: widget.token,
          page: 1,
          estado: 'aprobada',
        ),
        widget.apiClient.getJustificaciones(
          token: widget.token,
          page: 1,
          estado: 'rechazada',
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _counts = {
          'pendiente': results[0].total,
          'aprobada': results[1].total,
          'rechazada': results[2].total,
        };
      });
    } catch (_) {
      // counts are optional — fail silently
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _items.clear();
        _page = 1;
        _total = 0;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final result = await widget.apiClient.getJustificaciones(
        token: widget.token,
        page: _page,
        estado: _filtroEstado,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _total = result.total;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado al cargar justificaciones.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || _items.length >= _total) return;
    _page++;
    await _load();
  }

  Future<void> _showCreateSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateJustificacionSheet(
        apiClient: widget.apiClient,
        token: widget.token,
      ),
    );
    if (result == true) {
      _filtroEstado = null;
      await _load(reset: true);
      unawaited(_loadCounts());
    }
  }

  void _showDetailSheet(JustificacionItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DetailSheet(
        item: item,
        onDelete: item.estado == 'pendiente'
            ? () {
                Navigator.of(context).pop();
                _deleteItem(item);
              }
            : null,
      ),
    );
  }

  Future<void> _deleteItem(JustificacionItem item) async {
    try {
      await widget.apiClient.deleteJustificacion(
        token: widget.token,
        id: item.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Justificación eliminada.')),
      );
      await _load(reset: true);
      unawaited(_loadCounts());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
      // If delete failed after swipe, re-load to restore the item in list
      await _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis justificaciones'),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva justificación',
            onPressed: _showCreateSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_counts.isNotEmpty)
            _SummaryHeader(counts: _counts),
          _FilterRow(
            selected: _filtroEstado,
            estados: _estados,
            onSelect: (e) {
              setState(() => _filtroEstado = e);
              _load(reset: true);
            },
          ),
          Expanded(
            child: _loading
                ? const _JustifSkeleton()
                : _error != null
                ? _ErrorView(
                    message: _error!,
                    onRetry: () => _load(reset: true),
                  )
                : _items.isEmpty
                ? const _EmptyView()
                : RefreshIndicator(
                    onRefresh: () async {
                      await _load(reset: true);
                      unawaited(_loadCounts());
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >=
                            n.metrics.maxScrollExtent - 120) {
                          _loadNextPage();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          if (i == _items.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final item = _items[i];
                          final card = GestureDetector(
                            onTap: () => _showDetailSheet(item),
                            child: _JustificacionCard(item: item),
                          );
                          if (item.estado == 'pendiente') {
                            return Dismissible(
                              key: ValueKey(item.id),
                              direction: DismissDirection.endToStart,
                              background: _SwipeDeleteBackground(),
                              confirmDismiss: (_) => _confirmSwipeDelete(),
                              onDismissed: (_) => _deleteItem(item),
                              child: card,
                            );
                          }
                          return card;
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  Future<bool> _confirmSwipeDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar justificación'),
        content: const Text(
          '¿Eliminar esta justificación pendiente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

// ─── Summary header ────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.surfaceContainerLow,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _StatePill(
            label: 'Pendientes',
            count: counts['pendiente'] ?? 0,
            color: Colors.amber.shade700,
          ),
          _StatePill(
            label: 'Aprobadas',
            count: counts['aprobada'] ?? 0,
            color: Colors.green.shade700,
          ),
          _StatePill(
            label: 'Rechazadas',
            count: counts['rechazada'] ?? 0,
            color: cs.error,
          ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.estados,
    required this.onSelect,
  });

  final String? selected;
  final List<String> estados;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _chip(context, cs, null, 'Todas'),
          ...estados.map((e) => _chip(context, cs, e, _capitalize(e))),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    ColorScheme cs,
    String? value,
    String label,
  ) {
    final active = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onSelect(active ? null : value),
        selectedColor: cs.primaryContainer,
        checkmarkColor: cs.onPrimaryContainer,
        labelStyle: TextStyle(
          color: active ? cs.onPrimaryContainer : cs.onSurface,
          fontWeight: active ? FontWeight.w700 : FontWeight.normal,
        ),
        side: BorderSide.none,
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Swipe delete background ───────────────────────────────────────────────────

class _SwipeDeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}

// ─── Justificacion card ────────────────────────────────────────────────────────

class _JustificacionCard extends StatelessWidget {
  const _JustificacionCard({required this.item});

  final JustificacionItem item;

  Color _estadoColor(BuildContext context, String? estado) {
    final cs = Theme.of(context).colorScheme;
    return switch (estado) {
      'aprobada' => Colors.green.shade700,
      'rechazada' => cs.error,
      _ => Colors.amber.shade800,
    };
  }

  IconData _estadoIcon(String? estado) {
    return switch (estado) {
      'aprobada' => Icons.check_circle_outline,
      'rechazada' => Icons.cancel_outlined,
      _ => Icons.hourglass_empty_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _estadoColor(context, item.estado);
    final fechaDisplay = item.asistenciaFecha != null
        ? DateFormatter.formatApiDateForDisplay(item.asistenciaFecha)
        : 'Sin asistencia asociada';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_estadoIcon(item.estado), color: color, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Justificación #${item.id}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _capitalize(item.estado ?? 'pendiente'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fechaDisplay,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (item.estado == 'pendiente') ...[
                          const Spacer(),
                          Icon(
                            Icons.swipe_left_outlined,
                            size: 13,
                            color: cs.outlineVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'deslizar para eliminar',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.outlineVariant),
                          ),
                        ],
                      ],
                    ),
                    if ((item.motivo ?? '').isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.motivo!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (item.archivo != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.attach_file, size: 13, color: cs.primary),
                          const SizedBox(width: 3),
                          Text(
                            'Adjunto',
                            style: TextStyle(fontSize: 12, color: cs.primary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.chevron_right,
                color: cs.outlineVariant,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Detail bottom sheet ───────────────────────────────────────────────────────

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.item, this.onDelete});

  final JustificacionItem item;
  final VoidCallback? onDelete;

  Color _estadoColor(BuildContext context, String? estado) {
    final cs = Theme.of(context).colorScheme;
    return switch (estado) {
      'aprobada' => Colors.green.shade700,
      'rechazada' => cs.error,
      _ => Colors.amber.shade800,
    };
  }

  IconData _estadoIcon(String? estado) {
    return switch (estado) {
      'aprobada' => Icons.check_circle_outline,
      'rechazada' => Icons.cancel_outlined,
      _ => Icons.hourglass_empty_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _estadoColor(context, item.estado);
    final fechaDisplay = item.asistenciaFecha != null
        ? DateFormatter.formatApiDateForDisplay(item.asistenciaFecha)
        : 'Sin asistencia asociada';
    final creacion = item.createdAt != null
        ? DateFormatter.formatApiDateForDisplay(item.createdAt)
        : '—';

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_estadoIcon(item.estado), color: color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Justificación #${item.id}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _capitalize(item.estado ?? 'pendiente'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha de asistencia',
                    value: fechaDisplay,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.history_outlined,
                    label: 'Fecha de creación',
                    value: creacion,
                  ),
                  if ((item.motivo ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Motivo',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                        item.motivo!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  if (item.archivo != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Adjunto',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                      child: Row(
                        children: [
                          Icon(Icons.attach_file, size: 16, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.archivo!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.primary,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (onDelete != null) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline, color: cs.error),
                      label: Text(
                        'Eliminar justificación',
                        style: TextStyle(color: cs.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(double.infinity, 0),
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Create bottom sheet ───────────────────────────────────────────────────────

class _CreateJustificacionSheet extends StatefulWidget {
  const _CreateJustificacionSheet({
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<_CreateJustificacionSheet> createState() =>
      _CreateJustificacionSheetState();
}

class _CreateJustificacionSheetState
    extends State<_CreateJustificacionSheet> {
  final TextEditingController _motivoCtrl = TextEditingController();
  final TextEditingController _archivoCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _archivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'El motivo es requerido.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiClient.createJustificacion(
        token: widget.token,
        motivo: motivo,
        archivo: _archivoCtrl.text.trim().isEmpty ? null : _archivoCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado. Intentalo de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                Text(
                  'Nueva justificación',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _motivoCtrl,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Motivo *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _archivoCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL del adjunto (opcional)',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.attach_file, size: 18),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Guardar justificación'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / Error views ───────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fact_check_outlined, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Sin justificaciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Toca el botón + para crear una nueva.',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton loader ──────────────────────────────────────────────────────────

class _JustifSkeleton extends StatefulWidget {
  const _JustifSkeleton();

  @override
  State<_JustifSkeleton> createState() => _JustifSkeletonState();
}

class _JustifSkeletonState extends State<_JustifSkeleton>
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 7; i++) ...[
            _SkeletonBox(
              color: base,
              height: 80,
              radius: 12,
              opacity: _fade.value,
            ),
            const SizedBox(height: 10),
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
