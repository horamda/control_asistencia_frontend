import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class VacacionesPage extends StatefulWidget {
  const VacacionesPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<VacacionesPage> createState() => _VacacionesPageState();
}

class _VacacionesPageState extends State<VacacionesPage> {
  bool _loading = true;
  String? _error;
  List<VacacionItem> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;
  static const _per = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _items = [];
    });
    try {
      final result = await widget.apiClient.getVacaciones(
        token: widget.token,
        page: 1,
        per: _per,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = 1;
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
        _error = 'Error inesperado al cargar las vacaciones.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.apiClient.getVacaciones(
        token: widget.token,
        page: _page + 1,
        per: _per,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...result.items];
        _page++;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _solicitar() async {
    final result = await showDialog<_VacacionFormResult>(
      context: context,
      builder: (ctx) => const _VacacionFormDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await widget.apiClient.createVacacion(
        token: widget.token,
        fechaDesde: result.fechaDesde,
        fechaHasta: result.fechaHasta,
        observaciones: result.observaciones,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud de vacaciones enviada.')),
      );
      unawaited(_load());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red[700],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar la solicitud.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelar(VacacionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: const Text(
          '¿Confirmás la cancelación de esta solicitud de vacaciones?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.apiClient.deleteVacacion(
        token: widget.token,
        id: item.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada.')),
      );
      unawaited(_load());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vacaciones'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: _load,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _solicitar,
        icon: const Icon(Icons.add),
        label: const Text('Solicitar'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text('No hay solicitudes de vacaciones.'),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final item = _items[index];
          return _VacacionCard(
            item: item,
            onCancelar: () => _cancelar(item),
          );
        },
      ),
    );
  }
}

class _VacacionCard extends StatelessWidget {
  const _VacacionCard({required this.item, this.onCancelar});

  final VacacionItem item;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.beach_access_outlined, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.fechaDesde ?? '—'} → ${item.fechaHasta ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (item.observaciones != null) ...[
              const SizedBox(height: 6),
              Text(
                item.observaciones!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (onCancelar != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancelar,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar solicitud'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VacacionFormResult {
  const _VacacionFormResult({
    required this.fechaDesde,
    required this.fechaHasta,
    this.observaciones,
  });

  final String fechaDesde;
  final String fechaHasta;
  final String? observaciones;
}

class _VacacionFormDialog extends StatefulWidget {
  const _VacacionFormDialog();

  @override
  State<_VacacionFormDialog> createState() => _VacacionFormDialogState();
}

class _VacacionFormDialogState extends State<_VacacionFormDialog> {
  DateTime? _inicio;
  DateTime? _fin;
  final _observacionesCtrl = TextEditingController();

  @override
  void dispose() {
    _observacionesCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate({required bool isInicio}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isInicio) {
        _inicio = picked;
        if (_fin != null && _fin!.isBefore(picked)) _fin = null;
      } else {
        _fin = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _inicio != null && _fin != null && !_fin!.isBefore(_inicio!);

    return AlertDialog(
      title: const Text('Solicitar vacaciones'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Fecha inicio'),
            subtitle: Text(_inicio != null ? _displayDate(_inicio!) : 'Sin seleccionar'),
            onTap: () => _pickDate(isInicio: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Fecha fin'),
            subtitle: Text(_fin != null ? _displayDate(_fin!) : 'Sin seleccionar'),
            onTap: () => _pickDate(isInicio: false),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _observacionesCtrl,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () => Navigator.of(context).pop(
                    _VacacionFormResult(
                      fechaDesde: _formatDate(_inicio!),
                      fechaHasta: _formatDate(_fin!),
                      observaciones: _observacionesCtrl.text.trim().isEmpty
                          ? null
                          : _observacionesCtrl.text.trim(),
                    ),
                  )
              : null,
          child: const Text('Solicitar'),
        ),
      ],
    );
  }
}

