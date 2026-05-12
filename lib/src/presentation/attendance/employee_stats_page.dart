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
  bool _filtersExpanded = false;
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

  String _fmtDisplayDate(DateTime date) => DateFormatter.formatDisplayDate(date);
  DateTime? _parseInputDate(String raw) => DateFormatter.parseFlexibleDate(raw);
  String? _controllerDateToApi(TextEditingController ctrl) =>
      DateFormatter.toApiDateOrNull(ctrl.text);

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
      return 'El rango de fechas es inválido (desde > hasta).';
    }
    if (effectiveHasta.difference(effectiveDesde).inDays > 366) {
      return 'El rango máximo permitido es 366 días.';
    }
    return null;
  }

  Future<void> _pickDate({required bool isDesde}) async {
    final today = _todayDate();
    final first = DateTime(2000, 1, 1);
    final fromCtrl = isDesde ? _desdeController : _hastaController;
    final otherCtrl = isDesde ? _hastaController : _desdeController;
    var current = _parseInputDate(fromCtrl.text) ?? today;
    if (current.isAfter(today)) current = today;
    if (current.isBefore(first)) current = first;

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: first,
      lastDate: today,
      helpText: isDesde ? 'Seleccionar fecha desde' : 'Seleccionar fecha hasta',
    );
    if (picked == null || !mounted) return;

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
    if (_loadingData) return;
    final validationError = _validateRangeInputs();
    if (validationError != null) {
      setState(() {
        _loading = false;
        _error = validationError;
      });
      return;
    }
    setState(() => _loadingData = true);
    try {
      final stats = await widget.apiClient.getEstadisticas(
        token: widget.token,
        desde: _controllerDateToApi(_desdeController),
        hasta: _controllerDateToApi(_hastaController),
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _error = null;
        _filtersExpanded = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado al consultar estadisticas.');
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
      setState(() => _error = validationError);
      return;
    }
    _loadStats();
  }

  void _clearFilters() {
    _desdeController.clear();
    _hastaController.clear();
    _loadStats();
  }

  void _set7Days() {
    final today = _todayDate();
    _desdeController.text = _fmtDisplayDate(today.subtract(const Duration(days: 6)));
    _hastaController.text = _fmtDisplayDate(today);
    _loadStats();
  }

  void _set30Days() {
    final today = _todayDate();
    _desdeController.text = _fmtDisplayDate(today.subtract(const Duration(days: 29)));
    _hastaController.text = _fmtDisplayDate(today);
    _loadStats();
  }

  void _setCurrentMonth() {
    final today = _todayDate();
    _desdeController.text = _fmtDisplayDate(DateTime(today.year, today.month, 1));
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis estadisticas'),
        bottom: _loadingData
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
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
                  final pad = constraints.maxWidth < 600 ? 12.0 : 16.0;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(pad, pad, pad, 32),
                        children: [
                          _FilterBar(
                            desdeController: _desdeController,
                            hastaController: _hastaController,
                            expanded: _filtersExpanded,
                            loading: _loadingData,
                            onToggleExpand: () => setState(
                              () => _filtersExpanded = !_filtersExpanded,
                            ),
                            onPickDesde:
                                _loadingData ? null : () => _pickDate(isDesde: true),
                            onPickHasta:
                                _loadingData ? null : () => _pickDate(isDesde: false),
                            onApply: _loadingData ? null : _applyFilters,
                            onClear: _loadingData ? null : _clearFilters,
                            onPreset7Days: _loadingData ? null : _set7Days,
                            onPreset30Days: _loadingData ? null : _set30Days,
                            onPresetMonth: _loadingData ? null : _setCurrentMonth,
                            onPresetYear: _loadingData ? null : _setCurrentYear,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            _ErrorCard(
                              message: _error!,
                              onRetry: _loadingData ? null : _loadStats,
                            ),
                          ],
                          if (stats != null) ...[
                            const SizedBox(height: 12),
                            _SummaryHero(stats: stats),
                            const SizedBox(height: 12),
                            _KpiSection(stats: stats),
                            const SizedBox(height: 12),
                            _HorasRachaCard(stats: stats),
                            const SizedBox(height: 12),
                            _StatusCard(stats: stats),
                            const SizedBox(height: 12),
                            _DetailGrid(stats: stats),
                            const SizedBox(height: 12),
                            _DailyChart(series: stats.series.diaria),
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

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.desdeController,
    required this.hastaController,
    required this.expanded,
    required this.loading,
    required this.onToggleExpand,
    required this.onPickDesde,
    required this.onPickHasta,
    required this.onApply,
    required this.onClear,
    required this.onPreset7Days,
    required this.onPreset30Days,
    required this.onPresetMonth,
    required this.onPresetYear,
  });

  final TextEditingController desdeController;
  final TextEditingController hastaController;
  final bool expanded;
  final bool loading;
  final VoidCallback onToggleExpand;
  final VoidCallback? onPickDesde;
  final VoidCallback? onPickHasta;
  final VoidCallback? onApply;
  final VoidCallback? onClear;
  final VoidCallback? onPreset7Days;
  final VoidCallback? onPreset30Days;
  final VoidCallback? onPresetMonth;
  final VoidCallback? onPresetYear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _PresetChip(label: '7 días', onTap: onPreset7Days),
                      _PresetChip(label: '30 días', onTap: onPreset30Days),
                      _PresetChip(label: 'Este mes', onTap: onPresetMonth),
                      _PresetChip(label: 'Este año', onTap: onPresetYear),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onToggleExpand,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Filtrar',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: desdeController,
                          readOnly: true,
                          onTap: onPickDesde,
                          decoration: InputDecoration(
                            labelText: 'Desde',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            suffixIcon: IconButton(
                              onPressed: onPickDesde,
                              icon: const Icon(Icons.calendar_month, size: 18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: hastaController,
                          readOnly: true,
                          onTap: onPickHasta,
                          decoration: InputDecoration(
                            labelText: 'Hasta',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            suffixIcon: IconButton(
                              onPressed: onPickHasta,
                              icon: const Icon(Icons.calendar_month, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onApply,
                          icon: loading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.search, size: 16),
                          label: const Text('Aplicar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onClear,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Limpiar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        color: onTap != null ? cs.onSecondaryContainer : cs.onSurface,
      ),
      backgroundColor: onTap != null
          ? cs.secondaryContainer
          : cs.surfaceContainerHighest,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: onTap,
    );
  }
}

// ─── Summary hero ─────────────────────────────────────────────────────────────

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.stats});

  final EmployeeStatsResponse stats;

  ({String label, String sub, IconData icon, Color color}) _verdict(
    BuildContext context,
  ) {
    final cs = Theme.of(context).colorScheme;
    final p = stats.kpis.puntualidadPct;
    final a = stats.kpis.ausentismoPct;

    if (p >= 85 && a <= 5) {
      return (
        label: 'Excelente asistencia',
        sub: 'Puntualidad destacada y ausentismo muy bajo.',
        icon: Icons.emoji_events_outlined,
        color: Colors.green.shade700,
      );
    }
    if (p >= 70 && a <= 12) {
      return (
        label: 'Buen desempeño',
        sub: 'Asistencia consistente en el período.',
        icon: Icons.thumb_up_alt_outlined,
        color: Colors.green.shade600,
      );
    }
    if (p >= 50) {
      return (
        label: 'Desempeño regular',
        sub: 'Hay margen de mejora en puntualidad o asistencia.',
        icon: Icons.trending_flat,
        color: Colors.amber.shade700,
      );
    }
    return (
      label: 'Requiere atención',
      sub: 'Nivel de asistencia o puntualidad bajo en el período.',
      icon: Icons.warning_amber_outlined,
      color: cs.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _verdict(context);
    final cs = Theme.of(context).colorScheme;
    final desde = DateFormatter.formatApiDateForDisplay(stats.periodo.desde);
    final hasta = DateFormatter.formatApiDateForDisplay(stats.periodo.hasta);
    final puntualidad = stats.kpis.puntualidadPct;
    final ausentismo = stats.kpis.ausentismoPct;
    final cumplimiento = stats.kpis.cumplimientoJornadaPct;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: v.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Periodo
                    Row(
                      children: [
                        Icon(
                          Icons.date_range_outlined,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$desde — $hasta  ·  ${stats.periodo.dias} días',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Veredicto
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: v.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(v.icon, color: v.color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.label,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  color: v.color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                v.sub,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Pills de metricas rapidas
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatPill(
                          label: 'Puntualidad',
                          value: '${puntualidad.toStringAsFixed(0)}%',
                          color: puntualidad >= 80
                              ? Colors.green.shade700
                              : puntualidad >= 60
                              ? Colors.amber.shade800
                              : cs.error,
                        ),
                        _StatPill(
                          label: 'Ausentismo',
                          value: '${ausentismo.toStringAsFixed(0)}%',
                          color: ausentismo <= 5
                              ? Colors.green.shade700
                              : ausentismo <= 15
                              ? Colors.amber.shade800
                              : cs.error,
                        ),
                        _StatPill(
                          label: 'Jornada completa',
                          value: '${cumplimiento.toStringAsFixed(0)}%',
                          color: cumplimiento >= 80
                              ? Colors.green.shade700
                              : cumplimiento >= 60
                              ? Colors.amber.shade800
                              : cs.error,
                        ),
                        _StatPill(
                          label: 'Registros',
                          value: '${stats.totales.registros}',
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.85),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KPI section (carousel on narrow, grid on wide) ───────────────────────────

class _KpiSection extends StatefulWidget {
  const _KpiSection({required this.stats});

  final EmployeeStatsResponse stats;

  @override
  State<_KpiSection> createState() => _KpiSectionState();
}

class _KpiSectionState extends State<_KpiSection> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.72);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<({IconData icon, String label, double value, bool highIsGood})>
  _items() {
    final kpis = widget.stats.kpis;
    return [
      (
        icon: Icons.schedule,
        label: 'Puntualidad',
        value: kpis.puntualidadPct,
        highIsGood: true,
      ),
      (
        icon: Icons.task_alt,
        label: 'Jornada completa',
        value: kpis.cumplimientoJornadaPct,
        highIsGood: true,
      ),
      (
        icon: Icons.leaderboard_outlined,
        label: 'Adherencia',
        value: kpis.adherenciaPct,
        highIsGood: true,
      ),
      (
        icon: Icons.event_busy_outlined,
        label: 'Ausentismo',
        value: kpis.ausentismoPct,
        highIsGood: false,
      ),
      (
        icon: Icons.person_off_outlined,
        label: 'No-show',
        value: kpis.noShowPct,
        highIsGood: false,
      ),
      (
        icon: Icons.logout,
        label: 'Salida anticipada',
        value: kpis.tasaSalidaAnticipadaPct,
        highIsGood: false,
      ),
      (
        icon: Icons.fact_check_outlined,
        label: 'Justificadas',
        value: widget.stats.justificaciones.tasaJustificacionPct,
        highIsGood: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _items();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Indicadores clave',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;

            if (wide) {
              // Grilla de 2 o 3 columnas
              final cols = constraints.maxWidth >= 760 ? 3 : 2;
              final itemW =
                  (constraints.maxWidth - (8.0 * (cols - 1))) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map(
                      (item) => SizedBox(
                        width: itemW,
                        height: 150,
                        child: _KpiCard(
                          icon: item.icon,
                          label: item.label,
                          value: item.value,
                          highIsGood: item.highIsGood,
                        ),
                      ),
                    )
                    .toList(),
              );
            }

            // Carrusel en movil angosto
            return Column(
              children: [
                SizedBox(
                  height: 158,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: items.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _KpiCard(
                          icon: item.icon,
                          label: item.label,
                          value: item.value,
                          highIsGood: item.highIsGood,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? cs.primary : cs.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.highIsGood,
  });

  final IconData icon;
  final String label;
  final double value;
  final bool highIsGood;

  Color _color(BuildContext context) {
    if (highIsGood) {
      if (value >= 80) return Colors.green.shade700;
      if (value >= 60) return Colors.amber.shade800;
      return Theme.of(context).colorScheme.error;
    } else {
      if (value <= 5) return Colors.green.shade700;
      if (value <= 15) return Colors.amber.shade800;
      return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(
                    value: (value / 100).clamp(0.0, 1.0),
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
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

// ─── Error card ──────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Horas / Racha / Días card ───────────────────────────────────────────────

class _HorasRachaCard extends StatelessWidget {
  const _HorasRachaCard({required this.stats});

  final EmployeeStatsResponse stats;

  @override
  Widget build(BuildContext context) {
    final kpis = stats.kpis;
    final cs = Theme.of(context).colorScheme;

    final horasTxt = kpis.horasTotales > 0
        ? '${kpis.horasTotales.toStringAsFixed(1)} h'
        : '-';
    final promTxt = kpis.horasPromedio > 0
        ? '${kpis.horasPromedio.toStringAsFixed(1)} h/día'
        : '-';
    final rachaTxt = kpis.rachaDiasOk > 0 ? '${kpis.rachaDiasOk} días' : '-';
    final gpsIncTxt = '${kpis.gpsIncidencias}';

    final rachaColor = kpis.rachaDiasOk >= 10
        ? Colors.green.shade700
        : kpis.rachaDiasOk >= 3
        ? Colors.amber.shade800
        : cs.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Horas y racha',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${kpis.diasConRegistro} / ${kpis.diasLaborables} días',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 400;
                final tiles = [
                  _MetricTile(
                    icon: Icons.access_time_outlined,
                    label: 'Horas totales',
                    value: horasTxt,
                    color: cs.primary,
                  ),
                  _MetricTile(
                    icon: Icons.av_timer_outlined,
                    label: 'Promedio diario',
                    value: promTxt,
                    color: cs.primary,
                  ),
                  _MetricTile(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Racha OK',
                    value: rachaTxt,
                    color: rachaColor,
                  ),
                  _MetricTile(
                    icon: Icons.gps_not_fixed,
                    label: 'Incidencias GPS',
                    value: gpsIncTxt,
                    color: kpis.gpsIncidencias == 0
                        ? Colors.green.shade700
                        : kpis.gpsIncidencias <= 3
                        ? Colors.amber.shade800
                        : cs.error,
                  ),
                ];
                if (wide) {
                  return Row(
                    children: tiles
                        .map((t) => Expanded(child: t))
                        .toList(),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tiles
                      .map((t) => SizedBox(
                            width: (constraints.maxWidth - 8) / 2,
                            child: t,
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ─── Status distribution card ────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.stats});

  final EmployeeStatsResponse stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = stats.totales;
    final total = t.registros <= 0 ? 1 : t.registros;

    // Segmentos de la barra apilada
    final segments = <(int, Color)>[
      (t.ok, Colors.green.shade600),
      (t.tarde, Colors.amber.shade700),
      (t.ausente, cs.error),
      (t.salidaAnticipada, Colors.blueGrey.shade400),
      if (t.sinEstado > 0) (t.sinEstado, cs.outline),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.donut_small_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Distribución de estados',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${t.registros} registros',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Barra apilada resumen
            if (t.registros > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: segments.map((seg) {
                      final pct = (seg.$1 * 1.0) / total;
                      return Flexible(
                        flex: (pct * 1000).round(),
                        child: Container(color: seg.$2),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            _bar(context, 'OK', t.ok, total, Colors.green.shade600),
            _bar(context, 'Tarde', t.tarde, total, Colors.amber.shade700),
            _bar(context, 'Ausente', t.ausente, total, cs.error),
            _bar(
              context,
              'Salida ant.',
              t.salidaAnticipada,
              total,
              Colors.blueGrey.shade400,
            ),
            if (t.sinEstado > 0)
              _bar(context, 'Sin estado', t.sinEstado, total, cs.outline),
          ],
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    String label,
    int value,
    int total,
    Color color,
  ) {
    final pct = ((value * 100.0) / total).clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$value',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 38,
                child: Text(
                  '${pct.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: pct / 100.0,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            color: color,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

// ─── Detail grid ─────────────────────────────────────────────────────────────

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.stats});

  final EmployeeStatsResponse stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final j = stats.justificaciones;
    final jor = stats.jornadas;
    final aus = stats.ausencias;
    final vac = stats.vacaciones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Detalle del período',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 480;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _DetailTile(
                          icon: Icons.work_outline,
                          title: 'Jornadas',
                          color: cs.primary,
                          rows: [
                            ('Completas', '${jor.completas}'),
                            ('Incompletas', '${jor.incompletas}'),
                            ('Con marca', '${jor.conMarca}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _DetailTile(
                          icon: Icons.fact_check_outlined,
                          title: 'Justificaciones',
                          color: Colors.indigo.shade600,
                          rows: [
                            ('Total', '${j.total}'),
                            ('Aprobadas', '${j.aprobadas}'),
                            ('Pendientes', '${j.pendientes}'),
                            ('Rechazadas', '${j.rechazadas}'),
                            if (j.total > 0)
                              (
                                'Tasa aprob.',
                                '${j.tasaAprobacionPct.toStringAsFixed(1)}%',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        _DetailTile(
                          icon: Icons.event_busy_outlined,
                          title: 'Ausencias',
                          color: cs.error,
                          rows: [
                            ('Total', '${aus.total}'),
                            ('Sin justificación', '${aus.sinJustificacion}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _DetailTile(
                          icon: Icons.beach_access_outlined,
                          title: 'Vacaciones',
                          color: Colors.teal.shade600,
                          rows: [
                            ('Eventos', '${vac.eventos}'),
                            ('Días', '${vac.dias}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Columna unica en movil
            return Column(
              children: [
                _DetailTile(
                  icon: Icons.work_outline,
                  title: 'Jornadas',
                  color: cs.primary,
                  rows: [
                    ('Completas', '${jor.completas}'),
                    ('Incompletas', '${jor.incompletas}'),
                    ('Con marca', '${jor.conMarca}'),
                  ],
                ),
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.event_busy_outlined,
                  title: 'Ausencias',
                  color: cs.error,
                  rows: [
                    ('Total', '${aus.total}'),
                    ('Sin justificación', '${aus.sinJustificacion}'),
                  ],
                ),
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.fact_check_outlined,
                  title: 'Justificaciones',
                  color: Colors.indigo.shade600,
                  rows: [
                    ('Total', '${j.total}'),
                    ('Aprobadas', '${j.aprobadas}'),
                    ('Pendientes', '${j.pendientes}'),
                    ('Rechazadas', '${j.rechazadas}'),
                    if (j.total > 0)
                      (
                        'Tasa aprob.',
                        '${j.tasaAprobacionPct.toStringAsFixed(1)}%',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.beach_access_outlined,
                  title: 'Vacaciones',
                  color: Colors.teal.shade600,
                  rows: [
                    ('Eventos', '${vac.eventos}'),
                    ('Días', '${vac.dias}'),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final Color color;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...rows.indexed.map((entry) {
              final i = entry.$1;
              final row = entry.$2;
              return Column(
                children: [
                  if (i > 0)
                    Divider(
                      height: 12,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        row.$1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        row.$2,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Daily chart ─────────────────────────────────────────────────────────────

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.series});

  final List<StatsDiariaItem> series;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Tendencia diaria',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _legendDot('OK', Colors.green.shade600),
                _legendDot('Tarde', Colors.amber.shade700),
                _legendDot('Ausente', cs.error),
                _legendDot('Otro', Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 12),
            if (series.isEmpty)
              Text(
                'Sin datos diarios para el período seleccionado.',
                style: TextStyle(color: cs.onSurfaceVariant),
              )
            else
              _buildChart(context),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    final maxReg = series.fold(0, (m, e) => e.registros > m ? e.registros : m);
    final effective = maxReg < 1 ? 1 : maxReg;
    final errorColor = Theme.of(context).colorScheme.error;
    final showCount = series.length <= 40;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: series.map((d) {
          final totalH = ((d.registros * 110.0) / effective).clamp(4.0, 110.0);
          final reg = d.registros < 1 ? 1 : d.registros;
          final okH = (d.ok * totalH / reg).clamp(0.0, totalH);
          final tardeH = (d.tarde * totalH / reg).clamp(0.0, totalH - okH);
          final ausenteH =
              (d.ausente * totalH / reg).clamp(0.0, totalH - okH - tardeH);
          final otroH = (totalH - okH - tardeH - ausenteH).clamp(0.0, totalH);
          final label = DateFormatter.formatApiDateForDisplayShort(d.fecha);

          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCount && d.registros > 0)
                  Text(
                    '${d.registros}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  const SizedBox(height: 12),
                SizedBox(
                  width: 24,
                  height: 110,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (otroH > 0) _seg(otroH, Colors.grey.shade400),
                            if (ausenteH > 0) _seg(ausenteH, errorColor),
                            if (tardeH > 0)
                              _seg(tardeH, Colors.amber.shade700),
                            if (okH > 0) _seg(okH, Colors.green.shade600),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 10)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _seg(double height, Color color) {
    return Container(width: 24, height: height, color: color);
  }
}
