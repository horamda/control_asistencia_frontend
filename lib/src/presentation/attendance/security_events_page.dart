import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class SecurityEventsPage extends StatefulWidget {
  const SecurityEventsPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<SecurityEventsPage> createState() => _SecurityEventsPageState();
}

class _SecurityEventsPageState extends State<SecurityEventsPage> {
  bool _loading = true;
  bool _loadingPage = false;
  String? _error;

  int _page = 1;
  int _perPage = 20;
  int _total = 0;
  List<SecurityEventItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadPage(page: 1);
  }

  Future<void> _loadPage({required int page}) async {
    if (_loadingPage) {
      return;
    }
    setState(() {
      _loadingPage = true;
      if (_items.isEmpty) {
        _loading = true;
      }
    });

    try {
      final data = await widget.apiClient.getEventosSeguridad(
        token: widget.token,
        page: page,
        per: _perPage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = data.items;
        _page = data.page;
        _perPage = data.perPage;
        _total = data.total;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Error inesperado al consultar eventos de seguridad.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingPage = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadPage(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final hasPrev = _page > 1;
    final hasNext = (_page * _perPage) < _total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos de seguridad'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      color: const Color(0xFFFFF4E5),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Pagina $_page | Registros: $_total'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay eventos de seguridad para mostrar.'),
                      ),
                    ),
                  ..._items.map(_eventCard),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (!hasPrev || _loadingPage)
                              ? null
                              : () => _loadPage(page: _page - 1),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Anterior'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (!hasNext || _loadingPage)
                              ? null
                              : () => _loadPage(page: _page + 1),
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Siguiente'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _eventCard(SecurityEventItem event) {
    final details = <String>[
      if ((event.fecha ?? '').isNotEmpty) 'Fecha: ${event.fecha}',
      if ((event.horaOperacion ?? '').isNotEmpty) 'Hora: ${event.horaOperacion}',
      if (event.distanciaM != null && event.toleranciaM != null)
        'Distancia: ${event.distanciaM!.toStringAsFixed(1)} m / Tolerancia: ${event.toleranciaM!.toStringAsFixed(1)} m',
      if (event.sucursalId != null) 'Sucursal: ${event.sucursalId}',
    ];
    final subtitle = details.isEmpty ? 'Sin detalle adicional.' : details.join('\n');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          event.alertaFraude ? Icons.warning_amber_rounded : Icons.info_outline,
          color: event.alertaFraude ? Colors.red.shade700 : Colors.orange.shade700,
        ),
        title: Text(event.tipoEvento ?? 'evento_seguridad'),
        subtitle: Text(subtitle),
        trailing: Text('#${event.id}'),
        isThreeLine: true,
      ),
    );
  }
}
