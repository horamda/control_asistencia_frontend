import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class HistorialAdelantosPage extends StatefulWidget {
  const HistorialAdelantosPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<HistorialAdelantosPage> createState() => _HistorialAdelantosPageState();
}

class _HistorialAdelantosPageState extends State<HistorialAdelantosPage> {
  bool _loading = true;
  String? _error;
  List<AdelantoItem> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;
  static const _per = 20;

  static const _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

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
      final result = await widget.apiClient.getAdelantos(
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
        _error = 'Error inesperado al cargar el historial.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.apiClient.getAdelantos(
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

  String _mesLabel(int month, int year) {
    final nombre = (month >= 1 && month <= 12) ? _meses[month] : '—';
    return '$nombre $year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de adelantos'),
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
      return const Center(
        child: Text('No hay solicitudes de adelanto en el historial.'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _AdelantoHistorialCard(
            item: _items[index],
            mesLabel: _mesLabel(
              _items[index].periodoMonth,
              _items[index].periodoYear,
            ),
          );
        },
      ),
    );
  }
}

class _AdelantoHistorialCard extends StatelessWidget {
  const _AdelantoHistorialCard({
    required this.item,
    required this.mesLabel,
  });

  final AdelantoItem item;
  final String mesLabel;

  @override
  Widget build(BuildContext context) {
    final estado = item.estado ?? 'pendiente';
    final (label, color, icon) = switch (estado) {
      'aprobado' => ('Aprobado', Colors.green[700]!, Icons.check_circle_outline),
      'rechazado' => ('Rechazado', Colors.red[700]!, Icons.cancel_outlined),
      'cancelado' => ('Cancelado', Colors.grey[600]!, Icons.block_outlined),
      _ => (
          'Pendiente',
          Colors.amber[700]!,
          Icons.hourglass_empty_outlined,
        ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: color, size: 28),
        title: Text(
          mesLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
            if (item.fechaSolicitud != null)
              Text(
                'Solicitado: ${item.fechaSolicitud}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (item.resueltoAt != null)
              Text(
                'Resuelto: ${item.resueltoAt}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
