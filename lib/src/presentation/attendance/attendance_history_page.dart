import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import '../../core/utils/date_formatter.dart';

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
  late DateTime _calendarMonth;
  bool _loading = true;
  bool _loadingPage = false;
  bool _calendarLoading = false;
  String? _error;
  String? _calendarError;

  int _page = 1;
  int _perPage = 20;
  int _total = 0;
  List<AsistenciaItem> _items = const [];
  Map<DateTime, _DayStatus> _calendarStatuses = const {};

  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    final today = _today();
    _calendarMonth = DateTime(today.year, today.month, 1);
    _loadPage(page: 1);
    _loadCalendarMonth();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate({required bool isDesde}) async {
    final today = _today();
    final current = (isDesde ? _desde : _hasta) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: isDesde ? 'Desde' : 'Hasta',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isDesde) {
        _desde = picked;
        if (_hasta != null && _hasta!.isBefore(picked)) _hasta = picked;
      } else {
        _hasta = picked;
        if (_desde != null && _desde!.isAfter(picked)) _desde = picked;
      }
    });
  }

  Future<void> _loadPage({required int page}) async {
    if (_loadingPage) return;
    setState(() {
      _loadingPage = true;
      if (_items.isEmpty) _loading = true;
    });
    try {
      final data = await widget.apiClient.getAsistencias(
        token: widget.token,
        page: page,
        per: _perPage,
        desde: _desde != null ? DateFormatter.formatApiDate(_desde!) : null,
        hasta: _hasta != null ? DateFormatter.formatApiDate(_hasta!) : null,
      );
      if (!mounted) return;
      setState(() {
        _items = data.items;
        _page = data.page;
        _perPage = data.perPage;
        _total = data.total;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado al consultar asistencias.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingPage = false;
        });
      }
    }
  }

  Future<void> _loadCalendarMonth() async {
    if (_calendarLoading) return;
    final requestedMonth = _calendarMonth;
    final monthStart = requestedMonth;
    final monthEnd = DateTime(
      requestedMonth.year,
      requestedMonth.month + 1,
      0,
    );
    setState(() => _calendarLoading = true);
    try {
      final result = await widget.apiClient.getAsistencias(
        token: widget.token,
        page: 1,
        per: 400,
        desde: DateFormatter.formatApiDate(monthStart),
        hasta: DateFormatter.formatApiDate(monthEnd),
      );
      if (!mounted) return;
      if (_calendarMonth != requestedMonth) return;
      setState(() {
        _calendarStatuses = _buildStatuses(result.items);
        _calendarError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _calendarError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _calendarError =
                'No se pudo cargar el calendario.',
      );
    } finally {
      if (mounted) setState(() => _calendarLoading = false);
    }
  }

  Map<DateTime, _DayStatus> _buildStatuses(List<AsistenciaItem> items) {
    final map = <DateTime, _DayStatus>{};
    for (final item in items) {
      final date = DateFormatter.parseFlexibleDate(item.fecha ?? '');
      if (date == null) continue;
      final next = (item.estado ?? '').trim().toLowerCase() == 'ok'
          ? _DayStatus.ok
          : _DayStatus.issue;
      final current = map[date];
      map[date] =
          (current == _DayStatus.issue || next == _DayStatus.issue)
              ? _DayStatus.issue
              : _DayStatus.ok;
    }
    return map;
  }

  void _changeCalendarMonth(int delta) {
    final today = _today();
    final next = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + delta,
    );
    if (next.isAfter(DateTime(today.year, today.month, 1))) return;
    setState(() {
      _calendarMonth = DateTime(next.year, next.month, 1);
      _calendarStatuses = const {};
      _calendarError = null;
    });
    _loadCalendarMonth();
  }

  void _showDetail(AsistenciaItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AsistenciaDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPrev = _page > 1;
    final hasNext = (_page * _perPage) < _total;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de asistencias'),
        bottom: _loadingPage
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: _loading
          ? const _HistorySkeleton()
          : RefreshIndicator(
              onRefresh: () async {
                await _loadPage(page: _page);
                await _loadCalendarMonth();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  // ── Filters ────────────────────────────────────────
                  _DateRangeFilterBar(
                    desde: _desde,
                    hasta: _hasta,
                    loading: _loadingPage,
                    onPickDesde: () => _pickDate(isDesde: true),
                    onPickHasta: () => _pickDate(isDesde: false),
                    onApply: () => _loadPage(page: 1),
                    onClear: () {
                      setState(() {
                        _desde = null;
                        _hasta = null;
                      });
                      _loadPage(page: 1);
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── Calendar ───────────────────────────────────────
                  _CalendarCard(
                    month: _calendarMonth,
                    today: _today(),
                    statuses: _calendarStatuses,
                    loading: _calendarLoading,
                    error: _calendarError,
                    onPrevMonth: _calendarLoading
                        ? null
                        : () => _changeCalendarMonth(-1),
                    onNextMonth: _calendarLoading
                        ? null
                        : () => _changeCalendarMonth(1),
                  ),
                  const SizedBox(height: 10),

                  // ── Summary ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      '$_total asistencia${_total == 1 ? '' : 's'} — página $_page',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── Error ──────────────────────────────────────────
                  if (_error != null) ...[
                    _ErrorBanner(
                      message: _error!,
                      onRetry: () => _loadPage(page: _page),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── Items ──────────────────────────────────────────
                  if (_items.isEmpty)
                    _EmptyCard(
                      hasFilters: _desde != null || _hasta != null,
                    ),
                  ...(_items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => _showDetail(item),
                        child: _AsistenciaCard(item: item),
                      ),
                    ),
                  )),

                  // ── Pagination ─────────────────────────────────────
                  if (_total > _perPage) ...[
                    const SizedBox(height: 4),
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
                        const SizedBox(width: 10),
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// ─── Date range filter bar ─────────────────────────────────────────────────────

class _DateRangeFilterBar extends StatelessWidget {
  const _DateRangeFilterBar({
    required this.desde,
    required this.hasta,
    required this.loading,
    required this.onPickDesde,
    required this.onPickHasta,
    required this.onApply,
    required this.onClear,
  });

  final DateTime? desde;
  final DateTime? hasta;
  final bool loading;
  final VoidCallback onPickDesde;
  final VoidCallback onPickHasta;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFilter = desde != null || hasta != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filtrar por fecha',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (hasFilter) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: loading ? null : onClear,
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Limpiar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Desde',
                    value: desde,
                    onTap: loading ? null : onPickDesde,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateButton(
                    label: 'Hasta',
                    value: hasta,
                    onTap: loading ? null : onPickHasta,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: loading ? null : onApply,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Buscar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_month, size: 16),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
        child: Text(
          value != null ? DateFormatter.formatDisplayDate(value!) : '–',
          style: TextStyle(
            color: value != null ? cs.onSurface : cs.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Calendar card ─────────────────────────────────────────────────────────────

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.today,
    required this.statuses,
    required this.loading,
    required this.error,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final DateTime today;
  final Map<DateTime, _DayStatus> statuses;
  final bool loading;
  final String? error;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  bool get _canGoNext {
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final thisMonth = DateTime(today.year, today.month, 1);
    return !nextMonth.isAfter(thisMonth);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final totalCells = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header nav
            Row(
              children: [
                IconButton(
                  onPressed: onPrevMonth,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Mes anterior',
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[month.month - 1]} ${month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: (!_canGoNext || loading) ? null : onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Mes siguiente',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Weekday headers
            const Row(
              children: [
                _WeekLabel('L'), _WeekLabel('M'), _WeekLabel('X'),
                _WeekLabel('J'), _WeekLabel('V'), _WeekLabel('S'),
                _WeekLabel('D'),
              ],
            ),
            const SizedBox(height: 6),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, i) {
                  final dayNum = i - leadingBlanks + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final date =
                      DateTime(month.year, month.month, dayNum);
                  final status = statuses[date];
                  final isFuture = date.isAfter(today);
                  final colors = _dayColors(status, isFuture);
                  return Container(
                    decoration: BoxDecoration(
                      color: colors.$1,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.$2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.$3,
                      ),
                    ),
                  );
                },
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _LegendDot(color: Color(0xFF81C995), label: 'OK'),
                _LegendDot(color: Color(0xFFE57373), label: 'Con problema'),
                _LegendDot(color: Color(0xFFDADCE0), label: 'Sin registro'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, Color) _dayColors(_DayStatus? status, bool isFuture) {
    if (isFuture) {
      return (
        const Color(0xFFF6F7F8),
        const Color(0xFFE5E7EB),
        const Color(0xFF9AA0A6),
      );
    }
    if (status == _DayStatus.ok) {
      return (
        const Color(0xFFDDF5E0),
        const Color(0xFF81C995),
        const Color(0xFF1B5E20),
      );
    }
    if (status == _DayStatus.issue) {
      return (
        const Color(0xFFFADCDD),
        const Color(0xFFE57373),
        const Color(0xFFB71C1C),
      );
    }
    return (
      const Color(0xFFF1F3F4),
      const Color(0xFFDADCE0),
      const Color(0xFF5F6368),
    );
  }
}

class _WeekLabel extends StatelessWidget {
  const _WeekLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF5F6368),
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

// ─── Asistencia card ───────────────────────────────────────────────────────────

class _AsistenciaCard extends StatelessWidget {
  const _AsistenciaCard({required this.item});

  final AsistenciaItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOk = (item.estado ?? '').trim().toLowerCase() == 'ok';
    final borderColor =
        isOk ? Colors.green.shade700 : cs.error;

    final hasEntrada = (item.horaEntrada ?? '').isNotEmpty;
    final hasSalida = (item.horaSalida ?? '').isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: borderColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOk
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_outlined,
                          color: borderColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormatter.formatApiDateForDisplay(item.fecha),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: borderColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isOk ? 'OK' : _capitalize(item.estado ?? '-'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: borderColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (hasEntrada) ...[
                          Icon(
                            Icons.login_outlined,
                            size: 14,
                            color: const Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.horaEntrada!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1565C0),
                                ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (hasSalida) ...[
                          Icon(
                            Icons.logout_outlined,
                            size: 14,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.horaSalida!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade800,
                                ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (!hasEntrada && !hasSalida)
                          Text(
                            'Sin horarios registrados',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: cs.outlineVariant,
                        ),
                      ],
                    ),
                    if ((item.observaciones ?? '').isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.observaciones!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Asistencia detail sheet ───────────────────────────────────────────────────

class _AsistenciaDetailSheet extends StatelessWidget {
  const _AsistenciaDetailSheet({required this.item});

  final AsistenciaItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOk = (item.estado ?? '').trim().toLowerCase() == 'ok';
    final color = isOk ? Colors.green.shade700 : cs.error;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOk
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_outlined,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormatter.formatApiDateForDisplay(
                                item.fecha,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isOk
                                    ? 'OK'
                                    : _capitalize(item.estado ?? '-'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Times row
                  Row(
                    children: [
                      _TimeBlock(
                        icon: Icons.login_outlined,
                        label: 'Entrada',
                        time: item.horaEntrada,
                        color: const Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 12),
                      _TimeBlock(
                        icon: Icons.logout_outlined,
                        label: 'Salida',
                        time: item.horaSalida,
                        color: Colors.orange.shade800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Detail cells
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if ((item.metodoEntrada ?? '').isNotEmpty)
                        _DetailCell(
                          icon: Icons.touch_app_outlined,
                          label: 'Método entrada',
                          value: _capitalize(item.metodoEntrada!),
                        ),
                      if ((item.metodoSalida ?? '').isNotEmpty)
                        _DetailCell(
                          icon: Icons.touch_app_outlined,
                          label: 'Método salida',
                          value: _capitalize(item.metodoSalida!),
                        ),
                      if (item.gpsDistanciaEntradaM != null)
                        _DetailCell(
                          icon: Icons.my_location_outlined,
                          label: 'GPS entrada',
                          value:
                              '${item.gpsDistanciaEntradaM!.toStringAsFixed(1)} / '
                              '${(item.gpsToleranciaEntradaM ?? 0).toStringAsFixed(0)} m',
                        ),
                      if (item.gpsDistanciaSalidaM != null)
                        _DetailCell(
                          icon: Icons.my_location_outlined,
                          label: 'GPS salida',
                          value:
                              '${item.gpsDistanciaSalidaM!.toStringAsFixed(1)} / '
                              '${(item.gpsToleranciaSalidaM ?? 0).toStringAsFixed(0)} m',
                        ),
                    ],
                  ),

                  if ((item.observaciones ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Observaciones',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        item.observaciones!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String? time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasTime = (time ?? '').isNotEmpty;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasTime
              ? color.withValues(alpha: 0.08)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasTime
                ? color.withValues(alpha: 0.3)
                : cs.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: hasTime ? color : cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: hasTime ? color : cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasTime ? time! : '–',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: hasTime ? color : cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 56,
              color: cs.outlineVariant,
            ),
            const SizedBox(height: 14),
            Text(
              hasFilters
                  ? 'Sin asistencias en el rango seleccionado'
                  : 'Sin asistencias registradas',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Reintentar',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton loader ──────────────────────────────────────────────────────────

class _HistorySkeleton extends StatefulWidget {
  const _HistorySkeleton();

  @override
  State<_HistorySkeleton> createState() => _HistorySkeletonState();
}

class _HistorySkeletonState extends State<_HistorySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurface.withValues(alpha: 0.08);
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Filtro placeholder
          _SkeletonBox(color: base, height: 72, radius: 12, opacity: _fade.value),
          const SizedBox(height: 10),
          // Calendario placeholder
          _SkeletonBox(color: base, height: 200, radius: 12, opacity: _fade.value),
          const SizedBox(height: 10),
          // Cards de items
          for (var i = 0; i < 6; i++) ...[
            _SkeletonBox(color: base, height: 72, radius: 12, opacity: _fade.value),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.color,
    required this.height,
    required this.radius,
    required this.opacity,
  });

  final Color color;
  final double height;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

enum _DayStatus { ok, issue }
