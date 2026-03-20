import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import '../../core/utils/date_formatter.dart';

class MarksHistoryPage extends StatefulWidget {
  const MarksHistoryPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<MarksHistoryPage> createState() => _MarksHistoryPageState();
}

class _MarksHistoryPageState extends State<MarksHistoryPage> {
  final TextEditingController _desdeController = TextEditingController();
  final TextEditingController _hastaController = TextEditingController();

  bool _loading = true;
  bool _loadingPage = false;
  String? _error;

  int _page = 1;
  int _perPage = 20;
  int _total = 0;
  List<MarcaItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadPage(page: 1);
  }

  @override
  void dispose() {
    _desdeController.dispose();
    _hastaController.dispose();
    super.dispose();
  }

  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _fmtDisplayDate(DateTime date) {
    return DateFormatter.formatDisplayDate(date);
  }

  DateTime? _parseInputDate(String raw) {
    return DateFormatter.parseFlexibleDate(raw);
  }

  String? _controllerDateToApi(TextEditingController controller) {
    return DateFormatter.toApiDateOrNull(controller.text);
  }

  Future<void> _pickDate({required bool isDesde}) async {
    final today = _todayDate();
    final first = DateTime(2000, 1, 1);
    final fromCtrl = isDesde ? _desdeController : _hastaController;
    final otherCtrl = isDesde ? _hastaController : _desdeController;
    var current = _parseInputDate(fromCtrl.text) ?? today;
    if (current.isAfter(today)) {
      current = today;
    } else if (current.isBefore(first)) {
      current = first;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: first,
      lastDate: today,
      helpText: isDesde ? 'Seleccionar fecha desde' : 'Seleccionar fecha hasta',
    );
    if (picked == null || !mounted) {
      return;
    }

    final pickedNorm = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      fromCtrl.text = _fmtDisplayDate(pickedNorm);
      final other = _parseInputDate(otherCtrl.text);
      if (other != null) {
        if (isDesde && pickedNorm.isAfter(other)) {
          otherCtrl.text = _fmtDisplayDate(pickedNorm);
        }
        if (!isDesde && pickedNorm.isBefore(other)) {
          otherCtrl.text = _fmtDisplayDate(pickedNorm);
        }
      }
    });
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
      final data = await widget.apiClient.getMarcas(
        token: widget.token,
        page: page,
        per: _perPage,
        desde: _controllerDateToApi(_desdeController),
        hasta: _controllerDateToApi(_hastaController),
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
        _error = 'Error inesperado al consultar marcas.';
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
    await _loadPage(page: _page);
  }

  void _applyFilters() {
    _loadPage(page: 1);
  }

  void _clearFilters() {
    _desdeController.clear();
    _hastaController.clear();
    _loadPage(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final hasPrev = _page > 1;
    final hasNext = (_page * _perPage) < _total;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de marcas')),
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
                          _FiltersCard(
                            desdeController: _desdeController,
                            hastaController: _hastaController,
                            todayIso: _fmtDisplayDate(_todayDate()),
                            onPickDesde: _loadingPage
                                ? null
                                : () => _pickDate(isDesde: true),
                            onPickHasta: _loadingPage
                                ? null
                                : () => _pickDate(isDesde: false),
                            onApply: _loadingPage ? null : _applyFilters,
                            onClear: _loadingPage ? null : _clearFilters,
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('Pagina $_page | Registros: $_total'),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
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
                          ],
                          const SizedBox(height: 10),
                          if (_items.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No hay marcas para mostrar.'),
                              ),
                            ),
                          ..._items.map(_buildItemCard),
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

  Widget _buildItemCard(MarcaItem item) {
    final details = <String>[
      if ((item.hora ?? '').isNotEmpty) 'Hora: ${item.hora}',
      if ((item.accion ?? '').isNotEmpty) 'Accion: ${item.accion}',
      if ((item.tipoMarca ?? '').isNotEmpty) 'Tipo: ${item.tipoMarca}',
      if ((item.metodo ?? '').isNotEmpty) 'Metodo: ${item.metodo}',
      if ((item.estado ?? '').isNotEmpty) 'Estado: ${item.estado}',
      if ((item.observaciones ?? '').isNotEmpty) 'Obs: ${item.observaciones}',
    ];
    if (item.gpsDistanciaM != null && item.gpsToleranciaM != null) {
      details.add(
        'GPS: ${item.gpsDistanciaM!.toStringAsFixed(1)} / ${item.gpsToleranciaM!.toStringAsFixed(1)} m',
      );
    }
    if (item.lat != null && item.lon != null) {
      details.add('Posicion: ${item.lat}, ${item.lon}');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          'Fecha: ${DateFormatter.formatApiDateForDisplay(item.fecha)}',
        ),
        subtitle: Text(details.isEmpty ? 'Sin detalle.' : details.join('\n')),
        trailing: Text('#${item.id}'),
        isThreeLine: true,
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.desdeController,
    required this.hastaController,
    required this.todayIso,
    required this.onPickDesde,
    required this.onPickHasta,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController desdeController;
  final TextEditingController hastaController;
  final String todayIso;
  final VoidCallback? onPickDesde;
  final VoidCallback? onPickHasta;
  final VoidCallback? onApply;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros (max $todayIso)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: desdeController,
              readOnly: true,
              onTap: onPickDesde,
              decoration: InputDecoration(
                labelText: 'Desde',
                hintText: 'dd/MM/yyyy',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onPickDesde,
                  icon: const Icon(Icons.calendar_month),
                  tooltip: 'Seleccionar desde',
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hastaController,
              readOnly: true,
              onTap: onPickHasta,
              decoration: InputDecoration(
                labelText: 'Hasta',
                hintText: 'dd/MM/yyyy',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onPickHasta,
                  icon: const Icon(Icons.calendar_month),
                  tooltip: 'Seleccionar hasta',
                ),
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: onApply,
                        child: const Text('Aplicar'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onClear,
                        child: const Text('Limpiar'),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: onApply,
                        child: const Text('Aplicar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onClear,
                        child: const Text('Limpiar'),
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
  }
}
