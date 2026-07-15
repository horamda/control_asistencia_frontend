import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<JustificacionItem> _loadJustificacionDetail(
    JustificacionItem item,
  ) async {
    if (item.adjuntos.isNotEmpty || item.effectiveAdjuntosCount <= 0) {
      return item;
    }

    try {
      return await widget.apiClient.getJustificacion(
        token: widget.token,
        id: item.id,
      );
    } catch (_) {
      return item;
    }
  }

  Future<void> _showDetailSheet(JustificacionItem item) async {
    final detailItem = await _loadJustificacionDetail(item);
    if (!mounted) return;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _DetailSheet(
          apiClient: widget.apiClient,
          item: detailItem,
          onDelete: detailItem.estado == 'pendiente'
              ? () {
                  Navigator.of(context).pop();
                  _deleteItem(detailItem);
                }
              : null,
          onEdit: detailItem.estado == 'pendiente'
              ? () {
                  Navigator.of(context).pop();
                  unawaited(_showEditSheet(detailItem));
                }
              : null,
        ),
      ),
    );
  }

  Future<void> _showEditSheet(JustificacionItem item) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditJustificacionSheet(
        apiClient: widget.apiClient,
        token: widget.token,
        item: item,
      ),
    );
    if (result == true) {
      await _load(reset: true);
    }
  }

  Future<void> _deleteItem(JustificacionItem item) async {
    try {
      await widget.apiClient.deleteJustificacion(
        token: widget.token,
        id: item.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Justificación eliminada.')));
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
          if (_counts.isNotEmpty) _SummaryHeader(counts: _counts),
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
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                            onTap: () {
                              unawaited(_showDetailSheet(item));
                            },
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
        content: const Text('¿Eliminar esta justificación pendiente?'),
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
    final fechaDisplay = _justificacionPeriodoDisplay(item);

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
                            style: Theme.of(context).textTheme.titleSmall
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
                            style: Theme.of(context).textTheme.labelSmall
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
                    if (item.hasAdjuntos) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.attach_file, size: 13, color: cs.primary),
                          const SizedBox(width: 3),
                          Text(
                            item.hasAdjuntos
                                ? '${item.effectiveAdjuntosCount} adjunto${item.effectiveAdjuntosCount == 1 ? '' : 's'}'
                                : 'Adjunto',
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
  const _DetailSheet({
    required this.apiClient,
    required this.item,
    this.onDelete,
    this.onEdit,
  });

  final MobileApiClient apiClient;
  final JustificacionItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

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

  Future<void> _openAttachment(BuildContext context, String? rawUrl) async {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(apiClient.buildAbsoluteUrl(value));
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el adjunto.')),
        );
      }
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el adjunto.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _estadoColor(context, item.estado);
    final fechaDisplay = _justificacionPeriodoDisplay(item);
    final creacion = item.createdAt != null
        ? DateFormatter.formatApiDateForDisplay(item.createdAt)
        : '—';

    final hasServerAdjuntos = item.adjuntos.isNotEmpty;
    final hasLegacyArchivo = item.hasLegacyArchivo;
    final effectiveAdjuntosCount = item.effectiveAdjuntosCount;

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
                        child: Icon(
                          _estadoIcon(item.estado),
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Justificación #${item.id}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
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
                    label: item.hasFechaRange
                        ? 'Periodo justificado'
                        : (item.asistenciaFecha != null
                              ? 'Fecha de asistencia'
                              : 'Fecha justificada'),
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
                  if (effectiveAdjuntosCount > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Adjuntos ($effectiveAdjuntosCount)',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hasServerAdjuntos)
                      ...item.adjuntos.map(
                        (adjunto) => _JustificacionAttachmentCard(
                          title: adjunto.displayName,
                          subtitle: _serverAttachmentSubtitle(adjunto),
                          icon: _attachmentIconForServerAttachment(adjunto),
                          onTap: () {
                            unawaited(
                              _openAttachment(context, adjunto.downloadUrl),
                            );
                          },
                        ),
                      ),
                    if (hasLegacyArchivo)
                      _JustificacionAttachmentCard(
                        title: 'Archivo legado',
                        subtitle: item.archivo!.trim(),
                        icon: Icons.link_outlined,
                        onTap: () {
                          unawaited(_openAttachment(context, item.archivo));
                        },
                      ),
                    if (!hasServerAdjuntos && !hasLegacyArchivo)
                      const _JustificacionAttachmentCard(
                        title: 'Adjuntos registrados',
                        subtitle: 'No se pudieron listar para descarga.',
                        icon: Icons.attach_file,
                      ),
                  ],
                  if (onEdit != null || onDelete != null) ...[
                    const SizedBox(height: 24),
                    if (onEdit != null)
                      FilledButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar motivo'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 0),
                        ),
                      ),
                    if (onEdit != null && onDelete != null)
                      const SizedBox(height: 10),
                    if (onDelete != null)
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
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Create bottom sheet ───────────────────────────────────────────────────────

String _justificacionPeriodoDisplay(JustificacionItem item) {
  final start = item.fechaDesde ?? item.fecha ?? item.asistenciaFecha;
  final end = item.fechaHasta ?? item.fecha ?? item.asistenciaFecha;
  if (start == null && end == null) {
    return 'Sin periodo asociado';
  }
  final startDisplay = DateFormatter.formatApiDateForDisplay(start);
  final endDisplay = DateFormatter.formatApiDateForDisplay(end);
  if (startDisplay == endDisplay) {
    return startDisplay;
  }
  return '$startDisplay - $endDisplay';
}

String _formatSelectedRange(DateTime? from, DateTime? to) {
  if (from == null || to == null) {
    return 'Elegir periodo';
  }
  final start = DateFormatter.formatDisplayDate(from);
  final end = DateFormatter.formatDisplayDate(to);
  if (DateFormatter.formatApiDate(from) == DateFormatter.formatApiDate(to)) {
    return start;
  }
  return '$start - $end';
}

bool _sameDateRange(
  DateTime? fromA,
  DateTime? toA,
  DateTime? fromB,
  DateTime? toB,
) {
  if (fromA == null || toA == null || fromB == null || toB == null) {
    return false;
  }
  return DateFormatter.formatApiDate(fromA) ==
          DateFormatter.formatApiDate(fromB) &&
      DateFormatter.formatApiDate(toA) == DateFormatter.formatApiDate(toB);
}

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

class _CreateJustificacionSheetState extends State<_CreateJustificacionSheet> {
  static const int _maxAdjuntos = 10;
  final TextEditingController _motivoCtrl = TextEditingController();
  final List<_DraftJustificacionAdjunto> _adjuntos = [];
  DateTime? _selectedFechaDesde;
  DateTime? _selectedFechaHasta;
  AsistenciaItem? _selectedAsistencia;
  bool _saving = false;
  bool _pickingAttachment = false;
  bool _pickingAsistencia = false;
  String? _error;
  String? _asistenciaError;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'El motivo es requerido.');
      return;
    }
    if (_selectedFechaDesde == null || _selectedFechaHasta == null) {
      setState(() => _error = 'Selecciona el periodo de la justificacion.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fechaDesde = _selectedFechaDesde;
      final fechaHasta = _selectedFechaHasta;
      await widget.apiClient.createJustificacion(
        token: widget.token,
        motivo: motivo,
        fechaDesde: fechaDesde != null
            ? DateFormatter.formatApiDate(fechaDesde)
            : null,
        fechaHasta: fechaHasta != null
            ? DateFormatter.formatApiDate(fechaHasta)
            : null,
        asistenciaId:
            fechaDesde != null && fechaHasta != null && fechaDesde == fechaHasta
            ? _selectedAsistencia?.id
            : null,
        adjuntos: _adjuntos.map((item) => item.upload).toList(),
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

  Future<void> _pickPeriodo() async {
    if (_saving || _pickingAttachment || _pickingAsistencia) {
      return;
    }

    final today = DateTime.now();
    final initialRange =
        _selectedFechaDesde != null && _selectedFechaHasta != null
        ? DateTimeRange(start: _selectedFechaDesde!, end: _selectedFechaHasta!)
        : DateTimeRange(start: today, end: today);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'Seleccionar periodo de justificacion',
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedFechaDesde = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _selectedFechaHasta = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
      _selectedAsistencia = null;
      _pickingAsistencia = true;
      _error = null;
      _asistenciaError = null;
    });

    try {
      if (picked.start == picked.end) {
        final selectedDate = DateFormatter.formatApiDate(picked.start);
        final result = await widget.apiClient.getAsistencias(
          token: widget.token,
          page: 1,
          per: 100,
          desde: selectedDate,
          hasta: selectedDate,
        );
        if (!mounted) {
          return;
        }

        if (result.items.isEmpty) {
          setState(() {
            _asistenciaError = null;
          });
          return;
        }

        final pickedAsistencia = result.items.length == 1
            ? result.items.first
            : await _showAsistenciaSelectionSheet(
                context,
                pickedDate: picked.start,
                items: result.items,
              );
        if (!mounted || pickedAsistencia == null) {
          return;
        }

        setState(() {
          _selectedAsistencia = pickedAsistencia;
          _asistenciaError = null;
        });
      } else {
        setState(() {
          _selectedAsistencia = null;
          _asistenciaError = null;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _asistenciaError = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _asistenciaError = 'No se pudo cargar la asistencia para esa fecha.';
      });
    } finally {
      if (mounted) {
        setState(() => _pickingAsistencia = false);
      }
    }
  }

  void _clearAsistencia() {
    if (_saving || _pickingAsistencia) {
      return;
    }
    setState(() {
      _selectedAsistencia = null;
      _asistenciaError = null;
    });
  }

  Future<void> _addAttachment() async {
    if (_saving || _pickingAttachment) {
      return;
    }
    final source = await _showAttachmentSourceSheet(context);
    if (!mounted || source == null) {
      return;
    }
    setState(() {
      _pickingAttachment = true;
      _error = null;
    });
    try {
      final picked = switch (source) {
        _AttachmentSourceChoice.camera => await _pickCameraAttachments(),
        _AttachmentSourceChoice.gallery => await _pickGalleryAttachments(),
        _AttachmentSourceChoice.file => await _pickFileAttachments(),
      };
      if (!mounted || picked.isEmpty) {
        return;
      }
      final disponibles = _maxAdjuntos - _adjuntos.length;
      if (disponibles <= 0 || picked.length > disponibles) {
        setState(
          () => _error = 'Puedes adjuntar hasta $_maxAdjuntos archivos.',
        );
        return;
      }
      setState(() => _adjuntos.addAll(picked));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo adjuntar el archivo.');
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  void _removeAdjuntoAt(int index) {
    if (_saving) {
      return;
    }
    setState(() => _adjuntos.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.max,
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
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
                  Text(
                    'Periodo de justificacion',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        _saving || _pickingAttachment || _pickingAsistencia
                        ? null
                        : _pickPeriodo,
                    icon: _pickingAsistencia
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_outlined),
                    label: Text(
                      _formatSelectedRange(
                        _selectedFechaDesde,
                        _selectedFechaHasta,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Obligatorio. Puedes elegir un solo dia o un rango. La asistencia se vincula automaticamente cuando corresponde.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (_selectedFechaDesde != null &&
                      _selectedFechaHasta != null &&
                      _selectedFechaDesde == _selectedFechaHasta &&
                      _selectedAsistencia == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'La justificacion quedara asociada solo a la fecha seleccionada.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_selectedFechaDesde != null &&
                      _selectedFechaHasta != null &&
                      _selectedFechaDesde != _selectedFechaHasta) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Al elegir varios dias no se vincula una asistencia puntual.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_selectedAsistencia != null) ...[
                    const SizedBox(height: 10),
                    _JustificacionAttachmentCard(
                      title:
                          'Asistencia vinculada ${DateFormatter.formatApiDateForDisplay(_selectedAsistencia!.fecha)}',
                      subtitle: _asistenciaSubtitle(_selectedAsistencia!),
                      icon: Icons.event_available_outlined,
                      onRemove: _saving ? null : _clearAsistencia,
                    ),
                  ],
                  if (_asistenciaError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _asistenciaError!,
                      style: TextStyle(color: cs.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _saving || _pickingAttachment
                          ? null
                          : _addAttachment,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _pickingAttachment
                            ? 'Procesando...'
                            : 'Adjuntar evidencia',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tomá una foto o elegí un archivo PDF o imagen.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (_adjuntos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Adjuntos seleccionados (${_adjuntos.length})',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _adjuntos.length; i++)
                      _JustificacionAttachmentCard(
                        title: _adjuntos[i].name,
                        subtitle: _formatAttachmentBytes(
                          _adjuntos[i].sizeBytes,
                        ),
                        icon: _attachmentIconForDraft(_adjuntos[i].name),
                        onRemove: _saving ? null : () => _removeAdjuntoAt(i),
                      ),
                  ],
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
          ),
        ],
      ),
    );
  }
}

// ─── Edit bottom sheet ────────────────────────────────────────────────────────

class _EditJustificacionSheet extends StatefulWidget {
  const _EditJustificacionSheet({
    required this.apiClient,
    required this.token,
    required this.item,
  });

  final MobileApiClient apiClient;
  final String token;
  final JustificacionItem item;

  @override
  State<_EditJustificacionSheet> createState() =>
      _EditJustificacionSheetState();
}

class _EditJustificacionSheetState extends State<_EditJustificacionSheet> {
  static const int _maxAdjuntos = 10;
  late final TextEditingController _motivoCtrl;
  final List<_DraftJustificacionAdjunto> _adjuntos = [];
  DateTime? _initialFechaDesde;
  DateTime? _initialFechaHasta;
  DateTime? _selectedFechaDesde;
  DateTime? _selectedFechaHasta;
  bool _saving = false;
  bool _pickingPeriodo = false;
  bool _pickingAttachment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _motivoCtrl = TextEditingController(text: widget.item.motivo ?? '');
    final parsedDesde = DateFormatter.parseFlexibleDate(
      widget.item.fechaDesde ??
          widget.item.fecha ??
          widget.item.asistenciaFecha ??
          '',
    );
    final parsedHasta = DateFormatter.parseFlexibleDate(
      widget.item.fechaHasta ??
          widget.item.fecha ??
          widget.item.asistenciaFecha ??
          '',
    );
    _initialFechaDesde = parsedDesde;
    _initialFechaHasta = parsedHasta ?? parsedDesde;
    _selectedFechaDesde = parsedDesde;
    _selectedFechaHasta = parsedHasta ?? parsedDesde;
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'El motivo es requerido.');
      return;
    }
    if (_selectedFechaDesde == null || _selectedFechaHasta == null) {
      setState(() => _error = 'Selecciona el periodo de la justificacion.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fechaDesde = _selectedFechaDesde;
      final fechaHasta = _selectedFechaHasta;
      final periodoSinCambios = _sameDateRange(
        fechaDesde,
        fechaHasta,
        _initialFechaDesde,
        _initialFechaHasta,
      );
      await widget.apiClient.updateJustificacion(
        token: widget.token,
        id: widget.item.id,
        motivo: motivo,
        fechaDesde: fechaDesde != null
            ? DateFormatter.formatApiDate(fechaDesde)
            : null,
        fechaHasta: fechaHasta != null
            ? DateFormatter.formatApiDate(fechaHasta)
            : null,
        asistenciaId:
            periodoSinCambios &&
                fechaDesde != null &&
                fechaHasta != null &&
                fechaDesde == fechaHasta
            ? widget.item.asistenciaId
            : null,
        clearAsistencia:
            !(periodoSinCambios &&
                fechaDesde != null &&
                fechaHasta != null &&
                fechaDesde == fechaHasta),
        adjuntos: _adjuntos.map((item) => item.upload).toList(),
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

  Future<void> _pickPeriodo() async {
    if (_saving || _pickingAttachment || _pickingPeriodo) {
      return;
    }

    final today = DateTime.now();
    final initialRange =
        _selectedFechaDesde != null && _selectedFechaHasta != null
        ? DateTimeRange(start: _selectedFechaDesde!, end: _selectedFechaHasta!)
        : DateTimeRange(start: today, end: today);
    setState(() {
      _pickingPeriodo = true;
    });
    try {
      final picked = await showDateRangePicker(
        context: context,
        initialDateRange: initialRange,
        firstDate: DateTime(2020),
        lastDate: today,
        helpText: 'Seleccionar periodo de justificacion',
      );
      if (picked == null || !mounted) {
        return;
      }

      setState(() {
        _selectedFechaDesde = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        _selectedFechaHasta = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
        );
        _error = null;
      });
    } finally {
      if (mounted) {
        setState(() => _pickingPeriodo = false);
      }
    }
  }

  Future<void> _addAttachment() async {
    if (_saving || _pickingAttachment) {
      return;
    }
    final source = await _showAttachmentSourceSheet(context);
    if (!mounted || source == null) {
      return;
    }
    setState(() {
      _pickingAttachment = true;
      _error = null;
    });
    try {
      final picked = switch (source) {
        _AttachmentSourceChoice.camera => await _pickCameraAttachments(),
        _AttachmentSourceChoice.gallery => await _pickGalleryAttachments(),
        _AttachmentSourceChoice.file => await _pickFileAttachments(),
      };
      if (!mounted || picked.isEmpty) {
        return;
      }
      final disponibles =
          _maxAdjuntos - widget.item.effectiveAdjuntosCount - _adjuntos.length;
      if (disponibles <= 0 || picked.length > disponibles) {
        setState(
          () => _error = 'Puedes tener hasta $_maxAdjuntos archivos en total.',
        );
        return;
      }
      setState(() => _adjuntos.addAll(picked));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo adjuntar el archivo.');
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  void _removeAdjuntoAt(int index) {
    if (_saving) {
      return;
    }
    setState(() => _adjuntos.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.max,
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
                  'Editar justificación #${widget.item.id}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
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
                  if (_selectedFechaDesde != null &&
                      _selectedFechaHasta != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Periodo',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          (_saving || _pickingAttachment || _pickingPeriodo)
                          ? null
                          : _pickPeriodo,
                      icon: _pickingPeriodo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.event_outlined),
                      label: Text(
                        _formatSelectedRange(
                          _selectedFechaDesde,
                          _selectedFechaHasta,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Si el periodo cubre un solo dia, se puede mantener una asistencia puntual. Si abarca varios dias, esa vinculacion se quitara al guardar.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (widget.item.asistenciaFecha != null) ...[
                      const SizedBox(height: 10),
                      _DetailRow(
                        icon: Icons.event_available_outlined,
                        label: 'Asistencia vinculada',
                        value: DateFormatter.formatApiDateForDisplay(
                          widget.item.asistenciaFecha,
                        ),
                      ),
                    ],
                  ],
                  if (widget.item.effectiveAdjuntosCount > 0) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Adjuntos actuales (${widget.item.effectiveAdjuntosCount})',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.item.adjuntos.isNotEmpty)
                      ...widget.item.adjuntos.map(
                        (adjunto) => _JustificacionAttachmentCard(
                          title: adjunto.displayName,
                          subtitle: _serverAttachmentSubtitle(adjunto),
                          icon: _attachmentIconForServerAttachment(adjunto),
                          onTap: () {
                            unawaited(
                              _openJustificacionAttachment(
                                context,
                                widget.apiClient,
                                adjunto.downloadUrl,
                              ),
                            );
                          },
                        ),
                      ),
                    if (widget.item.hasLegacyArchivo)
                      _JustificacionAttachmentCard(
                        title: 'Archivo legado',
                        subtitle: widget.item.archivo!.trim(),
                        icon: Icons.link_outlined,
                        onTap: () {
                          unawaited(
                            _openJustificacionAttachment(
                              context,
                              widget.apiClient,
                              widget.item.archivo,
                            ),
                          );
                        },
                      ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _saving || _pickingAttachment
                          ? null
                          : _addAttachment,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _pickingAttachment
                            ? 'Procesando...'
                            : 'Agregar evidencia',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los adjuntos nuevos se agregan al guardar la edición.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (_adjuntos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Nuevos adjuntos (${_adjuntos.length})',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _adjuntos.length; i++)
                      _JustificacionAttachmentCard(
                        title: _adjuntos[i].name,
                        subtitle: _formatAttachmentBytes(
                          _adjuntos[i].sizeBytes,
                        ),
                        icon: _attachmentIconForDraft(_adjuntos[i].name),
                        onRemove: _saving ? null : () => _removeAdjuntoAt(i),
                      ),
                  ],
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
                        : const Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
          ),
          if (widget.item.adjuntos.isEmpty && !widget.item.hasLegacyArchivo)
            const _JustificacionAttachmentCard(
              title: 'Adjuntos actuales',
              subtitle: 'No se pudieron listar para descarga.',
              icon: Icons.attach_file,
            ),
        ],
      ),
    );
  }
}

enum _AttachmentSourceChoice { camera, gallery, file }

class _DraftJustificacionAdjunto {
  const _DraftJustificacionAdjunto({
    required this.upload,
    required this.name,
    this.sizeBytes,
  });

  final JustificacionAdjuntoUpload upload;
  final String name;
  final int? sizeBytes;
}

class _JustificacionAttachmentCard extends StatelessWidget {
  const _JustificacionAttachmentCard({
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
    this.onRemove,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actionIcon = onRemove != null
        ? Icons.close
        : onTap != null
        ? Icons.open_in_new_outlined
        : null;
    final actionTooltip = onRemove != null
        ? 'Quitar'
        : onTap != null
        ? 'Abrir'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: actionIcon == null
            ? null
            : IconButton(
                tooltip: actionTooltip,
                onPressed: onTap ?? onRemove,
                icon: Icon(actionIcon, size: 18),
              ),
      ),
    );
  }
}

Future<_AttachmentSourceChoice?> _showAttachmentSourceSheet(
  BuildContext context,
) {
  return showModalBottomSheet<_AttachmentSourceChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Adjuntar evidencia',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Tomá una foto o elegí un archivo PDF o imagen.',
                style: Theme.of(
                  sheetContext,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.pop(sheetContext, _AttachmentSourceChoice.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Tomar foto'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  _AttachmentSourceChoice.gallery,
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir de la galeria'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(sheetContext, _AttachmentSourceChoice.file),
                icon: const Icon(Icons.attach_file),
                label: const Text('Elegir archivo'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<AsistenciaItem?> _showAsistenciaSelectionSheet(
  BuildContext context, {
  required DateTime pickedDate,
  required List<AsistenciaItem> items,
}) {
  return showModalBottomSheet<AsistenciaItem>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Elegi la asistencia de ${DateFormatter.formatDisplayDate(pickedDate)}',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Se encontraron ${items.length} registro(s) para esa fecha.',
                style: Theme.of(
                  sheetContext,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: (MediaQuery.sizeOf(sheetContext).height * 0.45)
                    .clamp(220.0, 420.0)
                    .toDouble(),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _JustificacionAttachmentCard(
                      title:
                          'Asistencia ${DateFormatter.formatApiDateForDisplay(item.fecha)}',
                      subtitle: _asistenciaSubtitle(item),
                      icon: Icons.event_available_outlined,
                      onTap: () => Navigator.pop(sheetContext, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _normalizeAttachmentFilename(
  String rawName, {
  String fallbackExtension = 'jpg',
}) {
  final name = rawName.trim();
  if (name.isEmpty) {
    return 'adjunto.$fallbackExtension';
  }
  return name.contains('.') ? name : '$name.$fallbackExtension';
}

String _formatAttachmentBytes(int? sizeBytes) {
  if (sizeBytes == null || sizeBytes <= 0) {
    return 'Tamaño no disponible';
  }
  const kb = 1024.0;
  const mb = kb * 1024;
  const gb = mb * 1024;
  final value = sizeBytes.toDouble();
  if (value < kb) {
    return '$sizeBytes B';
  }
  if (value < mb) {
    final kbValue = value / kb;
    return '${kbValue >= 10 ? kbValue.toStringAsFixed(0) : kbValue.toStringAsFixed(1)} KB';
  }
  if (value < gb) {
    final mbValue = value / mb;
    return '${mbValue >= 10 ? mbValue.toStringAsFixed(0) : mbValue.toStringAsFixed(1)} MB';
  }
  return '${(value / gb).toStringAsFixed(1)} GB';
}

String _asistenciaSubtitle(AsistenciaItem item) {
  final parts = <String>[];
  final estado = item.estado?.trim();
  if (estado != null && estado.isNotEmpty) {
    parts.add(
      estado.length == 1
          ? estado.toUpperCase()
          : '${estado[0].toUpperCase()}${estado.substring(1)}',
    );
  }

  final entrada = item.horaEntrada?.trim();
  if (entrada != null && entrada.isNotEmpty) {
    parts.add('Entrada $entrada');
  }

  final salida = item.horaSalida?.trim();
  if (salida != null && salida.isNotEmpty) {
    parts.add('Salida $salida');
  }

  return parts.isEmpty ? 'Asistencia registrada' : parts.join(' · ');
}

String _serverAttachmentSubtitle(JustificacionAdjuntoItem adjunto) {
  final parts = <String>[];
  final extension = adjunto.extension?.trim();
  if (extension != null && extension.isNotEmpty) {
    parts.add(extension.toUpperCase());
  }
  if (adjunto.tamanoBytes != null) {
    parts.add(_formatAttachmentBytes(adjunto.tamanoBytes));
  }
  final estado = adjunto.estado?.trim();
  if (estado != null && estado.isNotEmpty) {
    parts.add(estado);
  }
  return parts.isEmpty ? 'Adjunto' : parts.join(' · ');
}

IconData _attachmentIconForServerAttachment(JustificacionAdjuntoItem adjunto) {
  final mime = adjunto.mimeType?.trim().toLowerCase() ?? '';
  final extension = adjunto.extension?.trim().toLowerCase() ?? '';
  if (mime.startsWith('image/') ||
      ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(extension)) {
    return Icons.image_outlined;
  }
  if (mime == 'application/pdf' || extension == 'pdf') {
    return Icons.picture_as_pdf_outlined;
  }
  return Icons.attach_file;
}

IconData _attachmentIconForDraft(String name) {
  final extension = name.split('.').last.trim().toLowerCase();
  if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(extension)) {
    return Icons.image_outlined;
  }
  if (extension == 'pdf') {
    return Icons.picture_as_pdf_outlined;
  }
  return Icons.attach_file;
}

Future<List<_DraftJustificacionAdjunto>> _pickCameraAttachments() async {
  final picker = ImagePicker();
  final photo = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 85,
    maxWidth: 2048,
    maxHeight: 2048,
    requestFullMetadata: false,
  );
  if (photo == null) {
    return const <_DraftJustificacionAdjunto>[];
  }
  final bytes = await photo.readAsBytes();
  final filename = _normalizeAttachmentFilename(
    photo.name,
    fallbackExtension: 'jpg',
  );
  return <_DraftJustificacionAdjunto>[
    _DraftJustificacionAdjunto(
      upload: JustificacionAdjuntoUpload(
        filename: filename,
        bytes: bytes,
        sizeBytes: bytes.length,
      ),
      name: filename,
      sizeBytes: bytes.length,
    ),
  ];
}

Future<List<_DraftJustificacionAdjunto>> _pickGalleryAttachments() async {
  final images = await ImagePicker().pickMultiImage(
    imageQuality: 85,
    maxWidth: 2048,
    maxHeight: 2048,
    requestFullMetadata: false,
  );
  final items = <_DraftJustificacionAdjunto>[];
  for (final image in images) {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) continue;
    final filename = _normalizeAttachmentFilename(
      image.name,
      fallbackExtension: 'jpg',
    );
    items.add(
      _DraftJustificacionAdjunto(
        upload: JustificacionAdjuntoUpload(
          filename: filename,
          bytes: bytes,
          sizeBytes: bytes.length,
        ),
        name: filename,
        sizeBytes: bytes.length,
      ),
    );
  }
  return items;
}

Future<List<_DraftJustificacionAdjunto>> _pickFileAttachments() async {
  final result = await FilePicker.pickFiles(
    allowMultiple: true,
    withData: kIsWeb,
    type: FileType.custom,
    allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf'],
  );
  if (result == null || result.files.isEmpty) {
    return const <_DraftJustificacionAdjunto>[];
  }

  final items = <_DraftJustificacionAdjunto>[];
  for (final file in result.files) {
    final filename = _normalizeAttachmentFilename(file.name);
    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      items.add(
        _DraftJustificacionAdjunto(
          upload: JustificacionAdjuntoUpload(
            filename: filename,
            bytes: bytes,
            sizeBytes: file.size,
          ),
          name: filename,
          sizeBytes: file.size,
        ),
      );
      continue;
    }
    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      items.add(
        _DraftJustificacionAdjunto(
          upload: JustificacionAdjuntoUpload(
            filename: filename,
            path: path,
            sizeBytes: file.size,
          ),
          name: filename,
          sizeBytes: file.size,
        ),
      );
    }
  }
  return items;
}

Future<void> _openJustificacionAttachment(
  BuildContext context,
  MobileApiClient apiClient,
  String? rawUrl,
) async {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) {
    return;
  }
  final uri = Uri.tryParse(apiClient.buildAbsoluteUrl(value));
  if (uri == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el adjunto.')),
      );
    }
    return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el adjunto.')),
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
    _fade = Tween<double>(
      begin: 0.35,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);
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
