import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import '../../core/utils/date_formatter.dart';

class EmployeeStatsPage extends StatefulWidget {
  const EmployeeStatsPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<EmployeeStatsPage> createState() => _EmployeeStatsPageState();
}

class _EmployeeStatsPageState extends State<EmployeeStatsPage> {
  final TextEditingController _desdeController = TextEditingController();
  final TextEditingController _hastaController = TextEditingController();

  bool _loading = true;
  bool _loadingData = false;
  String? _error;
  EmployeeStatsResponse? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
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

  String? _validateRangeInputs() {
    final desdeRaw = _desdeController.text.trim();
    final hastaRaw = _hastaController.text.trim();
    final desde = _parseInputDate(desdeRaw);
    final hasta = _parseInputDate(hastaRaw);
    final today = _todayDate();

    if (desdeRaw.isNotEmpty && desde == null) {
      return 'Fecha desde invalida. Use dd/MM/yyyy.';
    }
    if (hastaRaw.isNotEmpty && hasta == null) {
      return 'Fecha hasta invalida. Use dd/MM/yyyy.';
    }
    if (desde != null && desde.isAfter(today)) {
      return 'No se permiten fechas futuras en desde.';
    }
    if (hasta != null && hasta.isAfter(today)) {
      return 'No se permiten fechas futuras en hasta.';
    }

    final effectiveDesde = desde ?? today.subtract(const Duration(days: 29));
    final effectiveHasta = hasta ?? today;
    if (effectiveDesde.isAfter(effectiveHasta)) {
      return 'El rango de fechas es invalido (desde > hasta).';
    }
    if (effectiveHasta.difference(effectiveDesde).inDays > 366) {
      return 'El rango maximo permitido es 366 dias.';
    }
    return null;
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

  Future<void> _loadStats() async {
    if (_loadingData) {
      return;
    }
    final validationError = _validateRangeInputs();
    if (validationError != null) {
      setState(() {
        _loading = false;
        _error = validationError;
      });
      return;
    }
    setState(() {
      _loadingData = true;
    });
    try {
      final stats = await widget.apiClient.getEstadisticas(
        token: widget.token,
        desde: _controllerDateToApi(_desdeController),
        hasta: _controllerDateToApi(_hastaController),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
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
        _error = 'Error inesperado al consultar estadisticas.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingData = false;
        });
      }
    }
  }

  void _applyFilters() {
    final validationError = _validateRangeInputs();
    if (validationError != null) {
      setState(() {
        _error = validationError;
      });
      return;
    }
    _loadStats();
  }

  void _clearFilters() {
    _desdeController.clear();
    _hastaController.clear();
    _loadStats();
  }

  void _setCurrentMonth() {
    final today = _todayDate();
    _desdeController.text = _fmtDisplayDate(
      DateTime(today.year, today.month, 1),
    );
    _hastaController.text = _fmtDisplayDate(today);
    _loadStats();
  }

  void _setCurrentYear() {
    final today = _todayDate();
    _desdeController.text = _fmtDisplayDate(DateTime(today.year, 1, 1));
    _hastaController.text = _fmtDisplayDate(today);
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final daily = stats?.series.diaria ?? const <StatsDiariaItem>[];
    final maxDaily = daily.isEmpty
        ? 1
        : daily
              .map((e) => e.registros > 0 ? e.registros : 1)
              .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis estadisticas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
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
                            onPickDesde: _loadingData
                                ? null
                                : () => _pickDate(isDesde: true),
                            onPickHasta: _loadingData
                                ? null
                                : () => _pickDate(isDesde: false),
                            onApply: _loadingData ? null : _applyFilters,
                            onClear: _loadingData ? null : _clearFilters,
                            onPresetMonth: _loadingData ? null : _setCurrentMonth,
                            onPresetYear: _loadingData ? null : _setCurrentYear,
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
                                      onPressed: _loadingData
                                          ? null
                                          : _loadStats,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Reintentar'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (stats != null) ...[
                            const SizedBox(height: 10),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Periodo: ${DateFormatter.formatApiDateForDisplay(stats.periodo.desde)} a '
                                  '${DateFormatter.formatApiDateForDisplay(stats.periodo.hasta)} '
                                  '(${stats.periodo.dias} dias)',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _KpiGrid(stats: stats),
                            const SizedBox(height: 10),
                            _StatusCard(stats: stats),
                            const SizedBox(height: 10),
                            _DetailCard(stats: stats),
                            const SizedBox(height: 10),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tendencia diaria',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (daily.isEmpty)
                                      const Text(
                                        'Sin datos diarios para el periodo seleccionado.',
                                      )
                                    else
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: daily.map((d) {
                                            final h =
                                                ((d.registros * 120.0) / maxDaily)
                                                    .clamp(8.0, 120.0);
                                            final label = DateFormatter
                                                .formatApiDateForDisplayShort(
                                                  d.fecha,
                                                );
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    width: 22,
                                                    height: h,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF0E5A8A,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            5,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    label,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  final EmployeeStatsResponse stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 940
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final aspectRatio = crossAxisCount == 1 ? 3.2 : 1.8;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _kpi(
              'Puntualidad',
              '${stats.kpis.puntualidadPct.toStringAsFixed(1)}%',
            ),
            _kpi(
              'Ausentismo',
              '${stats.kpis.ausentismoPct.toStringAsFixed(1)}%',
            ),
            _kpi('No-show', '${stats.kpis.noShowPct.toStringAsFixed(1)}%'),
            _kpi(
              'Jornada completa',
              '${stats.kpis.cumplimientoJornadaPct.toStringAsFixed(1)}%',
            ),
          ],
        );
      },
    );
  }

  Widget _kpi(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.stats});

  final EmployeeStatsResponse stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.totales.registros <= 0 ? 1 : stats.totales.registros;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribucion de estados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _bar('OK', stats.totales.ok, total, const Color(0xFF2F8F5B)),
            _bar('Tarde', stats.totales.tarde, total, const Color(0xFFD58D00)),
            _bar(
              'Ausente',
              stats.totales.ausente,
              total,
              const Color(0xFFC53A4D),
            ),
            _bar(
              'Salida ant.',
              stats.totales.salidaAnticipada,
              total,
              const Color(0xFF667A92),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(String label, int value, int total, Color color) {
    final pct = ((value * 100.0) / total).clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value (${pct.toStringAsFixed(1)}%)'),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: pct / 100.0,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            color: color,
            backgroundColor: const Color(0xFFE5ECF3),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.stats});

  final EmployeeStatsResponse stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Registros: ${stats.totales.registros}'),
            Text(
              'Jornadas completas: ${stats.jornadas.completas}/${stats.jornadas.conMarca}',
            ),
            Text(
              'Ausencias sin justificacion: ${stats.ausencias.sinJustificacion}/${stats.ausencias.total}',
            ),
            Text(
              'Justificaciones: ${stats.justificaciones.total} (Aprobadas ${stats.justificaciones.aprobadas}, Pendientes ${stats.justificaciones.pendientes})',
            ),
            Text(
              'Vacaciones: ${stats.vacaciones.eventos} evento(s), ${stats.vacaciones.dias} dia(s)',
            ),
          ],
        ),
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
    required this.onPresetMonth,
    required this.onPresetYear,
  });

  final TextEditingController desdeController;
  final TextEditingController hastaController;
  final String todayIso;
  final VoidCallback? onPickDesde;
  final VoidCallback? onPickHasta;
  final VoidCallback? onApply;
  final VoidCallback? onClear;
  final VoidCallback? onPresetMonth;
  final VoidCallback? onPresetYear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros (dd/MM/yyyy, max $todayIso)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: desdeController,
              readOnly: true,
              onTap: onPickDesde,
              decoration: InputDecoration(
                labelText: 'Desde',
                hintText: '01/02/2026',
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
                hintText: '27/02/2026',
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
                      OutlinedButton(
                        onPressed: onPresetMonth,
                        child: const Text('Mes actual'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onPresetYear,
                        child: const Text('Anio actual'),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPresetMonth,
                        child: const Text('Mes actual'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPresetYear,
                        child: const Text('Anio actual'),
                      ),
                    ),
                  ],
                );
              },
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
