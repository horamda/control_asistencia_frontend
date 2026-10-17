import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/app_page_layout.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/epp/epp_models.dart';
import '../../core/network/mobile_api_client.dart';

String _error(Object e) => e is ApiException
    ? e.message
    : 'No se pudo completar la operación. Reintentá.';

class EppPage extends StatefulWidget {
  const EppPage({super.key, required this.api, required this.token});
  final MobileApiClient api;
  final String token;
  @override
  State<EppPage> createState() => _EppPageState();
}

class _EppPageState extends State<EppPage> with WidgetsBindingObserver {
  int _tab = 0, _page = 1, _total = 0, _year = DateTime.now().year;
  String _state = '';
  EppConfig? _config;
  List<EppData> _rows = [];
  bool _busy = false;
  String? _failure;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final config = EppConfig(
        await widget.api.getEppConfig(token: widget.token),
      );
      final result = _tab == 0
          ? <String, dynamic>{}
          : await widget.api.getEpp(
              token: widget.token,
              path: _tab == 1 ? '/pedidos' : '/resumen',
              query: _tab == 1
                  ? {'page': '$_page', if (_state.isNotEmpty) 'estado': _state}
                  : {'anio': '$_year'},
            );
      if (mounted && request == _request) {
        setState(() {
          _config = config;
          _rows = eppRows(result['items']);
          _total = eppInt(result['total']);
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _failure = _error(e));
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _edit([EppData? order]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _EppEditor(api: widget.api, token: widget.token, order: order),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _detail(EppData order) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _EppDetail(
          api: widget.api,
          token: widget.token,
          id: eppInt(order['id']),
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _size(EppArticle article) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SizeDialog(
        api: widget.api,
        token: widget.token,
        article: article,
        saved: _config!.saved(article.id),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('EPP y vestimenta', textAlign: TextAlign.center),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: _tab != 2 && _config != null && _failure == null
        ? AppFloatingActionButton(
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Solicitar EPP', textAlign: TextAlign.center),
          )
        : null,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: Text(
                          ['Mis talles', 'Mis pedidos', 'Resumen anual'][i],
                          textAlign: TextAlign.center,
                        ),
                        selected: _tab == i,
                        showCheckmark: false,
                        onSelected: _busy
                            ? null
                            : (_) {
                                setState(() {
                                  _tab = i;
                                  _page = 1;
                                  _rows = [];
                                });
                                _load();
                              },
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 3,
                child: _busy ? const LinearProgressIndicator() : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    key: ValueKey(_tab),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      _tab != 2
                          ? AppFloatingActionButton.bottomPadding(context)
                          : 16,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_failure != null) _Failure(_failure!, retry: _load),
                      if (_failure == null && _config != null) ...[
                        if (_tab == 0) ...[
                          Text(
                            'Elegí tus talles',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            'Guardalos por artículo. Al solicitar EPP te pediremos que los confirmes.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          if (_config!.articles.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No hay artículos habilitados para tu sector y puesto.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          for (final a in _config!.articles)
                            AppCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (a.hasImage)
                                      _PrivateImage(
                                        api: widget.api,
                                        token: widget.token,
                                        path: '/imagenes/articulos/${a.id}',
                                      ),
                                    Text(
                                      a.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      a.category,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (a.description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          a.description,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    Text(
                                      'Talle guardado: ${_config!.saved(a.id)['talle'] ?? 'Sin definir'}',
                                      textAlign: TextAlign.center,
                                    ),
                                    if (a.annualNotice > 0)
                                      Text(
                                        'Orientación anual: ${a.annualNotice} unidades. No es un límite.',
                                        textAlign: TextAlign.center,
                                      ),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () => _size(a),
                                      child: const Text(
                                        'Configurar talle',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        if (_tab == 1) ...[
                          Text(
                            'Tus pedidos',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Consultá el estado y las entregas de tus solicitudes.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          DropdownButtonFormField<String>(
                            initialValue: _state,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Filtrar por estado',
                              prefixIcon: Icon(Icons.filter_list_rounded),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text(
                                  'Todos',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              for (final s in eppStates.entries)
                                DropdownMenuItem(
                                  value: s.key,
                                  child: Text(
                                    s.value,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (v) {
                                    setState(() {
                                      _state = v!;
                                      _page = 1;
                                    });
                                    _load();
                                  },
                          ),
                          const SizedBox(height: 20),
                          if (!_busy || _rows.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '$_total ${_total == 1 ? 'pedido' : 'pedidos'}',
                                style: Theme.of(context).textTheme.titleSmall,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_rows.isEmpty && !_busy)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No hay pedidos para este filtro.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          for (final r in _rows)
                            _OrderCard(order: r, onTap: () => _detail(r)),
                          if (_total > 30 || _page > 1)
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              children: [
                                TextButton(
                                  onPressed: !_busy && _page > 1
                                      ? () {
                                          _page--;
                                          _load();
                                        }
                                      : null,
                                  child: const Text(
                                    'Anterior',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Text(
                                  'Página $_page · $_total pedidos',
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: !_busy && _page * 30 < _total
                                      ? () {
                                          _page++;
                                          _load();
                                        }
                                      : null,
                                  child: const Text(
                                    'Siguiente',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                        ],
                        if (_tab == 2) ...[
                          Text(
                            'Tus entregas del año',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Consultá las cantidades recibidas por artículo y talle.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          DropdownButtonFormField<int>(
                            initialValue: _year,
                            decoration: const InputDecoration(labelText: 'Año'),
                            items: [
                              for (var y = DateTime.now().year; y >= 2000; y--)
                                DropdownMenuItem(
                                  value: y,
                                  child: Text(
                                    '$y',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (v) {
                                    _year = v!;
                                    _load();
                                  },
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Cantidades efectivamente entregadas. Las entregas anuladas no se suman.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (_rows.isEmpty && !_busy)
                            const Text(
                              'No hay entregas registradas para este año.',
                              textAlign: TextAlign.center,
                            ),
                          for (final r in _rows)
                            AppCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      eppText(r['nombre']),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      'Talle ${r['talle']} · ${r['medidas'] ?? ''}',
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      '${r['cantidad']} entregadas',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _orderDate(dynamic value) {
  final raw = eppText(value).trim();
  // Preserve the calendar date supplied by the service across time zones.
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match == null || DateTime.tryParse(raw) == null) {
    return 'Fecha no disponible';
  }
  return '${match[3]}/${match[2]}/${match[1]}';
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final EppData order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = eppStates[order['estado']] ?? eppText(order['estado']);
    final reason = eppText(order['motivo']).trim();
    final attention = ['rechazado', 'cancelado'].contains(order['estado']);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Pedido #${order['id']}',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: attention
                      ? colors.errorContainer
                      : colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: attention
                        ? colors.onErrorContainer
                        : colors.onSecondaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Solicitado el ${_orderDate(order['creado_at'])}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure(this.message, {this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Reintentar')),
      ],
    ),
  );
}

class _PrivateImage extends StatefulWidget {
  const _PrivateImage({
    required this.api,
    required this.token,
    required this.path,
  });
  final MobileApiClient api;
  final String token, path;
  @override
  State<_PrivateImage> createState() => _PrivateImageState();
}

class _PrivateImageState extends State<_PrivateImage> {
  late Future<Uint8List> _bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bytes = widget.api.getEppFile(token: widget.token, path: widget.path);
  }

  @override
  void didUpdateWidget(covariant _PrivateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.token != widget.token) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, s) {
      if (s.hasError) {
        return TextButton.icon(
          onPressed: () => setState(_load),
          icon: const Icon(Icons.broken_image_outlined),
          label: const Text('Reintentar imagen', textAlign: TextAlign.center),
        );
      }
      if (!s.hasData) {
        return const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.memory(
                        s.data!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, e, st) => const Text(
                          'Imagen no disponible',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cerrar imagen',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: Image.memory(
            s.data!,
            height: 160,
            fit: BoxFit.contain,
            errorBuilder: (_, e, st) =>
                const Text('Imagen no disponible', textAlign: TextAlign.center),
          ),
        ),
      );
    },
  );
}

class _SizeDialog extends StatefulWidget {
  const _SizeDialog({
    required this.api,
    required this.token,
    required this.article,
    required this.saved,
  });
  final MobileApiClient api;
  final String token;
  final EppArticle article;
  final EppData saved;
  @override
  State<_SizeDialog> createState() => _SizeDialogState();
}

class _SizeDialogState extends State<_SizeDialog> {
  late final TextEditingController _measure;
  String? _size, _failure;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _measure = TextEditingController(text: eppText(widget.saved['medidas']));
    final saved = eppText(widget.saved['talle']);
    _size = widget.article.sizes.contains(saved) ? saved : null;
  }

  @override
  void dispose() {
    _measure.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    if (!remove && _size == null) {
      setState(() => _failure = 'Elegí un talle.');
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.api.writeEpp(
        token: widget.token,
        path: '/talles',
        put: true,
        data: {
          'articulo_id': widget.article.id,
          if (remove) 'eliminar': true,
          if (!remove) ...{'talle': _size, 'medidas': _measure.text.trim()},
        },
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _failure = _error(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.article.name, textAlign: TextAlign.center),
    scrollable: true,
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.article.description.isNotEmpty)
            Text(widget.article.description, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _size,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Talle'),
            items: [
              for (final t in widget.article.sizes)
                DropdownMenuItem(
                  value: t,
                  child: Text(t, textAlign: TextAlign.center),
                ),
            ],
            onChanged: _busy ? null : (v) => setState(() => _size = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _measure,
            enabled: !_busy,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Medidas (opcional)'),
          ),
          if (_failure != null) _Failure(_failure!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cerrar', textAlign: TextAlign.center),
      ),
      if (widget.saved.isNotEmpty)
        TextButton(
          onPressed: _busy ? null : () => _save(remove: true),
          child: const Text('Quitar talle', textAlign: TextAlign.center),
        ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(
          _busy ? 'Guardando…' : 'Guardar',
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}

class _Line {
  _Line({
    required this.id,
    required this.name,
    this.size = '',
    String quantity = '1',
    String measure = '',
  }) : quantity = TextEditingController(text: quantity),
       measure = TextEditingController(text: measure);
  final int id;
  final String name;
  String size;
  bool confirmed = false;
  bool editingSize = false;
  final TextEditingController quantity, measure;
  void dispose() {
    quantity.dispose();
    measure.dispose();
  }

  EppData data() => {
    'articulo_id': id,
    'talle': size,
    'cantidad': int.tryParse(quantity.text) ?? 0,
    'medidas': measure.text.trim(),
  };
}

class _EppEditor extends StatefulWidget {
  const _EppEditor({required this.api, required this.token, this.order});
  final MobileApiClient api;
  final String token;
  final EppData? order;
  @override
  State<_EppEditor> createState() => _EppEditorState();
}

class _EppEditorState extends State<_EppEditor> with WidgetsBindingObserver {
  final _reason = TextEditingController();
  int _conceptId = 0;
  bool _conceptChanged = false;
  final List<_Line> _lines = [];
  final _uuid = const Uuid().v4();
  EppConfig? _config;
  EppData? _pending;
  bool _allowExit = false;
  String? _failure;
  bool _busy = false, _conflict = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reason.text = eppText(widget.order?['motivo']);
    _conceptId = eppInt(widget.order?['concepto_reposicion_id']);
    for (final r in eppRows(widget.order?['items'])) {
      _lines.add(
        _Line(
          id: eppInt(r['articulo_id']),
          name: eppText(r['nombre']),
          size: eppText(r['talle']),
          quantity: '${r['cantidad']}',
          measure: eppText(r['medidas']),
        ),
      );
    }
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reason.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final config = EppConfig(
        await widget.api.getEppConfig(token: widget.token),
      );
      if (mounted) {
        setState(() {
          _config = config;
          _failure = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _failure = _error(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _add() async {
    if (_config == null) {
      return;
    }
    final selected = await showDialog<EppArticle>(
      context: context,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Agregar artículo', textAlign: TextAlign.center),
            content: SizedBox(
              width: 480,
              height: MediaQuery.sizeOf(context).height * .45,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar artículo',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (v) =>
                        update(() => query = v.toLowerCase().trim()),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final a in _config!.articles.where(
                          (a) =>
                              !_lines.any((l) => l.id == a.id) &&
                              '${a.name} ${a.category}'.toLowerCase().contains(
                                query,
                              ),
                        ))
                          ListTile(
                            title: Text(a.name, textAlign: TextAlign.center),
                            subtitle: Text(
                              a.category,
                              textAlign: TextAlign.center,
                            ),
                            onTap: () => Navigator.pop(context, a),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar', textAlign: TextAlign.center),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) {
      final saved = _config!.saved(selected.id);
      setState(
        () => _lines.add(
          _Line(
            id: selected.id,
            name: selected.name,
            size: eppText(saved['talle']),
            measure: eppText(saved['medidas']),
          ),
        ),
      );
    }
  }

  String? _validate(EppConfig config, {required bool confirm}) {
    if (_conceptId != 0 &&
        _conceptId != eppInt(widget.order?['concepto_reposicion_id']) &&
        !config.concepts.any((c) => eppInt(c['id']) == _conceptId)) {
      return 'El concepto seleccionado ya no está disponible. Elegí otro o dejalo sin concepto.';
    }
    if (_reason.text.trim().isEmpty) {
      return 'Indicá el motivo del pedido.';
    }
    if (_lines.isEmpty || _lines.length > config.maxItems) {
      return 'Incluí entre 1 y ${config.maxItems} artículos.';
    }
    for (final l in _lines) {
      final candidates = config.articles.where((a) => a.id == l.id);
      if (candidates.isEmpty) {
        return '${l.name} ya no está habilitado. Quitalo para continuar.';
      }
      if (!candidates.first.sizes.contains(l.size)) {
        return 'Elegí un talle vigente para ${l.name}.';
      }
      if (confirm && !l.confirmed) {
        return 'Confirmá el talle de ${l.name}.';
      }
      final n = int.tryParse(l.quantity.text);
      if (n == null || n < 1 || n > 1000) {
        return 'La cantidad de ${l.name} debe ser un entero entre 1 y 1000.';
      }
    }
    return null;
  }

  Future<void> _save(String action) async {
    if (_busy || _conflict) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      if (_pending == null) {
        final config = EppConfig(
          await widget.api.getEppConfig(token: widget.token),
        );
        if (!mounted) {
          return;
        }
        setState(() => _config = config);
        final error = _validate(config, confirm: action != 'borrador');
        if (error != null) {
          setState(() => _failure = error);
          return;
        }
        _pending = {
          if (widget.order == null)
            'envio_id': _uuid
          else
            'revision': widget.order!['revision'],
          'accion': action,
          'motivo': _reason.text.trim(),
          if (_conceptChanged)
            'concepto_reposicion_id': _conceptId == 0 ? null : _conceptId,
          'items': _lines.map((l) => l.data()).toList(),
        };
      }
      await widget.api.writeEpp(
        token: widget.token,
        path:
            '/pedidos${widget.order == null ? '' : '/${widget.order!['id']}'}',
        put: widget.order != null,
        data: _pending!,
      );
      if (mounted) {
        setState(() => _allowExit = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failure = _error(e);
          if (e is ApiException && e.statusCode == 409) {
            _conflict = true;
          }
          if (e is ApiException &&
              [400, 401, 403, 404, 413].contains(e.statusCode)) {
            _pending = null;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _pending != null || _conflict;
    return PopScope(
      canPop: _allowExit || (!_busy && _pending == null),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _busy) {
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              '¿Salir del pedido?',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'El resultado del envío no está confirmado. Al salir perderás los datos locales de reintento. Revisá Mis pedidos antes de crear otra solicitud.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Seguir revisando',
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir', textAlign: TextAlign.center),
              ),
            ],
          ),
        );
        if (leave == true && mounted) {
          setState(() => _allowExit = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.order == null
                ? 'Solicitar EPP'
                : 'Editar pedido #${widget.order!['id']}',
            textAlign: TextAlign.center,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  const Text(
                    'Usamos tus talles guardados por artículo. Podés cambiarlos para este pedido. Confirmalos antes de enviar; para guardar un borrador no hace falta confirmarlos.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _conceptSelector(locked),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reason,
                    enabled: !locked,
                    maxLength: 1000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del pedido',
                    ),
                  ),
                  for (final l in _lines) _lineCard(l, locked),
                  OutlinedButton.icon(
                    onPressed:
                        !locked &&
                            _config != null &&
                            _lines.length < _config!.maxItems
                        ? _add
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      'Agregar artículo',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_config != null && _config!.articles.isEmpty)
                    const Text(
                      'No hay artículos habilitados. Contactá al responsable de EPP.',
                      textAlign: TextAlign.center,
                    ),
                  if (_failure != null)
                    _Failure(
                      _failure!,
                      retry: _config == null && !_busy ? _refresh : null,
                    ),
                  if (_conflict) ...[
                    const Text(
                      'El pedido cambió o la clave de envío está en conflicto. Tus datos siguen visibles. Revisá el estado actual antes de volver a editar.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => widget.order == null
                                    ? EppPage(
                                        api: widget.api,
                                        token: widget.token,
                                      )
                                    : _EppDetail(
                                        api: widget.api,
                                        token: widget.token,
                                        id: eppInt(widget.order!['id']),
                                      ),
                              ),
                            ),
                      child: const Text(
                        'Consultar estado actual',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else if (_pending != null && !_busy) ...[
                    const Text(
                      'No se pudo confirmar el resultado. Reintentá el mismo envío para evitar duplicados. No cierres esta pantalla hasta comprobarlo.',
                      textAlign: TextAlign.center,
                    ),
                    FilledButton(
                      onPressed: () => _save(eppText(_pending!['accion'])),
                      child: const Text(
                        'Reintentar mismo envío',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: locked ? null : () => _save('enviar'),
                      child: Text(
                        _busy ? 'Guardando…' : 'Enviar solicitud',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: locked ? null : () => _save('borrador'),
                      child: const Text(
                        'Guardar borrador',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _conceptSelector(bool locked) {
    final originalId = eppInt(widget.order?['concepto_reposicion_id']);
    final choices = <int, String>{
      0: 'Sin concepto',
      for (final c in _config?.concepts ?? <EppData>[])
        eppInt(c['id']): eppText(c['nombre']),
    };
    if (originalId != 0) {
      final active = choices.containsKey(originalId);
      choices[originalId] =
          '${eppText(widget.order?['concepto_reposicion'])}${active ? '' : ' (inactivo)'}';
    }
    if (!choices.containsKey(_conceptId)) {
      choices[_conceptId] = 'Concepto no disponible';
    }
    return DropdownButtonFormField<int>(
      key: ValueKey('concept:$_conceptId:${choices.keys.join(',')}'),
      initialValue: _conceptId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Concepto de reposición (opcional)',
        helperText: 'El motivo escrito sigue siendo obligatorio.',
      ),
      items: [
        for (final entry in choices.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(
              entry.value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
      ],
      onChanged: locked
          ? null
          : (value) => setState(() {
              _conceptId = value ?? 0;
              _conceptChanged = true;
            }),
    );
  }

  Future<void> _saveUsualSize(_Line line) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.api.writeEpp(
        token: widget.token,
        path: '/talles',
        put: true,
        data: {
          'articulo_id': line.id,
          'talle': line.size,
          'medidas': line.measure.text.trim(),
        },
      );
      if (!mounted) return;
      final sizes = _config!.sizes;
      sizes.removeWhere((row) => eppInt(row['articulo_id']) == line.id);
      sizes.add({
        'articulo_id': line.id,
        'talle': line.size,
        'medidas': line.measure.text.trim(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Talle habitual y medidas guardados.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _lineCard(_Line l, bool locked) {
    final matches = _config?.articles.where((a) => a.id == l.id).toList() ?? [];
    final sizes = matches.isEmpty ? <String>[] : matches.first.sizes;
    final savedSize = eppText(_config?.saved(l.id)['talle']);
    final valid = sizes.contains(l.size);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.name,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (matches.isEmpty && _config != null)
              const Text(
                'Artículo no disponible en el catálogo actual.',
                textAlign: TextAlign.center,
              ),
            if (matches.isNotEmpty && matches.first.description.isNotEmpty)
              Text(matches.first.description, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              savedSize.isEmpty
                  ? 'No tenés un talle habitual guardado para este artículo.'
                  : 'Tu talle guardado: $savedSize',
              textAlign: TextAlign.center,
            ),
            if (savedSize.isNotEmpty && !sizes.contains(savedSize))
              const Text(
                'Tu talle guardado ya no está disponible. Elegí uno del catálogo actual.',
                textAlign: TextAlign.center,
              ),
            if (valid && !l.editingSize) ...[
              Text(
                'Talle para este pedido: ${l.size}',
                textAlign: TextAlign.center,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: locked
                      ? null
                      : () => setState(() => l.editingSize = true),
                  child: const Text(
                    'Cambiar talle',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ] else
              DropdownButtonFormField<String>(
                key: ValueKey('${l.id}:${sizes.join(',')}:${l.size}'),
                initialValue: sizes.contains(l.size) ? l.size : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Talle'),
                items: [
                  for (final t in sizes)
                    DropdownMenuItem(
                      value: t,
                      child: Text(t, textAlign: TextAlign.center),
                    ),
                ],
                onChanged: locked
                    ? null
                    : (v) => setState(() {
                        l.size = v!;
                        l.confirmed = false;
                      }),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Confirmo que este es mi talle',
                textAlign: TextAlign.center,
              ),
              value: l.confirmed,
              onChanged: locked
                  ? null
                  : (v) => setState(() => l.confirmed = v!),
            ),
            TextField(
              controller: l.quantity,
              enabled: !locked,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'Cantidad (1 a 1000)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: l.measure,
              enabled: !locked,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Medidas (opcional)',
              ),
            ),
            const Text(
              'Los cambios se aplican solo a este pedido, salvo que los guardes como habituales.',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: locked || !valid ? null : () => _saveUsualSize(l),
              child: const Text(
                'Guardar como mi talle habitual',
                textAlign: TextAlign.center,
              ),
            ),
            TextButton.icon(
              onPressed: locked
                  ? null
                  : () {
                      setState(() => _lines.remove(l));
                      l.dispose();
                    },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Quitar artículo', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _EppDetail extends StatefulWidget {
  const _EppDetail({required this.api, required this.token, required this.id});
  final MobileApiClient api;
  final String token;
  final int id;
  @override
  State<_EppDetail> createState() => _EppDetailState();
}

class _EppDetailState extends State<_EppDetail> {
  EppData? _order;
  String _cancelReason = '';
  String? _failure;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final order = await widget.api.getEpp(
        token: widget.token,
        path: '/pedidos/${widget.id}',
      );
      if (mounted) {
        setState(() => _order = order);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _failure = _error(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(initialReason: _cancelReason),
    );
    if (reason == null || !mounted) {
      return;
    }
    _cancelReason = reason;
    setState(() => _busy = true);
    try {
      final order = await widget.api.writeEpp(
        token: widget.token,
        path: '/pedidos/${widget.id}/acciones',
        data: {
          'accion': 'cancelar',
          'revision': _order!['revision'],
          'motivo': reason,
        },
      );
      if (mounted) {
        setState(() {
          _order = order;
          _failure = null;
        });
      }
    } catch (e) {
      await _load();
      if (mounted) {
        setState(
          () => _failure =
              '${_error(e)} Revisá el estado actualizado antes de volver a cancelar.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pdf(int id) async {
    setState(() => _busy = true);
    try {
      final bytes = await widget.api.getEppFile(
        token: widget.token,
        path: '/entregas/$id/pdf',
      );
      if (!mounted) {
        return;
      }
      await FilePicker.saveFile(
        dialogTitle: 'Guardar constancia de entrega',
        fileName: 'entrega-epp-$id.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _failure = _error(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Pedido #${widget.id}', textAlign: TextAlign.center),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_failure != null)
                _Failure(_failure!, retry: _busy ? null : _load),
              if (_order != null) ...[
                Text(
                  eppStates[_order!['estado']] ?? eppText(_order!['estado']),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (eppText(_order!['concepto_reposicion']).isNotEmpty)
                  Text(
                    'Concepto de reposición: ${_order!['concepto_reposicion']}',
                    textAlign: TextAlign.center,
                  ),
                Text(eppText(_order!['motivo']), textAlign: TextAlign.center),
                Text(
                  'Creado: ${_order!['creado_at'] ?? ''}',
                  textAlign: TextAlign.center,
                ),
                if (eppEditable(_order!) && _failure == null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => _EppEditor(
                                      api: widget.api,
                                      token: widget.token,
                                      order: _order,
                                    ),
                                  ),
                                );
                                if (mounted) {
                                  await _load();
                                }
                              },
                        child: const Text(
                          'Editar pedido',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _cancel,
                        child: const Text(
                          'Cancelar pedido',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                for (final r in eppRows(_order!['items']))
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            eppText(r['nombre']),
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Talle: ${r['talle']}\n${r['medidas'] ?? ''}',
                            textAlign: TextAlign.center,
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _Count('Solicitadas', '${r['cantidad']}'),
                              _Count(
                                'Aprobadas',
                                r['aprobada'] == null
                                    ? 'Sin resolver'
                                    : '${r['aprobada']}',
                              ),
                              _Count('Entregadas', '${r['entregada'] ?? 0}'),
                            ],
                          ),
                          if (eppText(r['motivo']).isNotEmpty)
                            Text(
                              'Motivo de resolución: ${r['motivo']}',
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Entregas y constancias',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (eppRows(_order!['entregas']).isEmpty)
                  const Text(
                    'Todavía no hay entregas registradas.',
                    textAlign: TextAlign.center,
                  ),
                for (final d in eppRows(_order!['entregas']))
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Entrega #${d['id']} · ${d['fecha']}',
                            textAlign: TextAlign.center,
                          ),
                          if (eppInt(d['anulada']) == 1)
                            const Text(
                              'Anulada · No suma en los totales',
                              textAlign: TextAlign.center,
                            ),
                          Text(
                            eppInt(d['firmada']) == 1
                                ? 'Planilla firmada adjunta'
                                : 'Sin planilla firmada',
                            textAlign: TextAlign.center,
                          ),
                          if (eppText(d['observaciones']).isNotEmpty)
                            Text(
                              eppText(d['observaciones']),
                              textAlign: TextAlign.center,
                            ),
                          if (eppInt(d['firmada']) == 1)
                            ExpansionTile(
                              title: const Text(
                                'Ver planilla firmada',
                                textAlign: TextAlign.center,
                              ),
                              children: [
                                _PrivateImage(
                                  api: widget.api,
                                  token: widget.token,
                                  path: '/imagenes/firmas/${d['id']}',
                                ),
                              ],
                            ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _pdf(eppInt(d['id'])),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text(
                              'Descargar constancia PDF',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Historial del pedido',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                for (final h in eppRows(_order!['historial']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      eppText(h['accion']).replaceAll('_', ' '),
                      textAlign: TextAlign.center,
                    ),
                    subtitle: Text(
                      eppText(h['creado_at']),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, textAlign: TextAlign.center),
      Text(
        value,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    ],
  );
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.initialReason});
  final String initialReason;
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  late final _text = TextEditingController(text: widget.initialReason);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Cancelar pedido', textAlign: TextAlign.center),
    content: TextField(
      controller: _text,
      maxLength: 1000,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Motivo obligatorio'),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Volver', textAlign: TextAlign.center),
      ),
      FilledButton(
        onPressed: _text.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _text.text.trim()),
        child: const Text('Confirmar cancelación', textAlign: TextAlign.center),
      ),
    ],
  );
}
