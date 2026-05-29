import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class KpisSectorPage extends StatefulWidget {
  const KpisSectorPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<KpisSectorPage> createState() => _KpisSectorPageState();
}

class _KpisSectorPageState extends State<KpisSectorPage> with TickerProviderStateMixin {
  static const _limitMeses = 6;

  bool _loading = true;
  String? _error;
  KpisSectorResumenResponse? _summary;
  KpisSectorialResponse? _legacyData;
  KpisSectorDiaResponse? _diaHoy;
  int _anio = DateTime.now().year;
  int _selectedIdx = 0;
  int? _selectedMes; // null = vista anual, periodoMonth = vista mensual
  late final PageController _pageCtrl;
  late final TabController _tabCtrl;
  String? _calSelDate;
  final Map<String, KpisSectorDiaResponse> _diaCache = {};
  bool _loadingDia = false;

  List<KpiSectorialItem> get _kpis =>
      _summary?.kpis ?? _legacyData?.kpis ?? const [];

  KpisSectorialSector? get _sector =>
      _summary?.sector ?? _legacyData?.sector;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.82);
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.apiClient.getKpisSectorResumen(
        token: widget.token,
        anio: _anio,
        limitMeses: _limitMeses,
        includeSeries: true,
        seriesDias: 60,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _legacyData = null;
        _loading = false;
        _selectedIdx = 0;
        _selectedMes = null;
      });
      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(0);
      }
      // ignore: unawaited_futures
      if (_anio == DateTime.now().year) _loadDiaHoy();
    } on ApiException {
      await _loadLegacy();
    } catch (_) {
      await _loadLegacy();
    }
  }

  Future<void> _loadDiaHoy() async {
    if (!mounted) return;
    try {
      final hoy = DateTime.now();
      final fecha =
          '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
      final dia = await widget.apiClient.getKpisSectorDia(
        token: widget.token,
        fecha: fecha,
      );
      if (!mounted) return;
      setState(() => _diaHoy = dia);
    } catch (_) {
      // no bloquea la UI si falla
    }
  }

  List<KpiSectorPuntoDiario> _dailyFor(int kpiId) {
    final serie = _summary?.seriesDiaria
        ?.where((s) => s.kpiId == kpiId)
        .firstOrNull;
    return serie?.puntos ?? const [];
  }

  Future<void> _loadLegacy() async {
    try {
      final data = await widget.apiClient.getKpisSector(
        token: widget.token,
        anio: _anio,
      );
      if (!mounted) return;
      setState(() {
        _summary = null;
        _legacyData = data;
        _loading = false;
        _selectedIdx = 0;
        _selectedMes = null;
      });
      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(0);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error inesperado al cargar los KPIs.';
        _loading = false;
      });
    }
  }

  void _cambiarAnio(int delta) {
    final nuevo = _anio + delta;
    if (nuevo > DateTime.now().year) return;
    setState(() {
      _anio = nuevo;
      _selectedMes = null;
      _diaHoy = null;
    });
    _load();
  }

  void _selectMes(int? mes) => setState(() => _selectedMes = mes);

  void _goToKpi(int idx) {
    final clamped = idx.clamp(0, _kpis.length - 1);
    setState(() => _selectedIdx = clamped);
    if (_pageCtrl.hasClients) {
      _pageCtrl.animateToPage(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  List<({KpisSectorMesCerrado mes, KpiSectorMesItem item})> _historyFor(
    int kpiId,
  ) {
    if (_summary == null) return const [];
    final result =
        <({KpisSectorMesCerrado mes, KpiSectorMesItem item})>[];
    for (final mes in _summary!.mesesCerrados) {
      for (final item in mes.kpis) {
        if (item.kpiId == kpiId) {
          result.add((mes: mes, item: item));
          break;
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPIs del Sector'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Mes en curso'),
          ],
        ),
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
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Tab 0: Resumen (contenido existente sin modificar)
          RefreshIndicator(
            onRefresh: _load,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth =
                    constraints.maxWidth >= 900 ? 700.0 : double.infinity;
                final hPad = constraints.maxWidth < 480 ? 12.0 : 16.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _buildListBody(hPad),
                  ),
                );
              },
            ),
          ),
          // Tab 1: Mes en curso
          _buildCalendarioTab(),
        ],
      ),
    );
  }

  Widget _buildListBody(double hPad) {
    // Siempre devuelve ListView para que RefreshIndicator tenga un hijo scrollable.
    // Dependiendo del estado mostramos loading, error o contenido.
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 300,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(hPad),
        children: [_buildError()],
      );
    }

    final kpis = _kpis;
    if (kpis.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: hPad),
        children: [
          _PeriodSelector(
            anio: _anio,
            meses: _summary?.mesesCerrados ?? const [],
            selectedMes: _selectedMes,
            canGoNextYear: _anio < DateTime.now().year,
            onPrevYear: () => _cambiarAnio(-1),
            onNextYear: () => _cambiarAnio(1),
            onSelectMes: _selectMes,
          ),
          if (_sector?.nombre != null) _SectorHeader(sector: _sector!),
          _buildEmpty(),
        ],
      );
    }

    final selIdx = _selectedIdx.clamp(0, kpis.length - 1);
    final selectedKpi = kpis[selIdx];
    final history = _historyFor(selectedKpi.kpiId);

    // Mes seleccionado: buscar datos de ese mes para el KPI actual
    final mesEntry = _selectedMes == null
        ? null
        : history.where((e) => e.mes.periodoMonth == _selectedMes).firstOrNull;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ── Año + Mes en misma fila ──────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: _PeriodSelector(
            anio: _anio,
            meses: _summary?.mesesCerrados ?? const [],
            selectedMes: _selectedMes,
            canGoNextYear: _anio < DateTime.now().year,
            onPrevYear: () => _cambiarAnio(-1),
            onNextYear: () => _cambiarAnio(1),
            onSelectMes: _selectMes,
          ),
        ),
        if (_sector?.nombre != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _SectorHeader(sector: _sector!),
          ),
        // ── Navegación entre KPIs ────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: _KpiNavBar(
            kpis: kpis,
            selectedIdx: selIdx,
            onPrev: selIdx > 0 ? () => _goToKpi(selIdx - 1) : null,
            onNext: selIdx < kpis.length - 1 ? () => _goToKpi(selIdx + 1) : null,
            onDotTap: _goToKpi,
          ),
        ),
        const SizedBox(height: 6),
        // ── Carrusel ─────────────────────────────────────────────────────────
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: kpis.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (idx) => setState(() => _selectedIdx = idx),
            itemBuilder: (context, index) {
              final kpi = kpis[index];
              final isSelected = index == selIdx;
              // En vista mensual mostrar datos del mes si existen
              final mesForCard = _selectedMes == null
                  ? null
                  : _historyFor(kpi.kpiId)
                      .where((e) => e.mes.periodoMonth == _selectedMes)
                      .firstOrNull;
              return AnimatedScale(
                scale: isSelected ? 1.0 : 0.90,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad * 0.5,
                    vertical: 4,
                  ),
                  child: GestureDetector(
                    onTap: () => _goToKpi(index),
                    child: kpi.isBetween
                        ? _RangeGaugeCard(
                            kpi: kpi,
                            isSelected: isSelected,
                            mesItem: mesForCard?.item,
                          )
                        : _CircularGaugeCard(
                            kpi: kpi,
                            isSelected: isSelected,
                            mesItem: mesForCard?.item,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        // ── Snapshot de hoy (solo vista anual, año actual) ───────────────────
        if (_selectedMes == null &&
            _diaHoy != null &&
            _diaHoy!.kpis.any((k) => k.tieneResultado))
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _HoySnapshotCard(
              diaHoy: _diaHoy!,
              selectedKpiId: selectedKpi.kpiId,
            ),
          ),
        // ── Panel de detalle ─────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: _selectedMes != null && mesEntry == null
              // Mes seleccionado pero sin datos en backend
              ? _NoMonthDataPanel(
                  mesNombre: _shortMonthName(_selectedMes!),
                  anio: _anio,
                  kpiNombre: selectedKpi.nombre,
                )
              : mesEntry != null
              ? _KpiMonthDetailPanel(
                  kpi: selectedKpi,
                  mes: mesEntry.mes,
                  item: mesEntry.item,
                )
              : _KpiDetailPanel(
                  kpi: selectedKpi,
                  history: history,
                  dailyPoints: _dailyFor(selectedKpi.kpiId),
                ),
        ),
        // ── Historial mensual (solo en vista anual) ──────────────────────────
        if (_selectedMes == null && history.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _KpiHistorySection(history: history, kpi: selectedKpi),
          ),
        // ── Última carga ─────────────────────────────────────────────────────
        if (_summary?.ultimoCargado != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _UltimoCargadoCard(item: _summary!.ultimoCargado!),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // _buildAnioSelector eliminado — reemplazado por _PeriodSelector

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _sector?.id == null
                  ? 'No tenés sector asignado.'
                  : 'Sin KPIs configurados para $_anio.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Calendario: mes en curso ───────────────────────────────────────────────

  Set<String> get _datesWithData {
    final dates = <String>{};
    for (final serie in _summary?.seriesDiaria ?? []) {
      for (final punto in serie.puntos) {
        if (punto.resultadoDia != null) {
          final f = punto.fecha;
          dates.add(f.length >= 10 ? f.substring(0, 10) : f);
        }
      }
    }
    return dates;
  }

  Future<void> _loadDia(String fecha) async {
    if (_diaCache.containsKey(fecha)) {
      setState(() => _calSelDate = fecha);
      return;
    }
    setState(() {
      _loadingDia = true;
      _calSelDate = fecha;
    });
    try {
      final dia = await widget.apiClient.getKpisSectorDia(
        token: widget.token,
        fecha: fecha,
      );
      if (!mounted) return;
      setState(() {
        _diaCache[fecha] = dia;
        _loadingDia = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDia = false);
    }
  }

  Widget _buildCalendarioTab() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday;
    final datesWithData = _datesWithData;
    final selDia = _diaCache[_calSelDate];

    return LayoutBuilder(
      builder: (_, constraints) {
        final hPad = constraints.maxWidth < 480 ? 12.0 : 16.0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth >= 900 ? 700.0 : double.infinity,
            ),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
              children: [
                // Encabezado: nombre del mes y año
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_fullMonthName(month)} $year',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                // Etiquetas de día de semana
                Row(
                  children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                      .map(
                        (d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 4),
                // Grid del mes
                _buildMonthGrid(
                  year, month, daysInMonth, firstWeekday, now, datesWithData,
                ),
                const SizedBox(height: 20),
                // Detalle del día seleccionado
                if (_loadingDia)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_calSelDate != null) ...[
                  _buildDiaDetailHeader(_calSelDate!, selDia),
                  const SizedBox(height: 8),
                  if (selDia == null ||
                      !selDia.kpis.any((k) => k.tieneResultado))
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Sin registros para este día.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...selDia.kpis.map((k) => _KpiDiaCard(kpi: k)),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 40,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tocá un día para ver los indicadores.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthGrid(
    int year,
    int month,
    int daysInMonth,
    int firstWeekday,
    DateTime now,
    Set<String> datesWithData,
  ) {
    final leadingEmpty = firstWeekday - 1; // Lun=0 .. Dom=6
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final cs = Theme.of(context).colorScheme;
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIdx = row * 7 + col;
            final day = cellIdx - leadingEmpty + 1;
            if (day < 1 || day > daysInMonth) {
              return const Expanded(child: SizedBox(height: 44));
            }
            final date = DateTime(year, month, day);
            final dateStr =
                '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final isToday = date == today;
            final isFuture = date.isAfter(today);
            final isSelected = _calSelDate == dateStr;
            final hasData = datesWithData.contains(dateStr);

            return Expanded(
              child: GestureDetector(
                onTap: isFuture ? null : () => _loadDia(dateStr),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 44,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary
                        : isToday
                            ? cs.primaryContainer
                            : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isSelected
                              ? cs.onPrimary
                              : isFuture
                                  ? const Color(0xFFBDBDBD)
                                  : isToday
                                      ? cs.primary
                                      : cs.onSurface,
                        ),
                      ),
                      if (hasData && !isFuture)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? cs.onPrimary.withValues(alpha: 0.85)
                                : cs.primary,
                          ),
                        )
                      else
                        const SizedBox(height: 7),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildDiaDetailHeader(
    String fecha,
    KpisSectorDiaResponse? diaResp,
  ) {
    final cs = Theme.of(context).colorScheme;
    final parts = fecha.split('-');
    final day = parts.length == 3 ? int.tryParse(parts[2]) ?? 0 : 0;
    final month = parts.length == 3 ? int.tryParse(parts[1]) ?? 0 : 0;
    final monthName = month > 0 ? _shortMonthName(month) : '';
    final kpisConDato =
        diaResp?.kpis.where((k) => k.tieneResultado).length ?? 0;
    final totalKpis = diaResp?.kpis.length ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$day $monthName',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 8),
        if (diaResp != null)
          Text(
            '· $kpisConDato/$totalKpis indicadores',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

// ─── Selector de período (año + chips de mes) ────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.anio,
    required this.meses,
    required this.selectedMes,
    required this.canGoNextYear,
    required this.onPrevYear,
    required this.onNextYear,
    required this.onSelectMes,
  });

  final int anio;
  final List<KpisSectorMesCerrado> meses;
  final int? selectedMes;
  final bool canGoNextYear;
  final VoidCallback onPrevYear;
  final VoidCallback onNextYear;
  final ValueChanged<int?> onSelectMes;

  // Meses cerrados del año: para el año actual son Jan..mes_anterior;
  // para años pasados son todos los 12 meses.
  List<int> get _closedMonthNumbers {
    final now = DateTime.now();
    if (anio < now.year) return List.generate(12, (i) => i + 1);
    if (anio == now.year && now.month > 1) {
      return List.generate(now.month - 1, (i) => i + 1);
    }
    return []; // enero del año actual todavía no hay mes cerrado
  }

  @override
  Widget build(BuildContext context) {
    final closedNums = _closedMonthNumbers;
    // Índice rápido: mes → datos del backend (puede no existir si no hay datos)
    final mesDataMap = {for (final m in meses) m.periodoMonth: m};

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila del año
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrevYear,
            ),
            Text(
              '$anio',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: canGoNextYear ? onNextYear : null,
            ),
          ],
        ),
        // Chips de meses — siempre visibles si hay meses cerrados en el calendario
        if (closedNums.isNotEmpty) ...[
          const SizedBox(height: 2),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2),
              children: [
                // "Año" = vista anual
                _MesChip(
                  label: 'Año',
                  selected: selectedMes == null,
                  onTap: () => onSelectMes(null),
                ),
                const SizedBox(width: 6),
                // Un chip por cada mes cerrado del calendario
                for (final num in closedNums) ...[
                  _MesChip(
                    label: _shortMonthName(num),
                    selected: selectedMes == num,
                    // Dot de color solo si el backend trajo datos para ese mes
                    semaforo: mesDataMap.containsKey(num)
                        ? _mesOverallSemaforo(mesDataMap[num]!)
                        : null,
                    hasData: mesDataMap.containsKey(num),
                    onTap: () => onSelectMes(num),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  String _mesOverallSemaforo(KpisSectorMesCerrado mes) {
    final r = mes.resumen;
    if (r.rojo > 0) return 'rojo';
    if (r.amarillo > 0) return 'amarillo';
    if (r.verde > 0) return 'verde';
    return 'gris';
  }
}

// Nombre corto del mes por número (1=Ene...12=Dic)
String _shortMonthName(int month) {
  const names = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];
  if (month < 1 || month > 12) return '$month';
  return names[month - 1];
}

// Nombre completo del mes por número (1=Enero...12=Diciembre)
String _fullMonthName(int month) {
  const names = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  if (month < 1 || month > 12) return '$month';
  return names[month - 1];
}

class _MesChip extends StatelessWidget {
  const _MesChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.semaforo,
    this.hasData = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? semaforo;
  /// false = mes sin datos del backend (chip atenuado, sin dot)
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected
        ? cs.primaryContainer
        : hasData
        ? cs.surfaceContainerHighest
        : cs.surfaceContainerLowest;
    final fg = selected
        ? cs.onPrimaryContainer
        : hasData
        ? cs.onSurfaceVariant
        : cs.onSurface.withValues(alpha: 0.35);
    final dotColor = semaforo != null ? _semaforoFg(semaforo!) : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: cs.primary.withValues(alpha: 0.4))
              : hasData
              ? Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot de semáforo (solo si hay datos del backend)
            if (dotColor != null && hasData) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Barra de navegación entre KPIs ──────────────────────────────────────────

class _KpiNavBar extends StatelessWidget {
  const _KpiNavBar({
    required this.kpis,
    required this.selectedIdx,
    required this.onPrev,
    required this.onNext,
    required this.onDotTap,
  });

  final List<KpiSectorialItem> kpis;
  final int selectedIdx;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<int> onDotTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kpi = kpis[selectedIdx];
    final total = kpis.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Flecha izquierda
        _NavArrow(
          icon: Icons.chevron_left,
          onPressed: onPrev,
        ),
        // Centro: nombre + posición + dots
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kpi.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 4),
              // Contador + dots (solo cuando hay ≤6 KPIs, si no solo el número)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${selectedIdx + 1} / $total',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (total <= 6) ...[
                    const SizedBox(width: 8),
                    for (var i = 0; i < total; i++)
                      GestureDetector(
                        onTap: () => onDotTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: i == selectedIdx ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == selectedIdx ? cs.primary : cs.outlineVariant,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Flecha derecha
        _NavArrow(
          icon: Icons.chevron_right,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Material(
      color: enabled
          ? cs.primaryContainer
          : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? cs.onPrimaryContainer : cs.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// ─── Sector header ────────────────────────────────────────────────────────────

class _SectorHeader extends StatelessWidget {
  const _SectorHeader({required this.sector});

  final KpisSectorialSector sector;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.group_work_outlined, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              sector.nombre ?? 'Sector no asignado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta gauge circular ───────────────────────────────────────────────────

class _CircularGaugeCard extends StatelessWidget {
  const _CircularGaugeCard({
    required this.kpi,
    required this.isSelected,
    this.mesItem,
  });

  final KpiSectorialItem kpi;
  final bool isSelected;
  final KpiSectorMesItem? mesItem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMes = mesItem != null && mesItem!.registros > 0;
    final semaforo = hasMes ? mesItem!.semaforo : kpi.semaforo;
    final fg = _semaforoFg(semaforo);
    final bg = _semaforoBg(semaforo);
    final resultado = hasMes ? (mesItem!.resultadoMes ?? kpi.resultadoAcumulado) : kpi.resultadoAcumulado;
    final gaugeValue = hasMes && mesItem != null
        ? _kpiGaugeValueMes(kpi, mesItem!)
        : _kpiGaugeValue(kpi);
    final isSuma = kpi.tipoAcumulacion == 'suma';
    final unidad = kpi.unidad != null ? '\n${kpi.unidad}' : '';
    // Para suma: mostrar % de progreso del gauge; para otros: el valor real
    final progresoSuma = hasMes ? (mesItem?.progresoPct ?? kpi.progresoPct) : kpi.progresoPct;
    final centerLabel = isSuma
        ? '${progresoSuma.toStringAsFixed(0)}%'
        : _fmt(resultado) + unidad;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? cs.surface : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: fg.withValues(alpha: 0.45), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              kpi.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: CircularProgressIndicator(
                    value: gaugeValue,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: fg.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(fg),
                  ),
                ),
                Text(
                  centerLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSuma ? 17 : 13,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SemaforoChip(semaforo: semaforo, fg: fg, bg: bg),
          ],
        ),
      ),
    );
  }
}

// ─── Tarjeta de rango (between) ───────────────────────────────────────────────

class _RangeGaugeCard extends StatelessWidget {
  const _RangeGaugeCard({
    required this.kpi,
    required this.isSelected,
    this.mesItem,
  });

  final KpiSectorialItem kpi;
  final bool isSelected;
  final KpiSectorMesItem? mesItem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMes = mesItem != null && mesItem!.registros > 0;
    final semaforo = hasMes ? mesItem!.semaforo : kpi.semaforo;
    final fg = _semaforoFg(semaforo);
    final bg = _semaforoBg(semaforo);
    final unidad = kpi.unidad != null ? ' ${kpi.unidad}' : '';
    final min = kpi.valorMin ?? 0;
    final max = kpi.valorMax ?? 0;
    final result = hasMes
        ? (mesItem!.resultadoMes ?? kpi.resultadoAcumulado)
        : kpi.resultadoAcumulado;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? cs.surface : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: fg.withValues(alpha: 0.45), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              kpi.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_fmt(result)}$unidad',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: fg,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            _MiniRangeBar(min: min, max: max, result: result, fg: fg),
            const SizedBox(height: 4),
            Text(
              '${_fmt(min)} – ${_fmt(max)}$unidad',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            _SemaforoChip(semaforo: semaforo, fg: fg, bg: bg),
          ],
        ),
      ),
    );
  }
}

// ─── Panel de detalle del KPI seleccionado ────────────────────────────────────

class _KpiDetailPanel extends StatelessWidget {
  const _KpiDetailPanel({
    required this.kpi,
    required this.history,
    this.dailyPoints = const [],
  });

  final KpiSectorialItem kpi;
  final List<({KpisSectorMesCerrado mes, KpiSectorMesItem item})> history;
  final List<KpiSectorPuntoDiario> dailyPoints;

  Color get _fg => _semaforoFg(kpi.semaforo);
  Color get _bg => _semaforoBg(kpi.semaforo);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unidad = kpi.unidad != null ? ' ${kpi.unidad}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    kpi.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SemaforoChip(semaforo: kpi.semaforo, fg: _fg, bg: _bg),
              ],
            ),
            // Tipo / condición del KPI
            const SizedBox(height: 6),
            _KpiTypeLabel(kpi: kpi, unidad: unidad),
            if (kpi.recomendacion != null) ...[
              const SizedBox(height: 4),
              Text(
                kpi.recomendacion!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _fg,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            // Visualización principal
            kpi.isBetween
                ? _buildBetweenDetail(context, unidad)
                : _buildLinealDetail(context, unidad),
            // Banner de desviación
            const SizedBox(height: 12),
            _DeviationBanner(kpi: kpi, unidad: unidad),
            // Mini gráfico si hay historial
            if (history.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Evolución mensual',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              (kpi.isBetween ||
                      kpi.tipoAcumulacion == 'promedio' ||
                      kpi.tipoAcumulacion == 'ultimo')
                  ? _MiniLineChart(
                      points: history,
                      color: _fg,
                      unidad: unidad,
                    )
                  : _MonthlyBarsChart(points: history, unidad: unidad),
            ],
            if (dailyPoints.isNotEmpty)
              _DailySparklineSection(points: dailyPoints, kpi: kpi),
          ],
        ),
      ),
    );
  }

  /// Layout centrado: gauge grande arriba centrado + grid de stats abajo.
  Widget _buildLinealDetail(BuildContext context, String unidad) {
    final cs = Theme.of(context).colorScheme;
    final gaugeValue = _kpiGaugeValue(kpi);
    final isSuma = kpi.tipoAcumulacion == 'suma';
    final isPromedio = kpi.tipoAcumulacion == 'promedio';

    // Etiqueta central del gauge
    final centerLabel = isSuma
        ? '${kpi.progresoPct.toStringAsFixed(0)}%'
        : '${_fmt(kpi.resultadoAcumulado)}$unidad';

    // Diferencia vs objetivo (solo para promedio/ultimo).
    // Usamos el semáforo del API como fuente de verdad sobre si el resultado
    // es bueno o malo — evita depender de mayorEsMejor que puede venir mal configurado.
    final delta = kpi.resultadoAcumulado - kpi.objetivoAnual;
    final diffGood = kpi.semaforo == 'verde';
    final diffColor = diffGood ? Colors.green.shade700 : Colors.orange.shade700;
    final hasDiff = kpi.objetivoAnual != 0;

    final statCells = <_StatCellData>[
      _StatCellData(
        label: isPromedio
            ? 'Promedio'
            : kpi.tipoAcumulacion == 'ultimo'
            ? 'Último valor'
            : 'Acumulado',
        value: '${_fmt(kpi.resultadoAcumulado)}$unidad',
        color: _fg,
        large: true,
      ),
      _StatCellData(
        label: 'Objetivo${kpi.condicionSimbolo != null ? ' (${kpi.condicionSimbolo})' : ''}',
        value: '${_fmt(kpi.objetivoAnual)}$unidad',
        color: cs.onSurfaceVariant,
      ),
      // Para suma: mostrar "Progreso X%" tiene sentido (% del total anual alcanzado)
      // Para promedio/ultimo: mostrar la diferencia real en unidades
      if (isSuma)
        _StatCellData(
          label: 'Progreso anual',
          value: '${kpi.progresoPct.toStringAsFixed(1)}%',
          color: _fg,
        )
      else if (hasDiff)
        _StatCellData(
          label: _diffLabel(diffGood, kpi.condicion),
          value: _diffValue(diffGood, delta, unidad, kpi.condicion),
          color: diffColor,
        ),
      if (isSuma && kpi.progresoEsperadoPct < 99)
        _StatCellData(
          label: 'Ritmo esperado',
          value: '${kpi.progresoEsperadoPct.toStringAsFixed(1)}%',
          color: cs.onSurfaceVariant,
        ),
    ];

    return Column(
      children: [
        // Gauge centrado
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: gaugeValue,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: _fg.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(_fg),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isSuma ? 24 : 16,
                      fontWeight: FontWeight.w800,
                      color: _fg,
                      height: 1,
                    ),
                  ),
                  if (isSuma) ...[
                    const SizedBox(height: 3),
                    Text(
                      'del objetivo',
                      style: TextStyle(
                        fontSize: 10,
                        color: _fg.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _StatsRow(cells: statCells),
      ],
    );
  }

  Widget _buildBetweenDetail(BuildContext context, String unidad) {
    final cs = Theme.of(context).colorScheme;
    final min = kpi.valorMin ?? 0;
    final max = kpi.valorMax ?? 0;
    final result = kpi.resultadoAcumulado;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_fmt(result)}$unidad',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _fg,
                          height: 1,
                        ),
                      ),
                      Text(
                        'Resultado actual',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatCell(
                      label: 'Mínimo',
                      value: '${_fmt(min)}$unidad',
                      color: cs.onSurfaceVariant,
                      align: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    _StatCell(
                      label: 'Máximo',
                      value: '${_fmt(max)}$unidad',
                      color: cs.onSurfaceVariant,
                      align: TextAlign.right,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MiniRangeBar(min: min, max: max, result: result, fg: _fg),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(min),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                Text(
                  'Rango objetivo',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                Text(
                  _fmt(max),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─── Datos para celda de estadística ─────────────────────────────────────────

class _StatCellData {
  const _StatCellData({
    required this.label,
    required this.value,
    required this.color,
    this.large = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool large;
}

// ─── Celda de estadística ─────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
    this.large = false,
    this.align = TextAlign.start,
  });

  final String label;
  final String value;
  final Color color;
  final bool large;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: switch (align) {
        TextAlign.right => CrossAxisAlignment.end,
        TextAlign.center => CrossAxisAlignment.center,
        _ => CrossAxisAlignment.start,
      },
      children: [
        Text(
          label,
          textAlign: align,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value,
          textAlign: align,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: large ? 16 : 13,
            color: color,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

// ─── Banner de desviación ─────────────────────────────────────────────────────

class _DeviationBanner extends StatelessWidget {
  const _DeviationBanner({required this.kpi, required this.unidad});

  final KpiSectorialItem kpi;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    final info = kpi.isBetween ? _betweenDeviation() : _linealDeviation();
    if (info == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: info.color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(info.icon, size: 18, color: info.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: info.color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  info.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            info.badge,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }

  _DeviationInfo _linealDeviation() {
    if (kpi.tipoAcumulacion == 'suma') {
      final esperado = kpi.progresoEsperadoPct;
      final actual = kpi.progresoPct;
      final delta = actual - esperado;

      if (esperado >= 99) {
        final ok = kpi.mayorEsMejor ? actual >= 100 : actual <= 100;
        return _DeviationInfo(
          icon: ok ? Icons.check_circle_outline : Icons.pending_outlined,
          color: ok ? Colors.green.shade700 : Colors.orange.shade700,
          title: ok ? 'Objetivo alcanzado' : 'Objetivo no alcanzado',
          subtitle: 'Progreso final del año',
          badge: '${actual.toStringAsFixed(0)}%',
        );
      }

      final ahead = kpi.mayorEsMejor ? delta >= 0 : delta <= 0;
      final absDelta = delta.abs();
      return _DeviationInfo(
        icon: ahead ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        color: ahead ? Colors.green.shade700 : Colors.orange.shade700,
        title: ahead
            ? 'Adelantado al ritmo esperado'
            : 'Por debajo del ritmo esperado',
        subtitle:
            'Esperado ${esperado.toStringAsFixed(1)}%  ·  Actual ${actual.toStringAsFixed(1)}%',
        badge: '${ahead ? '+' : '-'}${absDelta.toStringAsFixed(1)}%',
      );
    }

    // promedio / ultimo
    final objetivo = kpi.objetivoAnual;
    if (objetivo == 0) {
      return _DeviationInfo(
        icon: Icons.info_outline,
        color: Colors.grey.shade600,
        title: 'Sin objetivo definido',
        subtitle: 'No hay valor de referencia configurado',
        badge: '—',
      );
    }
    final delta = kpi.resultadoAcumulado - objetivo;
    // Semáforo del API = fuente de verdad. Evita depender de mayorEsMejor
    // que puede estar mal configurado en el backend (ej. DQI con mayorEsMejor=true).
    final good = kpi.semaforo == 'verde';

    return _DeviationInfo(
      icon: good ? Icons.check_circle_outline : Icons.warning_amber_outlined,
      color: good ? Colors.green.shade700 : Colors.orange.shade700,
      title: _deviationTitle(good, kpi.condicion),
      subtitle:
          'Objetivo ${_fmt(objetivo)}$unidad  ·  Resultado ${_fmt(kpi.resultadoAcumulado)}$unidad',
      badge: _deviationBadge(good, delta, unidad, kpi.condicion),
    );
  }

  _DeviationInfo? _betweenDeviation() {
    final min = kpi.valorMin;
    final max = kpi.valorMax;
    if (min == null || max == null) return null;
    final result = kpi.resultadoAcumulado;

    if (result >= min && result <= max) {
      final mid = (min + max) / 2;
      final halfRange = (max - min) / 2;
      final distFromMid = (result - mid).abs();
      final pctFromCenter =
          halfRange > 0 ? (distFromMid / halfRange * 100) : 0.0;
      return _DeviationInfo(
        icon: Icons.check_circle_outline,
        color: Colors.green.shade700,
        title: 'Dentro del rango objetivo',
        subtitle:
            'Rango ${_fmt(min)} – ${_fmt(max)}$unidad  ·  ${pctFromCenter.toStringAsFixed(0)}% del centro',
        badge: '✓',
      );
    } else if (result < min) {
      final delta = min - result;
      return _DeviationInfo(
        icon: Icons.arrow_downward,
        color: Colors.orange.shade700,
        title: 'Bajo el mínimo del rango',
        subtitle:
            'Mínimo ${_fmt(min)}$unidad  ·  Resultado ${_fmt(result)}$unidad',
        badge: '-${_fmt(delta)}$unidad',
      );
    } else {
      final delta = result - max;
      return _DeviationInfo(
        icon: Icons.arrow_upward,
        color: Colors.orange.shade700,
        title: 'Sobre el máximo del rango',
        subtitle:
            'Máximo ${_fmt(max)}$unidad  ·  Resultado ${_fmt(result)}$unidad',
        badge: '+${_fmt(delta)}$unidad',
      );
    }
  }
}

class _DeviationInfo {
  const _DeviationInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String badge;
}

// ─── Historial mensual ────────────────────────────────────────────────────────

class _KpiHistorySection extends StatelessWidget {
  const _KpiHistorySection({required this.history, required this.kpi});

  final List<({KpisSectorMesCerrado mes, KpiSectorMesItem item})> history;
  final KpiSectorialItem kpi;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unidad = kpi.unidad != null ? ' ${kpi.unidad}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Meses cerrados',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...history.reversed.map(
              (e) => _MonthRow(
                mes: e.mes,
                item: e.item,
                unidad: unidad,
                isBetween: kpi.isBetween,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.mes,
    required this.item,
    required this.unidad,
    required this.isBetween,
  });

  final KpisSectorMesCerrado mes;
  final KpiSectorMesItem item;
  final String unidad;
  final bool isBetween;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rowFg = _semaforoFg(item.semaforo);
    final hasData = item.resultadoMes != null && item.registros > 0;
    final barValue =
        hasData ? (item.progresoPct / 100).clamp(0.0, 1.0).toDouble() : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Nombre del mes (truncado pero siempre 3 letras)
          SizedBox(
            width: 36,
            child: Text(
              _shortMonthLabel(mes),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          // Barra de progreso — ocupa el espacio restante
          Expanded(
            child: isBetween
                ? _buildRangeBar(item)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barValue,
                      minHeight: 8,
                      color: hasData ? rowFg : Colors.grey.shade300,
                      backgroundColor: hasData
                          ? rowFg.withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Valor — flexible para no desbordarse
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80, minWidth: 40),
              child: Text(
                hasData
                    ? '${_fmtNullable(item.resultadoMes)}$unidad'
                    : '—',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: hasData
                      ? rowFg
                      : cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hasData ? rowFg : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeBar(KpiSectorMesItem item) {
    final min = item.valorMin ?? 0;
    final max = item.valorMax ?? 0;
    final result = item.resultadoMes ?? 0;
    return _MiniRangeBar(
      min: min,
      max: max,
      result: result,
      fg: _semaforoFg(item.semaforo),
    );
  }
}

// ─── Tarjeta de última carga ──────────────────────────────────────────────────

class _UltimoCargadoCard extends StatelessWidget {
  const _UltimoCargadoCard({required this.item});

  final KpiSectorUltimoCargado item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _semaforoFg(item.semaforo);
    final unidad = item.unidad != null ? ' ${item.unidad}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _semaforoBg(item.semaforo),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.bolt_outlined, color: fg, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Última carga',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    item.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (item.fechaResultado != null)
                    Text(
                      _shortDate(item.fechaResultado!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_fmt(item.resultado)}$unidad',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Gráfico de barras mensuales ──────────────────────────────────────────────

class _MonthlyBarsChart extends StatelessWidget {
  const _MonthlyBarsChart({required this.points, required this.unidad});

  final List<({KpisSectorMesCerrado mes, KpiSectorMesItem item})> points;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    final ordered = points.reversed.toList(growable: false);
    return SizedBox(
      height: 70,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in ordered)
            Expanded(
              child: Tooltip(
                message:
                    '${_monthLabel(e.mes)}: ${_fmtNullable(e.item.resultadoMes)}$unidad',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: _barH(e.item),
                            child: Container(
                              width: 12,
                              decoration: BoxDecoration(
                                color: _barColor(e.item),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shortMonthLabel(e.mes),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: Theme.of(context).textTheme.labelSmall,
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

  double _barH(KpiSectorMesItem item) {
    if (item.resultadoMes == null || item.registros == 0) return 0.08;
    return (item.progresoPct / 100).clamp(0.08, 1.0).toDouble();
  }

  Color _barColor(KpiSectorMesItem item) {
    if (item.resultadoMes == null || item.registros == 0) {
      return Colors.grey.shade300;
    }
    return _semaforoFg(item.semaforo).withValues(alpha: 0.75);
  }
}

// ─── Mini gráfico de línea ────────────────────────────────────────────────────

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({
    required this.points,
    required this.color,
    required this.unidad,
  });

  final List<({KpisSectorMesCerrado mes, KpiSectorMesItem item})> points;
  final Color color;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    final ordered = points.reversed.toList(growable: false);
    final values = ordered.map((e) => e.item.resultadoMes).toList();
    final tooltip = ordered
        .map(
          (e) =>
              '${_monthLabel(e.mes)}: ${_fmtNullable(e.item.resultadoMes)}$unidad',
        )
        .join('\n');

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrendLinePainter(values: values, color: color),
        ),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  const _TrendLinePainter({required this.values, required this.color});

  final List<double?> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final validValues = values.whereType<double>().toList();
    if (validValues.isEmpty) return;

    final minValue = validValues.reduce(math.min);
    final maxValue = validValues.reduce(math.max);
    final range = maxValue - minValue;
    final pts = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final normalized = range == 0 ? 0.5 : (v - minValue) / range;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      pts.add(Offset(x, y));
    }

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 4),
      Offset(size.width, size.height - 4),
      gridPaint,
    );

    if (pts.length > 1) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..color = color;
    for (final p in pts) {
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter old) =>
      old.values != values || old.color != color;
}

// ─── Barra de rango compacta ──────────────────────────────────────────────────

class _MiniRangeBar extends StatelessWidget {
  const _MiniRangeBar({
    required this.min,
    required this.max,
    required this.result,
    required this.fg,
  });

  final double min;
  final double max;
  final double result;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final scaleMax = math.max(max * 1.4, result.abs() * 1.1);
    final safeScale = scaleMax <= 0 ? 1.0 : scaleMax;
    final minPct = (min / safeScale).clamp(0.0, 1.0).toDouble();
    final maxPct = (max / safeScale).clamp(0.0, 1.0).toDouble();
    final resultPct = (result / safeScale).clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: w * minPct,
                child: Container(
                  height: 8,
                  width: (w * (maxPct - minPct)).clamp(0.0, w),
                  decoration: BoxDecoration(
                    color: Colors.green.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: (w * resultPct - 2).clamp(0.0, w - 4),
                child: Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: fg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Chip de semáforo ─────────────────────────────────────────────────────────

class _SemaforoChip extends StatelessWidget {
  const _SemaforoChip({
    required this.semaforo,
    required this.fg,
    required this.bg,
  });

  final String semaforo;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_semaforoIcon(semaforo), color: fg, size: 11),
          const SizedBox(width: 3),
          Text(
            _statusLabel(semaforo),
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Etiqueta de tipo/condición del KPI ──────────────────────────────────────

class _KpiTypeLabel extends StatelessWidget {
  const _KpiTypeLabel({required this.kpi, required this.unidad});

  final KpiSectorialItem kpi;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final obj = _fmt(kpi.objetivoAnual);

    final IconData icon;
    final String label;

    if (kpi.isBetween) {
      icon = Icons.straighten_outlined;
      label = 'Rango objetivo: ${_fmt(kpi.valorMin ?? 0)} – ${_fmt(kpi.valorMax ?? 0)}$unidad';
    } else if (kpi.condicion == 'lte') {
      icon = Icons.arrow_downward;
      label = 'Límite máximo (≤ $obj$unidad) — menor es mejor';
    } else if (kpi.condicion == 'gte') {
      icon = Icons.arrow_upward;
      label = 'Objetivo mínimo (≥ $obj$unidad) — mayor es mejor';
    } else if (kpi.condicion == 'eq') {
      icon = Icons.drag_handle;
      label = 'Objetivo exacto: $obj$unidad';
    } else if (kpi.tipoAcumulacion == 'suma') {
      icon = Icons.bar_chart;
      label = 'Acumulado anual — objetivo: $obj$unidad';
    } else {
      icon = Icons.info_outline;
      label = kpi.objetivoAnual != 0 ? 'Objetivo: $obj$unidad' : 'Sin objetivo configurado';
    }

    return Row(
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

// ─── Fila de stats con divisores (usada en detalle anual y mensual) ──────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.cells});

  final List<_StatCellData> cells;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (cells.isEmpty) return const SizedBox.shrink();

    return IntrinsicHeight(
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _StatCell(
                    label: cells[i].label,
                    value: cells[i].value,
                    color: cells[i].color,
                    large: cells[i].large,
                    align: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Panel "sin datos para el mes" ───────────────────────────────────────────

class _NoMonthDataPanel extends StatelessWidget {
  const _NoMonthDataPanel({
    required this.mesNombre,
    required this.anio,
    required this.kpiNombre,
  });

  final String mesNombre;
  final int anio;
  final String kpiNombre;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 40,
              color: cs.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '$mesNombre $anio',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sin datos cargados para $kpiNombre en este mes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Panel de detalle mensual ─────────────────────────────────────────────────

class _KpiMonthDetailPanel extends StatelessWidget {
  const _KpiMonthDetailPanel({
    required this.kpi,
    required this.mes,
    required this.item,
  });

  final KpiSectorialItem kpi;
  final KpisSectorMesCerrado mes;
  final KpiSectorMesItem item;

  Color get _fg => _semaforoFg(item.semaforo);
  Color get _bg => _semaforoBg(item.semaforo);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unidad = kpi.unidad != null ? ' ${kpi.unidad}' : '';
    final mesNombre = mes.mesNombre ?? mes.periodo;
    final hasData = item.resultadoMes != null && item.registros > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kpi.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        mesNombre,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _SemaforoChip(semaforo: item.semaforo, fg: _fg, bg: _bg),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Sin datos para este mes',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            else ...[
              kpi.isBetween
                  ? _buildBetweenMonth(context, unidad)
                  : _buildLinealMonth(context, unidad),
              const SizedBox(height: 12),
              _MonthDeviationBanner(kpi: kpi, item: item, unidad: unidad),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLinealMonth(BuildContext context, String unidad) {
    final isSuma = kpi.tipoAcumulacion == 'suma';
    final isPromedio = kpi.tipoAcumulacion == 'promedio';
    final result = item.resultadoMes!;
    final objetivo = item.objetivoMes;
    final gaugeValue = _kpiGaugeValueMes(kpi, item);
    final centerLabel = isSuma
        ? '${item.progresoPct.toStringAsFixed(0)}%'
        : '${_fmt(result)}$unidad';

    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: gaugeValue,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: _fg.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(_fg),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isSuma ? 24 : 16,
                      fontWeight: FontWeight.w800,
                      color: _fg,
                      height: 1,
                    ),
                  ),
                  if (isSuma) ...[
                    const SizedBox(height: 3),
                    Text(
                      'del objetivo',
                      style: TextStyle(
                        fontSize: 10,
                        color: _fg.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _StatsRow(cells: [
          _StatCellData(
            label: isPromedio
                ? 'Promedio'
                : kpi.tipoAcumulacion == 'ultimo'
                ? 'Último valor'
                : 'Resultado',
            value: '${_fmt(result)}$unidad',
            color: _fg,
            large: true,
          ),
          _StatCellData(
            label: 'Objetivo mes${kpi.condicionSimbolo != null ? ' (${kpi.condicionSimbolo})' : ''}',
            value: '${_fmt(objetivo)}$unidad',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          _StatCellData(
            label: 'Progreso',
            value: '${item.progresoPct.toStringAsFixed(1)}%',
            color: _fg,
          ),
        ]),
      ],
    );
  }

  Widget _buildBetweenMonth(BuildContext context, String unidad) {
    final cs = Theme.of(context).colorScheme;
    final min = item.valorMin ?? kpi.valorMin ?? 0;
    final max = item.valorMax ?? kpi.valorMax ?? 0;
    final result = item.resultadoMes!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_fmt(result)}$unidad',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: _fg,
                      height: 1,
                    ),
                  ),
                  Text(
                    'Resultado del mes',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatCell(
                  label: 'Mínimo',
                  value: '${_fmt(min)}$unidad',
                  color: cs.onSurfaceVariant,
                  align: TextAlign.right,
                ),
                const SizedBox(height: 8),
                _StatCell(
                  label: 'Máximo',
                  value: '${_fmt(max)}$unidad',
                  color: cs.onSurfaceVariant,
                  align: TextAlign.right,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _MiniRangeBar(min: min, max: max, result: result, fg: _fg),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(min), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            Text('Rango objetivo', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            Text(_fmt(max), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

// ─── Banner de desviación mensual ─────────────────────────────────────────────

class _MonthDeviationBanner extends StatelessWidget {
  const _MonthDeviationBanner({
    required this.kpi,
    required this.item,
    required this.unidad,
  });

  final KpiSectorialItem kpi;
  final KpiSectorMesItem item;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    final info = _compute();
    if (info == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: info.color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(info.icon, size: 18, color: info.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: info.color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  info.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            info.badge,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }

  _DeviationInfo? _compute() {
    if (kpi.isBetween) {
      final min = item.valorMin ?? kpi.valorMin;
      final max = item.valorMax ?? kpi.valorMax;
      if (min == null || max == null || item.resultadoMes == null) return null;
      final result = item.resultadoMes!;
      if (result >= min && result <= max) {
        return _DeviationInfo(
          icon: Icons.check_circle_outline,
          color: Colors.green.shade700,
          title: 'Dentro del rango objetivo',
          subtitle: 'Rango ${_fmt(min)} – ${_fmt(max)}$unidad',
          badge: '✓',
        );
      } else if (result < min) {
        return _DeviationInfo(
          icon: Icons.arrow_downward,
          color: Colors.orange.shade700,
          title: 'Bajo el mínimo del rango',
          subtitle: 'Mínimo ${_fmt(min)}$unidad  ·  Resultado ${_fmt(result)}$unidad',
          badge: '-${_fmt(min - result)}$unidad',
        );
      } else {
        return _DeviationInfo(
          icon: Icons.arrow_upward,
          color: Colors.orange.shade700,
          title: 'Sobre el máximo del rango',
          subtitle: 'Máximo ${_fmt(max)}$unidad  ·  Resultado ${_fmt(item.resultadoMes!)}$unidad',
          badge: '+${_fmt(item.resultadoMes! - max)}$unidad',
        );
      }
    }

    // lineal
    final result = item.resultadoMes;
    if (result == null) return null;
    final objetivo = item.objetivoMes;
    if (objetivo == 0) {
      return _DeviationInfo(
        icon: Icons.info_outline,
        color: Colors.grey.shade600,
        title: 'Sin objetivo mensual',
        subtitle: 'No hay objetivo configurado para este mes',
        badge: '—',
      );
    }

    final delta = result - objetivo;
    // Semáforo del item mensual como fuente de verdad.
    final good = item.semaforo == 'verde';
    final hitTarget = item.progresoPct >= 100;

    if (kpi.tipoAcumulacion == 'suma') {
      return _DeviationInfo(
        icon: hitTarget ? Icons.check_circle_outline : Icons.pending_outlined,
        color: hitTarget ? Colors.green.shade700 : Colors.orange.shade700,
        title: hitTarget ? 'Objetivo del mes alcanzado' : 'Objetivo del mes no alcanzado',
        subtitle: 'Objetivo ${_fmt(objetivo)}$unidad  ·  Resultado ${_fmt(result)}$unidad',
        badge: '${item.progresoPct.toStringAsFixed(0)}%',
      );
    }

    return _DeviationInfo(
      icon: good ? Icons.check_circle_outline : Icons.warning_amber_outlined,
      color: good ? Colors.green.shade700 : Colors.orange.shade700,
      title: _deviationTitle(good, kpi.condicion),
      subtitle: 'Objetivo ${_fmt(objetivo)}$unidad  ·  Resultado ${_fmt(result)}$unidad',
      badge: _deviationBadge(good, delta, unidad, kpi.condicion),
    );
  }
}

// ─── Helpers de KPI ──────────────────────────────────────────────────────────

/// Calcula el valor de llenado del gauge (0.0 – 1.0).
///
/// `lte` (menor es mejor): usa el BUFFER restante = (obj − res) / obj.
///   0 resultado → 100% lleno (perfecto, sin errores).
///   Resultado = obj → 0% (llegó al límite).
///   Resultado > obj → 0% (superó el límite).
///
/// `gte` (mayor es mejor): usa PROGRESO = res / obj.
///   0 resultado → 0% (nada logrado).
///   Resultado = obj → 100% (alcanzó el objetivo).
///
/// `suma`: usa progresoPct del API (incluye factor tiempo).
double _kpiGaugeValue(KpiSectorialItem kpi) {
  if (kpi.isBetween) return 0;
  if (kpi.tipoAcumulacion == 'suma') {
    return (kpi.progresoPct / 100).clamp(0.0, 1.0);
  }
  final obj = kpi.objetivoAnual;
  final res = kpi.resultadoAcumulado;
  if (obj <= 0) return res == 0 ? 1.0 : 0.0;
  if (kpi.condicion == 'lte') {
    return ((obj - res) / obj).clamp(0.0, 1.0); // buffer restante
  }
  return (res / obj).clamp(0.0, 1.0); // progreso hacia objetivo
}

/// Ídem para datos mensuales.
double _kpiGaugeValueMes(KpiSectorialItem kpi, KpiSectorMesItem item) {
  if (kpi.isBetween) return 0;
  if (kpi.tipoAcumulacion == 'suma') {
    return (item.progresoPct / 100).clamp(0.0, 1.0);
  }
  final obj = item.objetivoMes;
  final res = item.resultadoMes ?? 0;
  if (obj <= 0) return res == 0 ? 1.0 : 0.0;
  if (kpi.condicion == 'lte') {
    return ((obj - res) / obj).clamp(0.0, 1.0);
  }
  return (res / obj).clamp(0.0, 1.0);
}

/// Títulos de desviación según la condición del KPI.
String _deviationTitle(bool good, String? condicion) {
  if (good) {
    return switch (condicion) {
      'lte' => 'Dentro del límite',
      'gte' => 'Sobre el objetivo',
      'eq'  => 'En el objetivo',
      _     => 'Dentro del objetivo',
    };
  } else {
    return switch (condicion) {
      'lte' => 'Supera el límite',
      'gte' => 'Bajo el objetivo',
      'eq'  => 'Fuera del objetivo',
      _     => 'Fuera del objetivo',
    };
  }
}

/// Badge del banner de desviación: texto claro sin signos ambiguos.
///
/// Para `lte` bien (bajo el límite): muestra "X de margen"
/// Para `lte` mal (sobre el límite): muestra "+X sobre el límite"
/// Para `gte` bien (sobre el objetivo): muestra "+X"
/// Para `gte` mal (bajo el objetivo): muestra "−X"
String _deviationBadge(
  bool good,
  double delta,
  String unidad,
  String? condicion,
) {
  final abs = delta.abs();
  final fmt = _fmt(abs) + unidad;
  if (condicion == 'lte') {
    return good ? '$fmt de margen' : '+$fmt sobre el límite';
  }
  // gte / eq / default
  return '${delta >= 0 ? '+' : '−'}$fmt';
}

/// Label de la celda "Diferencia" en el panel de stats.
String _diffLabel(bool good, String? condicion) {
  return switch (condicion) {
    'lte' => good ? 'Margen' : 'Exceso',
    'gte' => good ? 'Excedente' : 'Déficit',
    _     => 'Diferencia',
  };
}

/// Valor de la celda "Diferencia": siempre positivo con contexto claro.
String _diffValue(bool good, double delta, String unidad, String? condicion) {
  final abs = _fmt(delta.abs()) + unidad;
  if (condicion == 'lte') {
    // Bajo el límite = bueno, sobre el límite = malo
    return good ? abs : '+${_fmt(delta)}$unidad';
  }
  return '${delta >= 0 ? '+' : ''}${_fmt(delta)}$unidad';
}

// ─── Snapshot de hoy ─────────────────────────────────────────────────────────

class _HoySnapshotCard extends StatelessWidget {
  const _HoySnapshotCard({
    required this.diaHoy,
    required this.selectedKpiId,
  });

  final KpisSectorDiaResponse diaHoy;
  final int selectedKpiId;

  @override
  Widget build(BuildContext context) {
    final kpiDia = diaHoy.kpis
        .where((k) => k.kpiId == selectedKpiId)
        .firstOrNull;
    if (kpiDia == null || !kpiDia.tieneResultado) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final fg = _semaforoFg(kpiDia.semaforoDia);
    final bg = _semaforoBg(kpiDia.semaforoDia);
    final unidad = kpiDia.unidad != null ? ' ${kpiDia.unidad}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: bg.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: fg.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.today_outlined, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              'Hoy',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: fg,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _shortDate(diaHoy.fecha),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            if (kpiDia.resultadoDia != null) ...[
              Text(
                '${_fmt(kpiDia.resultadoDia!)}$unidad',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: fg,
                ),
              ),
              const SizedBox(width: 8),
            ],
            _SemaforoChip(semaforo: kpiDia.semaforoDia, fg: fg, bg: bg),
          ],
        ),
      ),
    );
  }
}

// ─── Tarjetas de KPI para el día (calendario) ────────────────────────────────

class _KpiDiaCard extends StatelessWidget {
  const _KpiDiaCard({required this.kpi});

  final KpisSectorDiaItem kpi;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = kpi.tieneResultado ? kpi.semaforoDia : 'gris';
    final fg = _semaforoFg(sem);
    final bg = _semaforoBg(sem);
    final unidad = kpi.unidad != null ? ' ${kpi.unidad}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: bg.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: fg.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kpi.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        kpi.codigo,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (kpi.tieneResultado)
                  _SemaforoChip(semaforo: sem, fg: fg, bg: bg)
                else
                  Text(
                    'Sin dato',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            if (kpi.tieneResultado) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _DiaStatCol(
                    label: 'Resultado día',
                    value: kpi.resultadoDia != null
                        ? '${_fmt(kpi.resultadoDia!)}$unidad'
                        : '—',
                    valueColor: fg,
                  ),
                  if (kpi.objetivoDia != null)
                    _DiaStatCol(
                      label: 'Obj. día',
                      value: '${_fmt(kpi.objetivoDia!)}$unidad',
                    ),
                  if (kpi.resultadoAcumuladoAFecha != null)
                    _DiaStatCol(
                      label: 'Acumulado',
                      value:
                          '${_fmt(kpi.resultadoAcumuladoAFecha!)}$unidad',
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

class _DiaStatCol extends StatelessWidget {
  const _DiaStatCol({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Serie diaria (sparkline de acumulado) ────────────────────────────────────

class _DailySparklineSection extends StatelessWidget {
  const _DailySparklineSection({
    required this.points,
    required this.kpi,
  });

  final List<KpiSectorPuntoDiario> points;
  final KpiSectorialItem kpi;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _semaforoFg(kpi.semaforo);
    final unidad = kpi.unidad != null ? ' ${kpi.unidad}' : '';
    final valores = points.map((p) => p.resultadoAcumuladoAFecha).toList();
    final objetivos = kpi.isBetween
        ? <double?>[]
        : points.map((p) => p.objetivoAcumuladoAFecha).toList();

    final first = points.first.fecha;
    final last = points.last.fecha;
    final lastVal = points.last.resultadoAcumuladoAFecha;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Acumulado diario',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${points.length} días con dato)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          width: double.infinity,
          child: CustomPaint(
            painter: _DailyAccumPainter(
              valores: valores,
              objetivos: objetivos,
              color: fg,
              objetivoColor: cs.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _compactDate(first),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            if (lastVal != null)
              Text(
                '${_fmt(lastVal)}$unidad',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: fg,
                ),
              ),
            Text(
              _compactDate(last),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  String _compactDate(String iso) {
    if (iso.length >= 10) return iso.substring(5, 10).replaceAll('-', '/');
    return iso;
  }
}

class _DailyAccumPainter extends CustomPainter {
  const _DailyAccumPainter({
    required this.valores,
    required this.objetivos,
    required this.color,
    required this.objetivoColor,
  });

  final List<double?> valores;
  final List<double?> objetivos;
  final Color color;
  final Color objetivoColor;

  @override
  void paint(Canvas canvas, Size size) {
    final validValues = valores.whereType<double>().toList();
    if (validValues.isEmpty) return;

    final allValues = [
      ...validValues,
      ...objetivos.whereType<double>(),
    ];
    final minValue = allValues.reduce(math.min);
    final maxValue = allValues.reduce(math.max);
    final range = maxValue - minValue;

    double toY(double v) {
      if (range == 0) return size.height / 2;
      final normalized = (v - minValue) / range;
      return size.height - (normalized * (size.height - 8)) - 4;
    }

    // Línea de objetivo (gris, más fina)
    if (objetivos.length > 1) {
      final objPts = <Offset>[];
      for (var i = 0; i < objetivos.length; i++) {
        final v = objetivos[i];
        if (v == null) continue;
        final x = size.width * i / (objetivos.length - 1);
        objPts.add(Offset(x, toY(v)));
      }
      if (objPts.length > 1) {
        final path = Path()..moveTo(objPts.first.dx, objPts.first.dy);
        for (final p in objPts.skip(1)) { path.lineTo(p.dx, p.dy); }
        canvas.drawPath(
          path,
          Paint()
            ..color = objetivoColor
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // Línea de valor acumulado
    final valPts = <Offset>[];
    for (var i = 0; i < valores.length; i++) {
      final v = valores[i];
      if (v == null) continue;
      final x = valores.length == 1
          ? size.width / 2
          : size.width * i / (valores.length - 1);
      valPts.add(Offset(x, toY(v)));
    }
    if (valPts.length > 1) {
      final path = Path()..moveTo(valPts.first.dx, valPts.first.dy);
      for (final p in valPts.skip(1)) { path.lineTo(p.dx, p.dy); }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Puntos
    final dotPaint = Paint()..color = color;
    for (final p in valPts) {
      canvas.drawCircle(p, 2.5, dotPaint);
    }
    // Último punto destacado
    if (valPts.isNotEmpty) {
      canvas.drawCircle(valPts.last, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _DailyAccumPainter old) =>
      old.valores != valores || old.color != color;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _semaforoFg(String semaforo) {
  return switch (semaforo) {
    'verde' => const Color(0xFF1B5E20),
    'amarillo' => const Color(0xFFE65100),
    'rojo' => const Color(0xFFB71C1C),
    _ => const Color(0xFF616161),
  };
}

Color _semaforoBg(String semaforo) {
  return switch (semaforo) {
    'verde' => const Color(0xFFE8F5E9),
    'amarillo' => const Color(0xFFFFF3E0),
    'rojo' => const Color(0xFFFFEBEE),
    _ => const Color(0xFFF5F5F5),
  };
}

IconData _semaforoIcon(String semaforo) {
  return switch (semaforo) {
    'verde' => Icons.check_circle_outline,
    'amarillo' => Icons.warning_amber_outlined,
    'rojo' => Icons.cancel_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

String _statusLabel(String semaforo) {
  if (semaforo.isEmpty) return 'Gris';
  return semaforo[0].toUpperCase() + semaforo.substring(1);
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

String _fmtNullable(double? v) {
  if (v == null) return 'Sin dato';
  return _fmt(v);
}

String _shortDate(String value) {
  if (value.length >= 10) return value.substring(0, 10);
  return value;
}

String _monthLabel(KpisSectorMesCerrado mes) => mes.mesNombre ?? mes.periodo;

String _shortMonthLabel(KpisSectorMesCerrado mes) {
  final label = _monthLabel(mes);
  if (label.length <= 3) return label;
  return label.substring(0, 3);
}
