import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

// ─── Pantalla principal ───────────────────────────────────────────────────────

class PedidosMercaderiaPage extends StatefulWidget {
  const PedidosMercaderiaPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<PedidosMercaderiaPage> createState() => _PedidosMercaderiaPageState();
}

class _PedidosMercaderiaPageState extends State<PedidosMercaderiaPage> {
  bool _loading = true;
  String? _error;
  List<PedidoMercaderiaItem> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;
  static const _per = 20;

  PedidoMercaderiaEstadoResponse? _estado;

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
      final results = await Future.wait([
        widget.apiClient.getPedidosMercaderia(
          token: widget.token,
          page: 1,
          per: _per,
        ),
        widget.apiClient.getPedidosMercaderiaEstado(token: widget.token),
      ]);
      if (!mounted) return;
      final page = results[0] as PedidosMercaderiaPageResult;
      final estado = results[1] as PedidoMercaderiaEstadoResponse;
      setState(() {
        _items = page.items;
        _total = page.total;
        _estado = estado;
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
        _error = 'Error inesperado al cargar los pedidos.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.apiClient.getPedidosMercaderia(
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

  Future<void> _abrir({PedidoMercaderiaItem? existente}) async {
    final result = await Navigator.of(context).push<PedidoMercaderiaItem>(
      MaterialPageRoute(
        builder: (_) => _PedidoFormPage(
          apiClient: widget.apiClient,
          token: widget.token,
          existente: existente,
        ),
      ),
    );
    if (result == null || !mounted) return;
    unawaited(_load());
  }

  Future<void> _cancelar(PedidoMercaderiaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text(
          '¿Confirmás la cancelación de este pedido de mercadería?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.apiClient.cancelPedidoMercaderia(
        token: widget.token,
        id: item.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido cancelado.')),
      );
      unawaited(_load());
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red[700]),
      );
    }
  }

  // Permite crear si no hay pedido este mes, o si el pedido del mes fue cancelado.
  bool get _puedeCrear {
    if (_estado == null) return false;
    if (!_estado!.yaSolicitado) return true;
    return _estado!.pedido?.estado == 'cancelado';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos de Mercadería'),
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
      floatingActionButton: _puedeCrear
          ? FloatingActionButton.extended(
              onPressed: () => _abrir(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo pedido'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) _loadMore();
        return false;
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, _puedeCrear ? 88 : 16),
        itemCount: 1 + (_items.isNotEmpty ? _items.length : 1) + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Índice 0: banner de estado del mes actual
          if (index == 0) return _buildPeriodoBanner();

          final listIndex = index - 1;

          if (_items.isEmpty && listIndex == 0) {
            return const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('No hay pedidos de mercadería.')),
            );
          }
          if (_items.isNotEmpty && listIndex == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final item = _items[listIndex];
          return _PedidoCard(
            item: item,
            onEditar: item.estado == 'pendiente'
                ? () => _abrir(existente: item)
                : null,
            onCancelar:
                item.estado == 'pendiente' ? () => _cancelar(item) : null,
          );
        },
      ),
    );
  }

  Widget _buildPeriodoBanner() {
    if (_estado == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final pedido = _estado!.pedido;
    final periodo = _estado!.periodo;

    if (pedido == null) {
      return _ContextoBanner(
        icon: Icons.inventory_2_outlined,
        message: 'No tenés pedido para $periodo.',
        action: _puedeCrear
            ? _ContextoBannerAction(
                label: 'Hacer pedido',
                onTap: () => _abrir(),
              )
            : null,
        color: cs.primaryContainer,
        onColor: cs.onPrimaryContainer,
      );
    }

    return switch (pedido.estado) {
      'pendiente' => _ContextoBanner(
          icon: Icons.pending_outlined,
          message: 'Tu pedido de $periodo está pendiente de aprobación.',
          action: _ContextoBannerAction(
            label: 'Editar',
            onTap: () => _abrir(existente: pedido),
          ),
          color: cs.primaryContainer,
          onColor: cs.onPrimaryContainer,
        ),
      'aprobado' => _ContextoBanner(
          icon: Icons.check_circle_outline,
          message: 'Tu pedido de $periodo fue aprobado.',
          color: Colors.green.shade100,
          onColor: Colors.green.shade900,
        ),
      'rechazado' => _ContextoBanner(
          icon: Icons.cancel_outlined,
          message: pedido.motivoRechazo != null
              ? 'Tu pedido de $periodo fue rechazado: ${pedido.motivoRechazo}'
              : 'Tu pedido de $periodo fue rechazado.',
          color: cs.errorContainer,
          onColor: cs.onErrorContainer,
        ),
      'cancelado' => _ContextoBanner(
          icon: Icons.info_outline,
          message:
              'Tu pedido de $periodo fue cancelado. Podés armar uno nuevo.',
          action: _ContextoBannerAction(
            label: 'Nuevo pedido',
            onTap: () => _abrir(),
          ),
          color: cs.surfaceContainerHighest,
          onColor: cs.onSurfaceVariant,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ─── Banner de contexto ───────────────────────────────────────────────────────

class _ContextoBannerAction {
  const _ContextoBannerAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

class _ContextoBanner extends StatelessWidget {
  const _ContextoBanner({
    required this.icon,
    required this.message,
    required this.color,
    required this.onColor,
    this.action,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color onColor;
  final _ContextoBannerAction? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: onColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(color: onColor, fontSize: 13),
                ),
                if (action != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: action!.onTap,
                    child: Text(
                      action!.label,
                      style: TextStyle(
                        color: onColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: onColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _PedidoCard extends StatelessWidget {
  const _PedidoCard({required this.item, this.onEditar, this.onCancelar});

  final PedidoMercaderiaItem item;
  final VoidCallback? onEditar;
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
                const Icon(Icons.inventory_2_outlined, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.periodo ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (item.totalBultos != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${item.totalBultos} bulto${item.totalBultos == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                _EstadoChip(estado: item.estado),
              ],
            ),
            if (item.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...item.items.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 30),
                      Expanded(
                        child: Text(
                          l.descripcion ??
                              l.codigoArticulo ??
                              'Artículo #${l.articuloId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${l.cantidadBultos} bulto${l.cantidadBultos == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (item.motivoRechazo != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: cs.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.motivoRechazo!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.error,
                          ),
                    ),
                  ),
                ],
              ),
            ],
            if (onEditar != null || onCancelar != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEditar != null)
                    TextButton.icon(
                      onPressed: onEditar,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                  if (onCancelar != null)
                    TextButton.icon(
                      onPressed: onCancelar,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancelar'),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({this.estado});

  final String? estado;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (estado) {
      'pendiente' => ('Pendiente', cs.primaryContainer, cs.onPrimaryContainer),
      'aprobado' => (
          'Aprobado',
          Colors.green.shade100,
          Colors.green.shade900,
        ),
      'rechazado' => ('Rechazado', cs.errorContainer, cs.onErrorContainer),
      'cancelado' => (
          'Cancelado',
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
        ),
      _ => (
          estado ?? '?',
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Formulario ───────────────────────────────────────────────────────────────

class _PedidoFormPage extends StatefulWidget {
  const _PedidoFormPage({
    required this.apiClient,
    required this.token,
    this.existente,
  });

  final MobileApiClient apiClient;
  final String token;
  final PedidoMercaderiaItem? existente;

  @override
  State<_PedidoFormPage> createState() => _PedidoFormPageState();
}

class _PedidoFormPageState extends State<_PedidoFormPage> {
  // — carrito —
  final List<_LineaEntry> _lineas = [];

  // — catálogo completo (carga eager) —
  bool _loadingCatalog = true;
  String? _catalogError;
  List<CatalogoPedidoMercaderiaItem> _allItems = [];

  // — filtros client-side —
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _divisionFiltro;
  List<String> _divisions = [];

  // — submit —
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    if (widget.existente != null) {
      for (final l in widget.existente!.items) {
        _lineas.add(_LineaEntry(
          articuloId: l.articuloId,
          descripcion:
              l.descripcion ?? l.codigoArticulo ?? 'Artículo #${l.articuloId}',
          cantidadBultos: l.cantidadBultos,
        ));
      }
    }
    _searchCtrl.addListener(_onQueryChanged);
    _loadAllCatalog();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (_searchCtrl.text != _query) {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    }
  }

  Future<void> _loadAllCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
      _allItems = [];
    });
    try {
      const perPage = 100;
      var page = 1;
      final collected = <CatalogoPedidoMercaderiaItem>[];
      while (true) {
        final result = await widget.apiClient.getPedidosMercaderiaArticulos(
          token: widget.token,
          page: page,
          per: perPage,
        );
        collected.addAll(result.items);
        if (collected.length >= result.total || result.items.isEmpty) break;
        page++;
      }
      if (!mounted) return;
      final divs = collected
          .map((a) => a.division)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _allItems = collected;
        _divisions = divs;
        _loadingCatalog = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogError = 'No se pudo cargar el catálogo.';
        _loadingCatalog = false;
      });
    }
  }

  List<CatalogoPedidoMercaderiaItem> get _filtered {
    return _allItems.where((a) {
      final matchesDivision =
          _divisionFiltro == null || a.division == _divisionFiltro;
      if (!matchesDivision) return false;
      if (_query.isEmpty) return true;
      return (a.descripcion?.toLowerCase().contains(_query) ?? false) ||
          (a.codigoArticulo?.toLowerCase().contains(_query) ?? false) ||
          (a.marca?.toLowerCase().contains(_query) ?? false) ||
          (a.familia?.toLowerCase().contains(_query) ?? false) ||
          (a.sabor?.toLowerCase().contains(_query) ?? false);
    }).toList();
  }

  void _addOrUpdate(CatalogoPedidoMercaderiaItem articulo, int cantidad) {
    if (cantidad <= 0) {
      setState(
        () => _lineas.removeWhere((l) => l.articuloId == articulo.id),
      );
      return;
    }
    setState(() {
      final idx = _lineas.indexWhere((l) => l.articuloId == articulo.id);
      final entry = _LineaEntry(
        articuloId: articulo.id,
        descripcion: articulo.descripcion ??
            articulo.codigoArticulo ??
            'Artículo #${articulo.id}',
        cantidadBultos: cantidad,
      );
      if (idx >= 0) {
        _lineas[idx] = entry;
      } else {
        _lineas.add(entry);
      }
    });
  }

  Future<void> _confirmAndSubmit() async {
    if (_lineas.isEmpty || _submitting) return;
    FocusScope.of(context).unfocus();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PedidoConfirmSheet(
        lineas: List.unmodifiable(_lineas),
        esEdicion: widget.existente != null,
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final lineas = _lineas
          .map((l) => PedidoMercaderiaLinea(
                articuloId: l.articuloId,
                cantidadBultos: l.cantidadBultos,
              ))
          .toList();

      final PedidoMercaderiaItem pedido;
      if (widget.existente != null) {
        pedido = await widget.apiClient.updatePedidoMercaderia(
          token: widget.token,
          id: widget.existente!.id,
          items: lineas,
        );
      } else {
        pedido = await widget.apiClient.createPedidoMercaderia(
          token: widget.token,
          items: lineas,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(pedido);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Error inesperado. Intentá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.existente != null;
    final totalBultos = _lineas.fold(0, (s, l) => s + l.cantidadBultos);

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar pedido' : 'Nuevo pedido'),
      ),
      bottomNavigationBar: _buildBottomBar(totalBultos),
      body: Column(
        children: [
          if (_lineas.isNotEmpty) _buildCarrito(),
          _buildFilters(),
          Expanded(child: _buildCatalog()),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int totalBultos) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_submitError != null) _buildErrorBanner(),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _lineas.isEmpty
                      ? Text(
                          'Agregá artículos al pedido',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_lineas.length} artículo${_lineas.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '$totalBultos bulto${totalBultos == 1 ? '' : 's'} en total',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _lineas.isNotEmpty && !_submitting
                      ? _confirmAndSubmit
                      : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(widget.existente != null ? 'Guardar cambios' : 'Enviar pedido'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 18,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _submitError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _submitError = null),
              color: Theme.of(context).colorScheme.onErrorContainer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarrito() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Seleccionados (${_lineas.length})',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _lineas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final l = _lineas[i];
                return Chip(
                  label: Text(
                    '${l.descripcion} ×${l.cantidadBultos}',
                    maxLines: 1,
                  ),
                  onDeleted: () => setState(
                    () => _lineas.removeWhere(
                      (e) => e.articuloId == l.articuloId,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, código, marca...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
          ),
          if (_divisions.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _DivisionChip(
                    label: 'Todos',
                    selected: _divisionFiltro == null,
                    onTap: () => setState(() => _divisionFiltro = null),
                  ),
                  const SizedBox(width: 6),
                  ..._divisions.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _DivisionChip(
                        label: d,
                        selected: _divisionFiltro == d,
                        onTap: () => setState(
                          () =>
                              _divisionFiltro = _divisionFiltro == d ? null : d,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCatalog() {
    if (_loadingCatalog) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Cargando catálogo...'),
          ],
        ),
      );
    }
    if (_catalogError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_catalogError!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadAllCatalog,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return const Center(child: Text('Sin resultados.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final art = items[index];
        final existing =
            _lineas.where((l) => l.articuloId == art.id).firstOrNull;
        return _ArticuloTile(
          articulo: art,
          cantidadActual: existing?.cantidadBultos ?? 0,
          onChanged: (qty) => _addOrUpdate(art, qty),
        );
      },
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _DivisionChip extends StatelessWidget {
  const _DivisionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

class _LineaEntry {
  const _LineaEntry({
    required this.articuloId,
    required this.descripcion,
    required this.cantidadBultos,
  });

  final int articuloId;
  final String descripcion;
  final int cantidadBultos;
}

class _ArticuloTile extends StatelessWidget {
  const _ArticuloTile({
    required this.articulo,
    required this.cantidadActual,
    required this.onChanged,
  });

  final CatalogoPedidoMercaderiaItem articulo;
  final int cantidadActual;
  final ValueChanged<int> onChanged;

  Widget? _buildSubtitle() {
    final parts = <String>[
      if (articulo.codigoArticulo != null) articulo.codigoArticulo!,
      if (articulo.unidadesPorBulto != null)
        '${articulo.unidadesPorBulto} u/bulto',
      if (articulo.marca != null) articulo.marca!,
      if (articulo.familia != null) articulo.familia!,
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inCart = cantidadActual > 0;
    return Material(
      color: inCart
          ? cs.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          articulo.descripcion ??
              articulo.codigoArticulo ??
              'Artículo #${articulo.id}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _buildSubtitle(),
        trailing: cantidadActual == 0
            ? IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onChanged(1),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => onChanged(cantidadActual - 1),
                  ),
                  Text(
                    '$cantidadActual',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => onChanged(cantidadActual + 1),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Sheet de confirmación ────────────────────────────────────────────────────

class _PedidoConfirmSheet extends StatelessWidget {
  const _PedidoConfirmSheet({
    required this.lineas,
    required this.esEdicion,
  });

  final List<_LineaEntry> lineas;
  final bool esEdicion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalBultos = lineas.fold(0, (s, l) => s + l.cantidadBultos);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            esEdicion ? 'Confirmar cambios' : 'Confirmar pedido',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Revisá los artículos antes de enviar.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: lineas.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final l = lineas[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.descripcion,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${l.cantidadBultos} bulto${l.cantidadBultos == 1 ? '' : 's'}',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$totalBultos bulto${totalBultos == 1 ? '' : 's'}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.send_outlined),
              label: Text(esEdicion ? 'Guardar cambios' : 'Enviar pedido'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Revisar pedido'),
            ),
          ),
        ],
      ),
    );
  }
}
