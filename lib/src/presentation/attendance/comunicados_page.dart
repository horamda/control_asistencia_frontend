import 'notification_settings_page.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/reuniones/comunicados_navigation.dart';
import '../../core/reuniones/push_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page_layout.dart';

String _date(Object? value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class ComunicadosPage extends StatefulWidget {
  const ComunicadosPage({super.key, required this.api, required this.token});
  final MobileApiClient api;
  final String token;
  @override
  State<ComunicadosPage> createState() => _ComunicadosPageState();
}

class _ComunicadosPageState extends State<ComunicadosPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  int _page = 0, _pages = 1, _unread = 0, _request = 0;
  bool _loading = true, _marking = false, _enabling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ComunicadosNavigation.refresh.addListener(_refresh);
    unawaited(_load());
  }

  void _refresh() => unawaited(_load());
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      unawaited(PushService.instance.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ComunicadosNavigation.refresh.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request;
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.token.startsWith('offline_')) throw Exception();
      final data = await widget.api.getComunicados(
        token: widget.token,
        page: page,
      );
      if (!mounted || request != _request) return;
      final items = (data['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _items = more
            ? [
                ..._items,
                ...items.where(
                  (e) => !_items.any((old) => old['id'] == e['id']),
                ),
              ]
            : items;
        _page = page;
        _pages = (data['pages'] as num?)?.toInt() ?? 1;
        _unread = (data['no_leidos'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error =
              'No se pudieron cargar los comunicados. Revisá tu conexión y reintentá.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    setState(() => _marking = true);
    try {
      await widget.api.leerTodosComunicados(token: widget.token);
      ComunicadosNavigation.refresh.value++;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron marcar los comunicados. Reintentá.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _enable() async {
    setState(() => _enabling = true);
    try {
      await PushService.instance.enable();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron activar los avisos. Revisá los permisos del dispositivo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicados')),
      body: AppPageBody(
        maxWidth: 840,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppCard(
                child: ExpansionTile(
                  title: const Text('Notificaciones'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Tus mensajes, siempre disponibles',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Aunque borres el aviso del celular, podés volver a leer aquí los comunicados que la empresa conserve. Necesitás conexión para consultarlos.',
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const NotificationSettingsPage(),
                              ),
                            ),
                            child: const Text('Configurar notificaciones'),
                          ),
                          ValueListenableBuilder<String>(
                            valueListenable: PushService.instance.status,
                            builder: (_, status, _) => Text(status),
                          ),
                          const SizedBox(height: 8),
                          AppAdaptiveActions(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _enabling ? null : _enable,
                                icon: const Icon(
                                  Icons.notifications_active_outlined,
                                ),
                                label: Text(
                                  _enabling
                                      ? 'Conectando…'
                                      : 'Activar notificaciones',
                                ),
                              ),
                              if (!kIsWeb &&
                                  defaultTargetPlatform ==
                                      TargetPlatform.android)
                                TextButton(
                                  onPressed: () async {
                                    await openAppSettings();
                                  },
                                  child: const Text('Permisos de Android'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('$_unread sin leer', textAlign: TextAlign.center),
              if (_unread > 0)
                TextButton.icon(
                  onPressed: _loading || _marking ? null : _markAll,
                  icon: const Icon(Icons.done_all),
                  label: Text(
                    _marking ? 'Marcando…' : 'Marcar todos como leídos',
                  ),
                ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _loading ? null : () => _load(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              if (!_loading && _error == null && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no tenés comunicados.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final item in _items)
                AppCard(
                  color: item['leido'] == true
                      ? colors.surface
                      : colors.primaryContainer,
                  child: InkWell(
                    onTap: () async {
                      final id = (item['id'] as num?)?.toInt();
                      if (id == null) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ComunicadoDetailPage(
                            api: widget.api,
                            token: widget.token,
                            id: id,
                          ),
                        ),
                      );
                      if (mounted) await _load();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Icon(
                                item['leido'] == true
                                    ? Icons.drafts_outlined
                                    : Icons.mark_email_unread_outlined,
                              ),
                              if (item['leido'] != true)
                                const Text(
                                  'Sin leer',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              if (item['imagen_url'] != null)
                                const Icon(Icons.image_outlined),
                              Text(_date(item['fecha'])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${item['titulo'] ?? 'Comunicado'}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${item['mensaje'] ?? ''}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_page < _pages)
                OutlinedButton(
                  onPressed: _loading ? null : () => _load(more: true),
                  child: const Text('Cargar más'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ComunicadoDetailPage extends StatefulWidget {
  const ComunicadoDetailPage({
    super.key,
    required this.api,
    required this.token,
    required this.id,
  });
  final MobileApiClient api;
  final String token;
  final int id;
  @override
  State<ComunicadoDetailPage> createState() => _ComunicadoDetailPageState();
}

class _ComunicadoDetailPageState extends State<ComunicadoDetailPage> {
  Map<String, dynamic>? _data;
  Uint8List? _image;
  bool _loading = true, _imageLoading = false, _imageError = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getComunicado(
        token: widget.token,
        id: widget.id,
      );
      if (!mounted) return;
      setState(() => _data = data);
      ComunicadosNavigation.refresh.value++;
      if (data['imagen_url'] != null) unawaited(_loadImage());
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException && e.statusCode == 404
              ? 'Este comunicado ya no está disponible o no está dirigido a vos.'
              : 'No se pudo abrir el comunicado. Revisá tu conexión y reintentá.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _imageLoading = true;
      _imageError = false;
    });
    try {
      final bytes = await widget.api.getComunicadoImagen(
        token: widget.token,
        id: widget.id,
      );
      if (mounted) setState(() => _image = bytes);
    } catch (_) {
      if (mounted) setState(() => _imageError = true);
    } finally {
      if (mounted) setState(() => _imageLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comunicado')),
    body: AppPageBody(
      maxWidth: 840,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!, textAlign: TextAlign.center),
            TextButton(
              onPressed: _loading ? null : _load,
              child: const Text('Reintentar'),
            ),
          ],
          if (_data != null)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_data!['titulo'] ?? 'Comunicado'}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_date(_data!['fecha']), textAlign: TextAlign.center),
                    if (_imageLoading) const LinearProgressIndicator(),
                    if (_image != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Image.memory(
                          _image!,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, _, _) =>
                              const Text('No se pudo mostrar la imagen.'),
                        ),
                      ),
                    if (_imageError)
                      TextButton(
                        onPressed: _imageLoading ? null : _loadImage,
                        child: const Text('Reintentar imagen'),
                      ),
                    const SizedBox(height: 16),
                    SelectableText(
                      '${_data!['mensaje'] ?? ''}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text('Leído', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
