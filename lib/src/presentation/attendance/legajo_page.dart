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

class _LegajoPageState extends State<LegajoPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legajo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Eventos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ResumenTab(apiClient: widget.apiClient, token: widget.token),
          _EventosTab(apiClient: widget.apiClient, token: widget.token),
        ],
      ),
    );
  }
}

// ─── Tab Resumen ──────────────────────────────────────────────────────────────

class _ResumenTab extends StatefulWidget {
  const _ResumenTab({required this.apiClient, required this.token});
  final MobileApiClient apiClient;
  final String token;

  @override
  State<_ResumenTab> createState() => _ResumenTabState();
}

class _ResumenTabState extends State<_ResumenTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  LegajoResumenResponse? _resumen;
  List<LegajoHistorialPorTipoItem> _porTipo = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiClient.getLegajoResumen(token: widget.token),
        widget.apiClient.getLegajoHistorialPorTipo(token: widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _resumen = results[0] as LegajoResumenResponse;
        _porTipo = results[1] as List<LegajoHistorialPorTipoItem>;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

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

    final resumen = _resumen!;
    final hist = resumen.resumen.historico;
    final per = resumen.resumen.periodo;
    final recientes = resumen.resumen.recientes;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tarjetas de totales históricos ──
          _SectionHeader('Historial completo'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total',
                  value: '${hist.total}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Vigentes',
                  value: '${hist.vigentes}',
                  color: Colors.green[700]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Anulados',
                  value: '${hist.anulados}',
                  color: Colors.grey[600]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Período actual ──
          if (per.total > 0) ...[
            _SectionHeader(
              'Período${resumen.periodo.desde != null ? ' (${resumen.periodo.desde} – ${resumen.periodo.hasta ?? 'hoy'})' : ''}',
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SeveridadBadge(
                      label: 'Graves',
                      count: per.graves,
                      color: Colors.red[700]!,
                    ),
                    _SeveridadBadge(
                      label: 'Media',
                      count: per.media,
                      color: Colors.orange[700]!,
                    ),
                    _SeveridadBadge(
                      label: 'Leve',
                      count: per.leve,
                      color: Colors.amber[700]!,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Por categoría ──
          if (_porTipo.isNotEmpty) ...[
            _SectionHeader('Por categoría'),
            const SizedBox(height: 8),
            ..._porTipo.map((item) => _TipoCard(item: item)),
            const SizedBox(height: 20),
          ],

          // ── Eventos recientes ──
          if (recientes.isNotEmpty) ...[
            _SectionHeader('Eventos recientes'),
            const SizedBox(height: 8),
            ...recientes.map(
              (e) => _LegajoEventoCard(item: e, compact: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
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

class _SeveridadBadge extends StatelessWidget {
  const _SeveridadBadge({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TipoCard extends StatelessWidget {
  const _TipoCard({required this.item});
  final LegajoHistorialPorTipoItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tieneEventos = item.total > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              tieneEventos
                  ? Icons.description_outlined
                  : Icons.check_circle_outline,
              color: tieneEventos ? cs.primary : Colors.green,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (item.ultimaFecha != null)
                    Text(
                      'Último: ${item.ultimaFecha}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (tieneEventos)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.total}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: cs.primary,
                    ),
                  ),
                  Text(
                    '${item.vigentes} vigente${item.vigentes != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Sin eventos',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab Eventos ──────────────────────────────────────────────────────────────

class _EventosTab extends StatefulWidget {
  const _EventosTab({required this.apiClient, required this.token});
  final MobileApiClient apiClient;
  final String token;

  @override
  State<_EventosTab> createState() => _EventosTabState();
}

class _EventosTabState extends State<_EventosTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<LegajoEventoItem> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;
  static const _per = 20;

  // Filtros activos
  String? _filterEstado;    // 'vigente' | 'anulado'
  String? _filterSeveridad; // 'grave' | 'media' | 'leve'

  @override
  bool get wantKeepAlive => true;

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
        estado: _filterEstado,
        severidad: _filterSeveridad,
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
        _error = 'Error inesperado al cargar los eventos.';
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
        estado: _filterEstado,
        severidad: _filterSeveridad,
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

  void _setEstado(String? value) {
    if (_filterEstado == value) return;
    setState(() => _filterEstado = value);
    _load();
  }

  void _setSeveridad(String? value) {
    if (_filterSeveridad == value) return;
    setState(() => _filterSeveridad = value);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        _buildFilters(),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildFilters() {
    final cs = Theme.of(context).colorScheme;

    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: cs.primaryContainer,
          checkmarkColor: cs.onPrimaryContainer,
          labelStyle: TextStyle(
            color: selected ? cs.onPrimaryContainer : null,
            fontSize: 12,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('Todos', _filterEstado == null, () => _setEstado(null)),
                chip(
                  'Vigentes',
                  _filterEstado == 'vigente',
                  () => _setEstado('vigente'),
                ),
                chip(
                  'Anulados',
                  _filterEstado == 'anulado',
                  () => _setEstado('anulado'),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 20,
                  color: cs.outlineVariant,
                ),
                const SizedBox(width: 8),
                chip(
                  'Grave',
                  _filterSeveridad == 'grave',
                  () => _setSeveridad(
                    _filterSeveridad == 'grave' ? null : 'grave',
                  ),
                ),
                chip(
                  'Media',
                  _filterSeveridad == 'media',
                  () => _setSeveridad(
                    _filterSeveridad == 'media' ? null : 'media',
                  ),
                ),
                chip(
                  'Leve',
                  _filterSeveridad == 'leve',
                  () => _setSeveridad(
                    _filterSeveridad == 'leve' ? null : 'leve',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());

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
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            Center(child: Text('No hay eventos con los filtros seleccionados.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
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
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return _LegajoEventoCard(item: _items[index]);
          },
        ),
      ),
    );
  }
}

// ─── Card de evento ───────────────────────────────────────────────────────────

class _LegajoEventoCard extends StatelessWidget {
  const _LegajoEventoCard({required this.item, this.compact = false});

  final LegajoEventoItem item;
  final bool compact;

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
                Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: severidadColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.tipoNombre ?? item.tipoCodigo ?? 'Evento',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration:
                          anulado ? TextDecoration.lineThrough : null,
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
            if (!compact && item.descripcion != null) ...[
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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
            if (!compact &&
                (item.fechaDesde != null || item.fechaHasta != null)) ...[
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
