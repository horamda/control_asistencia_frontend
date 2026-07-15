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
  PedidoMercaderiaItem? _ultimoPedidoAprobado;

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
      // El resumen (para "repetir pedido anterior") se pide aparte y no bloquea
      // la carga principal si falla.
      PedidoMercaderiaItem? ultimoAprobado;
      try {
        final resumen = await widget.apiClient.getPedidosMercaderiaResumen(
          token: widget.token,
        );
        ultimoAprobado = resumen.ultimoPedidoAprobado;
      } catch (_) {
        ultimoAprobado = null;
      }
      if (!mounted) return;
      final page = results[0] as PedidosMercaderiaPageResult;
      final estado = results[1] as PedidoMercaderiaEstadoResponse;
      setState(() {
        _items = page.items;
        _total = page.total;
        _estado = estado;
        _ultimoPedidoAprobado = ultimoAprobado;
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

  Future<void> _abrir({
    PedidoMercaderiaItem? existente,
    PedidoMercaderiaItem? plantilla,
  }) async {
    final result = await Navigator.of(context).push<PedidoMercaderiaItem>(
      MaterialPageRoute(
        builder: (_) => _PedidoFormPage(
          apiClient: widget.apiClient,
          token: widget.token,
          existente: existente,
          plantilla: plantilla,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido cancelado.')));
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
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 1200
            ? 1040.0
            : constraints.maxWidth >= 900
            ? 900.0
            : double.infinity;
        final hPad = constraints.maxWidth < 600 ? 16.0 : 24.0;
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
              _loadMore();
            }
            return false;
          },
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  12,
                  hPad,
                  _puedeCrear ? 88 : 16,
                ),
                itemCount:
                    1 +
                    (_items.isNotEmpty ? _items.length : 1) +
                    (_loadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // Índice 0: banner de estado del mes actual
                  if (index == 0) return _buildPeriodoBanner();

                  final listIndex = index - 1;

                  if (_items.isEmpty && listIndex == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text('No hay pedidos de mercadería.'),
                      ),
                    );
                  }
                  if (_items.isNotEmpty && listIndex == _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final item = _items[listIndex];
                  return _PedidoCard(
                    item: item,
                    onEditar: item.estado == 'pendiente'
                        ? () => _abrir(existente: item)
                        : null,
                    onCancelar: item.estado == 'pendiente'
                        ? () => _cancelar(item)
                        : null,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodoBanner() {
    if (_estado == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final pedido = _estado!.pedido;
    final periodo = _estado!.periodo;

    final repetirAction = (_puedeCrear && _ultimoPedidoAprobado != null)
        ? _ContextoBannerAction(
            label: 'Repetir el anterior',
            onTap: () => _abrir(plantilla: _ultimoPedidoAprobado),
          )
        : null;

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
        secondaryAction: repetirAction,
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
        message: 'Tu pedido de $periodo fue cancelado. Podés armar uno nuevo.',
        action: _ContextoBannerAction(
          label: 'Nuevo pedido',
          onTap: () => _abrir(),
        ),
        secondaryAction: repetirAction,
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
    this.secondaryAction,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color onColor;
  final _ContextoBannerAction? action;
  final _ContextoBannerAction? secondaryAction;

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
                Text(message, style: TextStyle(color: onColor, fontSize: 13)),
                if (action != null || secondaryAction != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (action != null)
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
                      if (secondaryAction != null)
                        GestureDetector(
                          onTap: secondaryAction!.onTap,
                          child: Text(
                            secondaryAction!.label,
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
                if (item.totalBultos != null || item.totalUnidades != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${item.totalBultos ?? 0} bultos · ${item.totalUnidades ?? 0} unidades',
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
                        _formatPedidoCantidades(
                          l.cantidadBultos,
                          l.cantidadUnidades,
                        ),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: cs.error),
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
                      style: TextButton.styleFrom(foregroundColor: cs.error),
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
      'aprobado' => ('Aprobado', Colors.green.shade100, Colors.green.shade900),
      'rechazado' => ('Rechazado', cs.errorContainer, cs.onErrorContainer),
      'cancelado' => (
        'Cancelado',
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
      ),
      _ => (estado ?? '?', cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
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
    this.plantilla,
  });

  final MobileApiClient apiClient;
  final String token;
  final PedidoMercaderiaItem? existente;
  // Pedido aprobado anterior usado como base para "repetir pedido".
  // Solo aplica cuando `existente` es null (pedido nuevo).
  final PedidoMercaderiaItem? plantilla;

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

  late bool _mostrarAvisoPlantilla =
      widget.plantilla != null && widget.existente == null;

  @override
  void initState() {
    super.initState();
    final base = widget.existente ?? widget.plantilla;
    if (base != null) {
      for (final l in base.items) {
        _lineas.add(
          _LineaEntry(
            articuloId: l.articuloId,
            descripcion:
                l.descripcion ??
                l.codigoArticulo ??
                'Artículo #${l.articuloId}',
            cantidadBultos: l.cantidadBultos,
            cantidadUnidades: l.cantidadUnidades,
            unidadesPorBulto: l.unidadesPorBulto ?? 0,
          ),
        );
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
      final divs =
          collected.map((a) => a.division).whereType<String>().toSet().toList()
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

  void _addOrUpdate(
    CatalogoPedidoMercaderiaItem articulo,
    _PedidoCantidad cantidad,
  ) {
    if (cantidad.bultos <= 0 && cantidad.unidades <= 0) {
      setState(() => _lineas.removeWhere((l) => l.articuloId == articulo.id));
      return;
    }
    setState(() {
      final idx = _lineas.indexWhere((l) => l.articuloId == articulo.id);
      final entry = _LineaEntry(
        articuloId: articulo.id,
        descripcion:
            articulo.descripcion ??
            articulo.codigoArticulo ??
            'Artículo #${articulo.id}',
        cantidadBultos: cantidad.bultos,
        cantidadUnidades: cantidad.unidades,
        unidadesPorBulto: articulo.unidadesPorBulto ?? 0,
      );
      if (idx >= 0) {
        _lineas[idx] = entry;
      } else {
        _lineas.add(entry);
      }
    });
  }

  Future<void> _editarLineaDesdeCarrito(_LineaEntry l) async {
    final result = await _promptLineaCantidad(context, l);
    if (result == null || !mounted) return;
    setState(() {
      if (result.isEmpty) {
        _lineas.removeWhere((e) => e.articuloId == l.articuloId);
        return;
      }
      final idx = _lineas.indexWhere((e) => e.articuloId == l.articuloId);
      if (idx >= 0) {
        _lineas[idx] = _LineaEntry(
          articuloId: l.articuloId,
          descripcion: l.descripcion,
          cantidadBultos: result.bultos,
          cantidadUnidades: result.unidades,
          unidadesPorBulto: l.unidadesPorBulto,
        );
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
          .map(
            (l) => PedidoMercaderiaLinea(
              articuloId: l.articuloId,
              cantidadBultos: l.cantidadBultos,
              cantidadUnidades: l.cantidadUnidades,
            ),
          )
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
    final totalUnidades = _lineas.fold(0, (s, l) => s + l.totalUnidades);

    return Scaffold(
      appBar: AppBar(title: Text(esEdicion ? 'Editar pedido' : 'Nuevo pedido')),
      bottomNavigationBar: _buildBottomBar(totalBultos, totalUnidades),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth >= 1200
              ? 1040.0
              : constraints.maxWidth >= 900
              ? 900.0
              : double.infinity;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  if (_mostrarAvisoPlantilla) _buildAvisoPlantilla(),
                  if (_lineas.isNotEmpty) _buildCarrito(),
                  _buildFilters(),
                  Expanded(child: _buildCatalog()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvisoPlantilla() {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.history, size: 18, color: cs.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Precargamos los artículos de tu último pedido aprobado. '
                'Revisá las cantidades antes de enviar.',
                style: TextStyle(color: cs.onSecondaryContainer, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _mostrarAvisoPlantilla = false),
              color: cs.onSecondaryContainer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(int totalBultos, int totalUnidades) {
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Row(
                  children: [
                    Expanded(
                      child: _lineas.isEmpty
                          ? Text(
                              'Agregá artículos al pedido',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
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
                                  '${_formatPedidoCantidades(totalBultos, _lineas.fold(0, (s, l) => s + l.cantidadUnidades))} · $totalUnidades unidades equivalentes',
                                  style: Theme.of(context).textTheme.bodySmall
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
                      label: Text(
                        widget.existente != null
                            ? 'Guardar cambios'
                            : 'Enviar pedido',
                      ),
                    ),
                  ],
                ),
              ),
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
                return InputChip(
                  label: Text(
                    '${l.descripcion}: ${_formatPedidoCantidades(l.cantidadBultos, l.cantidadUnidades)}',
                    maxLines: 1,
                  ),
                  onPressed: () => _editarLineaDesdeCarrito(l),
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
    final rows = _catalogRows();
    if (rows.isEmpty) {
      return const Center(child: Text('Sin resultados.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) {
          return _DivisionHeader(label: row);
        }
        final art = row as CatalogoPedidoMercaderiaItem;
        final existing = _lineas
            .where((l) => l.articuloId == art.id)
            .firstOrNull;
        return _ArticuloTile(
          articulo: art,
          cantidadActual: _PedidoCantidad(
            bultos: existing?.cantidadBultos ?? 0,
            unidades: existing?.cantidadUnidades ?? 0,
          ),
          onChanged: (cantidad) => _addOrUpdate(art, cantidad),
        );
      },
    );
  }

  /// Agrupa el catálogo por división para que sea más rápido de escanear.
  /// Se omite el agrupamiento si ya hay un filtro de división o búsqueda
  /// activos, ya que en ese caso el listado plano es más directo.
  List<Object> _catalogRows() {
    final items = _filtered;
    if (_query.isNotEmpty || _divisionFiltro != null) return items.cast();
    final sorted = [...items]
      ..sort((a, b) {
        final cmp = (a.division ?? '').compareTo(b.division ?? '');
        if (cmp != 0) return cmp;
        return (a.descripcion ?? '').compareTo(b.descripcion ?? '');
      });
    final rows = <Object>[];
    String? lastDivision;
    for (final art in sorted) {
      final div = art.division ?? 'Sin división';
      if (div != lastDivision) {
        rows.add(div);
        lastDivision = div;
      }
      rows.add(art);
    }
    return rows;
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
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _DivisionHeader extends StatelessWidget {
  const _DivisionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
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
    required this.cantidadUnidades,
    required this.unidadesPorBulto,
  });

  final int articuloId;
  final String descripcion;
  final int cantidadBultos;
  final int cantidadUnidades;
  final int unidadesPorBulto;

  int get totalUnidades => cantidadBultos * unidadesPorBulto + cantidadUnidades;
}

class _PedidoCantidad {
  const _PedidoCantidad({required this.bultos, required this.unidades});

  final int bultos;
  final int unidades;

  bool get isEmpty => bultos == 0 && unidades == 0;
}

class _ArticuloTile extends StatelessWidget {
  const _ArticuloTile({
    required this.articulo,
    required this.cantidadActual,
    required this.onChanged,
  });

  final CatalogoPedidoMercaderiaItem articulo;
  final _PedidoCantidad cantidadActual;
  final ValueChanged<_PedidoCantidad> onChanged;

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
    final inCart = !cantidadActual.isEmpty;
    return Material(
      color: inCart
          ? cs.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: SizedBox(
          width: 22,
          child: inCart
              ? Icon(Icons.check_circle, color: cs.primary, size: 22)
              : null,
        ),
        title: Text(
          articulo.descripcion ??
              articulo.codigoArticulo ??
              'Artículo #${articulo.id}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _buildSubtitle(),
        trailing: SizedBox(
          width: 184,
          child: Row(
            children: [
              Expanded(
                child: _CantidadStepper(
                  label: 'Bultos',
                  value: cantidadActual.bultos,
                  onChanged: (value) => onChanged(
                    _PedidoCantidad(
                      bultos: value,
                      unidades: cantidadActual.unidades,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _CantidadStepper(
                  label: 'Unidades',
                  value: cantidadActual.unidades,
                  onChanged: (value) => onChanged(
                    _PedidoCantidad(
                      bultos: cantidadActual.bultos,
                      unidades: value,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CantidadStepper extends StatelessWidget {
  const _CantidadStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  Future<void> _editar(BuildContext context) async {
    final result = await _promptQuantity(context, label: label, initial: value);
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          SizedBox(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.remove_circle_outline, size: 19),
                  onPressed: value > 0 ? () => onChanged(value - 1) : null,
                ),
                InkWell(
                  onTap: () => _editar(context),
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 28,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add_circle_outline, size: 19),
                  onPressed: () => onChanged(value + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Muestra un diálogo simple para tipear una cantidad en lugar de tocar +/-
/// repetidamente. Devuelve null si se cancela.
Future<int?> _promptQuantity(
  BuildContext context, {
  required String label,
  required int initial,
}) {
  final ctrl = TextEditingController(text: initial == 0 ? '' : '$initial');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        onSubmitted: (_) => Navigator.of(ctx).pop(_parseQuantity(ctrl.text)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(_parseQuantity(ctrl.text)),
          child: const Text('Listo'),
        ),
      ],
    ),
  );
}

// ─── Sheet de confirmación ────────────────────────────────────────────────────

class _PedidoConfirmSheet extends StatelessWidget {
  const _PedidoConfirmSheet({required this.lineas, required this.esEdicion});

  final List<_LineaEntry> lineas;
  final bool esEdicion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalBultos = lineas.fold(0, (s, l) => s + l.cantidadBultos);
    final unidadesSueltas = lineas.fold(0, (s, l) => s + l.cantidadUnidades);
    final totalUnidades = lineas.fold(0, (s, l) => s + l.totalUnidades);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Revisá los artículos antes de enviar.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatPedidoCantidades(
                              l.cantidadBultos,
                              l.cantidadUnidades,
                            ),
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_formatPedidoCantidades(totalBultos, unidadesSueltas)} · $totalUnidades unidades equivalentes',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
        ),
      ),
    );
  }
}

/// Diálogo para editar bultos y unidades de una línea ya agregada al carrito,
/// sin tener que volver a buscar el artículo en el catálogo completo.
/// Devuelve null si se cancela.
Future<_PedidoCantidad?> _promptLineaCantidad(
  BuildContext context,
  _LineaEntry linea,
) {
  final bultosCtrl = TextEditingController(
    text: linea.cantidadBultos == 0 ? '' : '${linea.cantidadBultos}',
  );
  final unidadesCtrl = TextEditingController(
    text: linea.cantidadUnidades == 0 ? '' : '${linea.cantidadUnidades}',
  );
  return showDialog<_PedidoCantidad>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        linea.descripcion,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: TextField(
              controller: bultosCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Bultos'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: unidadesCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Unidades'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            ctx,
          ).pop(const _PedidoCantidad(bultos: 0, unidades: 0)),
          child: const Text('Quitar del pedido'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(
            _PedidoCantidad(
              bultos: _parseQuantity(bultosCtrl.text),
              unidades: _parseQuantity(unidadesCtrl.text),
            ),
          ),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

int _parseQuantity(String text) {
  final parsed = int.tryParse(text.trim()) ?? 0;
  return parsed < 0 ? 0 : parsed;
}

String _formatPedidoCantidades(int bultos, int unidades) {
  final parts = <String>[];
  if (bultos > 0) {
    parts.add('$bultos bulto${bultos == 1 ? '' : 's'}');
  }
  if (unidades > 0) {
    parts.add('$unidades unidad${unidades == 1 ? '' : 'es'}');
  }
  return parts.isEmpty ? 'Sin cantidad' : parts.join(' + ');
}
