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
  final TextEditingController _desdeController = TextEditingController();
  final TextEditingController _hastaController = TextEditingController();

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
  Map<DateTime, _DayAttendanceStatus> _calendarStatuses = const {};

  @override
  void initState() {
    super.initState();
    final today = _todayDate();
    _calendarMonth = DateTime(today.year, today.month, 1);
    _loadPage(page: 1);
    _loadCalendarMonth();
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

  String _fmtApiDate(DateTime date) {
    return DateFormatter.formatApiDate(date);
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
      final data = await widget.apiClient.getAsistencias(
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
    await _loadCalendarMonth();
  }

  void _applyFilters() {
    _loadPage(page: 1);
  }

  void _clearFilters() {
    _desdeController.clear();
    _hastaController.clear();
    _loadPage(page: 1);
  }

  Future<void> _loadCalendarMonth() async {
    if (_calendarLoading) {
      return;
    }
    final requestedMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      1,
    );
    final monthStart = requestedMonth;
    final monthEnd = DateTime(requestedMonth.year, requestedMonth.month + 1, 0);

    setState(() {
      _calendarLoading = true;
    });

    try {
      final result = await widget.apiClient.getAsistencias(
        token: widget.token,
        page: 1,
        per: 400,
        desde: _fmtApiDate(monthStart),
        hasta: _fmtApiDate(monthEnd),
      );
      if (!mounted) {
        return;
      }
      if (_calendarMonth.year != requestedMonth.year ||
          _calendarMonth.month != requestedMonth.month) {
        return;
      }
      setState(() {
        _calendarStatuses = _buildCalendarStatuses(result.items);
        _calendarError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _calendarError = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _calendarError = 'No se pudo cargar el calendario de asistencias.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _calendarLoading = false;
        });
      }
    }
  }

  Map<DateTime, _DayAttendanceStatus> _buildCalendarStatuses(
    List<AsistenciaItem> items,
  ) {
    final statuses = <DateTime, _DayAttendanceStatus>{};
    for (final item in items) {
      final parsedDate = DateFormatter.parseFlexibleDate(item.fecha ?? '');
      if (parsedDate == null) {
        continue;
      }
      final next = _statusFromEstado(item.estado);
      final current = statuses[parsedDate];
      statuses[parsedDate] = _mergeStatus(current, next);
    }
    return statuses;
  }

  _DayAttendanceStatus _statusFromEstado(String? estado) {
    final normalized = (estado ?? '').trim().toLowerCase();
    if (normalized == 'ok') {
      return _DayAttendanceStatus.ok;
    }
    return _DayAttendanceStatus.issue;
  }

  _DayAttendanceStatus _mergeStatus(
    _DayAttendanceStatus? current,
    _DayAttendanceStatus next,
  ) {
    if (current == _DayAttendanceStatus.issue ||
        next == _DayAttendanceStatus.issue) {
      return _DayAttendanceStatus.issue;
    }
    return _DayAttendanceStatus.ok;
  }

  String _monthLabel(DateTime month) {
    const names = <String>[
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${names[month.month - 1]} ${month.year}';
  }

  void _changeCalendarMonth(int delta) {
    final today = _todayDate();
    final currentMonth = DateTime(today.year, today.month, 1);
    final nextMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + delta,
    );
    if (nextMonth.isAfter(currentMonth)) {
      return;
    }
    setState(() {
      _calendarMonth = DateTime(nextMonth.year, nextMonth.month, 1);
      _calendarStatuses = const {};
      _calendarError = null;
    });
    _loadCalendarMonth();
  }

  Widget _buildCalendarCard() {
    final month = _calendarMonth;
    final today = _todayDate();
    final monthStart = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = monthStart.weekday - 1;
    final totalCells = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;
    final canGoNext = !DateTime(
      month.year,
      month.month + 1,
      1,
    ).isAfter(DateTime(today.year, today.month, 1));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _calendarLoading
                      ? null
                      : () => _changeCalendarMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Mes anterior',
                ),
                Expanded(
                  child: Text(
                    _monthLabel(month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: (_calendarLoading || !canGoNext)
                      ? null
                      : () => _changeCalendarMonth(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Mes siguiente',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: const [
                _WeekdayHeader(label: 'L'),
                _WeekdayHeader(label: 'M'),
                _WeekdayHeader(label: 'X'),
                _WeekdayHeader(label: 'J'),
                _WeekdayHeader(label: 'V'),
                _WeekdayHeader(label: 'S'),
                _WeekdayHeader(label: 'D'),
              ],
            ),
            const SizedBox(height: 6),
            if (_calendarLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final dayNumber = index - leadingBlanks + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime(month.year, month.month, dayNumber);
                  final status = _calendarStatuses[date];
                  final isFuture = date.isAfter(today);
                  final colors = _dayColors(status: status, isFuture: isFuture);
                  return Container(
                    decoration: BoxDecoration(
                      color: colors.$1,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.$2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.$3,
                      ),
                    ),
                  );
                },
              ),
            if (_calendarError != null) ...[
              const SizedBox(height: 8),
              Text(
                _calendarError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 10),
            const Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _LegendItem(color: Color(0xFFDDF5E0), label: 'OK'),
                _LegendItem(color: Color(0xFFFADCDD), label: 'Con problema'),
                _LegendItem(color: Color(0xFFF1F3F4), label: 'Sin registro'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, Color) _dayColors({
    required _DayAttendanceStatus? status,
    required bool isFuture,
  }) {
    if (isFuture) {
      return (
        const Color(0xFFF6F7F8),
        const Color(0xFFE5E7EB),
        const Color(0xFF9AA0A6),
      );
    }
    if (status == _DayAttendanceStatus.ok) {
      return (
        const Color(0xFFDDF5E0),
        const Color(0xFF81C995),
        const Color(0xFF1B5E20),
      );
    }
    if (status == _DayAttendanceStatus.issue) {
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
                          _buildCalendarCard(),
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
                                child: Text('No hay asistencias para mostrar.'),
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

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF5F6368),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF9AA0A6)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

enum _DayAttendanceStatus { ok, issue }
