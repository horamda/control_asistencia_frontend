import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class LegajoPage extends StatefulWidget {
  const LegajoPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<LegajoPage> createState() => _LegajoPageState();
}

class _LegajoPageState extends State<LegajoPage> {
  bool _loading = true;
  String? _error;
  List<LegajoEventoItem> _items = [];
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
      final result = await widget.apiClient.getLegajoEventos(
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
        _error = 'Error inesperado al cargar el legajo.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.apiClient.getLegajoEventos(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legajo'),
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
      return const Center(child: Text('No hay eventos en el legajo.'));
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _LegajoEventoCard(item: _items[index]);
        },
      ),
    );
  }
}

class _LegajoEventoCard extends StatelessWidget {
  const _LegajoEventoCard({required this.item});

  final LegajoEventoItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final severidad = item.severidad;
    final severidadColor = switch (severidad) {
      'grave' => Colors.red[700]!,
      'media' => Colors.orange[700]!,
      'leve' => Colors.amber[700]!,
      _ => cs.onSurfaceVariant,
    };
    final anulado = item.estado == 'anulado';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description_outlined, size: 20, color: severidadColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.tipoNombre ?? item.tipoCodigo ?? 'Evento',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: anulado ? TextDecoration.lineThrough : null,
                      color: anulado ? cs.onSurfaceVariant : null,
                    ),
                  ),
                ),
                if (item.fechaEvento != null)
                  Text(
                    item.fechaEvento!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (item.titulo != null) ...[
              const SizedBox(height: 6),
              Text(
                item.titulo!,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
            if (item.descripcion != null) ...[
              const SizedBox(height: 4),
              Text(
                item.descripcion!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (severidad != null || anulado) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (severidad != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: severidadColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        severidad,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: severidadColor,
                        ),
                      ),
                    ),
                  if (anulado) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Anulado',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (item.fechaDesde != null || item.fechaHasta != null) ...[
              const SizedBox(height: 4),
              Text(
                'Vigencia: ${item.fechaDesde ?? '—'} → ${item.fechaHasta ?? 'indefinida'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
