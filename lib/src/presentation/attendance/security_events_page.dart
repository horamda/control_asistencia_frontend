import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import '../../core/utils/date_formatter.dart';

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
      appBar: AppBar(title: const Text('Eventos de seguridad')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth >= 1200
                      ? 1040.0
                      : constraints.maxWidth >= 900
                      ? 900.0
                      : double.infinity;
                  final horizontalPadding = constraints.maxWidth < 600
                      ? 12.0
                      : 16.0;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(horizontalPadding),
                        children: [
                          if (_error != null) ...[
                            Card(
                              color: const Color(0xFFFFF4E5),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_error!),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _loadingPage
                                          ? null
                                          : () => _loadPage(page: _page),
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Reintentar'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
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
                                child: Text(
                                  'No hay eventos de seguridad para mostrar.',
                                ),
                              ),
                            ),
                          ..._items.map(_eventCard),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, paginationConstraints) {
                              final stacked =
                                  paginationConstraints.maxWidth < 430;
                              if (stacked) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: (!hasPrev || _loadingPage)
                                          ? null
                                          : () => _loadPage(page: _page - 1),
                                      icon: const Icon(Icons.chevron_left),
                                      label: const Text('Anterior'),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: (!hasNext || _loadingPage)
                                          ? null
                                          : () => _loadPage(page: _page + 1),
                                      icon: const Icon(Icons.chevron_right),
                                      label: const Text('Siguiente'),
                                    ),
                                  ],
                                );
                              }
                              return Row(
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
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _eventCard(SecurityEventItem event) {
    final details = <String>[
      if ((event.fecha ?? '').isNotEmpty)
        'Fecha: ${DateFormatter.formatApiDateForDisplay(event.fecha)}',
      if ((event.horaOperacion ?? '').isNotEmpty)
        'Hora: ${event.horaOperacion}',
      if (event.distanciaM != null && event.toleranciaM != null)
        'Distancia: ${event.distanciaM!.toStringAsFixed(1)} m / Tolerancia: ${event.toleranciaM!.toStringAsFixed(1)} m',
      if (event.sucursalId != null) 'Sucursal: ${event.sucursalId}',
    ];
    final subtitle = details.isEmpty
        ? 'Sin detalle adicional.'
        : details.join('\n');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          event.alertaFraude ? Icons.warning_amber_rounded : Icons.info_outline,
          color: event.alertaFraude
              ? Colors.red.shade700
              : Colors.orange.shade700,
        ),
        title: Text(event.tipoEvento ?? 'evento_seguridad'),
        subtitle: Text(subtitle),
        trailing: Text('#${event.id}'),
        isThreeLine: true,
      ),
    );
  }
}
