import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final TextEditingController _desdeController = TextEditingController();
  final TextEditingController _hastaController = TextEditingController();

  bool _loading = true;
  bool _loadingPage = false;
  String? _error;

  int _page = 1;
  int _perPage = 20;
  int _total = 0;
  List<AsistenciaItem> _items = const [];

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

  String _fmtDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseIsoDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _pickDate({required bool isDesde}) async {
    final today = _todayDate();
    final first = DateTime(2000, 1, 1);
    final fromCtrl = isDesde ? _desdeController : _hastaController;
    final otherCtrl = isDesde ? _hastaController : _desdeController;
    var current = _parseIsoDate(fromCtrl.text) ?? today;
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
      fromCtrl.text = _fmtDate(pickedNorm);
      final other = _parseIsoDate(otherCtrl.text);
      if (other != null) {
        if (isDesde && pickedNorm.isAfter(other)) {
          otherCtrl.text = _fmtDate(pickedNorm);
        }
        if (!isDesde && pickedNorm.isBefore(other)) {
          otherCtrl.text = _fmtDate(pickedNorm);
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
      final data = await widget.apiClient.getAsistencias(
        token: widget.token,
        page: page,
        per: _perPage,
        desde: _desdeController.text,
        hasta: _hastaController.text,
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
        _error = 'Error inesperado al consultar asistencias.';
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
      appBar: AppBar(title: const Text('Historial de asistencias')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _FiltersCard(
                    desdeController: _desdeController,
                    hastaController: _hastaController,
                    todayIso: _fmtDate(_todayDate()),
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
                        child: Text(_error!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_items.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay asistencias para mostrar.'),
                      ),
                    ),
                  ..._items.map(_buildItemCard),
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

  Widget _buildItemCard(AsistenciaItem item) {
    final details = <String>[
      if ((item.horaEntrada ?? '').isNotEmpty) 'Entrada: ${item.horaEntrada}',
      if ((item.horaSalida ?? '').isNotEmpty) 'Salida: ${item.horaSalida}',
      if ((item.metodoEntrada ?? '').isNotEmpty)
        'Metodo entrada: ${item.metodoEntrada}',
      if ((item.metodoSalida ?? '').isNotEmpty)
        'Metodo salida: ${item.metodoSalida}',
      if ((item.estado ?? '').isNotEmpty) 'Estado: ${item.estado}',
      if ((item.observaciones ?? '').isNotEmpty) 'Obs: ${item.observaciones}',
    ];
    if (item.gpsDistanciaEntradaM != null &&
        item.gpsToleranciaEntradaM != null) {
      details.add(
        'GPS entrada: ${item.gpsDistanciaEntradaM!.toStringAsFixed(1)} / ${item.gpsToleranciaEntradaM!.toStringAsFixed(1)} m',
      );
    }
    if (item.gpsDistanciaSalidaM != null && item.gpsToleranciaSalidaM != null) {
      details.add(
        'GPS salida: ${item.gpsDistanciaSalidaM!.toStringAsFixed(1)} / ${item.gpsToleranciaSalidaM!.toStringAsFixed(1)} m',
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text('Fecha: ${item.fecha ?? '-'}'),
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
                hintText: 'Seleccionar fecha',
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
                hintText: 'Seleccionar fecha',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onPickHasta,
                  icon: const Icon(Icons.calendar_month),
                  tooltip: 'Seleccionar hasta',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
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
            ),
          ],
        ),
      ),
    );
  }
}
