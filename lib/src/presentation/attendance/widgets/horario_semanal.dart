import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/mobile_api_client.dart';

class HorarioSemanal extends StatefulWidget {
  const HorarioSemanal({
    super.key,
    required this.apiClient,
    required this.token,
    this.initialDate,
  });
  final MobileApiClient apiClient;
  final String token;
  final DateTime? initialDate;

  @override
  State<HorarioSemanal> createState() => _HorarioSemanalState();
}

class _HorarioSemanalState extends State<HorarioSemanal> {
  late DateTime _monday;
  bool _loading = true;
  List<_DayResult> _days = [];
  int _generation = 0;
  static const _names = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    final date = widget.initialDate ?? DateTime.now();
    _monday = DateTime(date.year, date.month, date.day - date.weekday + 1);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant HorarioSemanal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token ||
        oldWidget.apiClient != widget.apiClient) {
      unawaited(_load());
    }
  }

  DateTime _date(int offset) =>
      DateTime(_monday.year, _monday.month, _monday.day + offset);
  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _loading = true);
    final results = await Future.wait([
      for (var i = 0; i < 7; i++) _fetch(_date(i)),
    ]);
    if (!mounted || generation != _generation) return;
    setState(() {
      _days = results;
      _loading = false;
    });
  }

  Future<_DayResult> _fetch(DateTime date) async {
    try {
      return _DayResult(
        date,
        data: await widget.apiClient.getHorarioEsperado(
          token: widget.token,
          fecha: _iso(date),
        ),
      );
    } on ApiException catch (e) {
      return _DayResult(date, error: e.message);
    } catch (_) {
      return _DayResult(date, error: 'No se pudo consultar este día.');
    }
  }

  void _move(int days) {
    _monday = _date(days);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Entradas y salidas',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Horario previsto para cada fecha, con los cambios y excepciones que correspondan.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              tooltip: 'Semana anterior',
              onPressed: () => _move(-7),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_short(_monday)} – ${_short(_date(6))} · ${_date(6).year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Semana siguiente',
              onPressed: () => _move(7),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          for (final day in _days) ...[
            const SizedBox(height: 8),
            Card(
              color: DateUtils.isSameDay(day.date, DateTime.now())
                  ? cs.primaryContainer
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final title = Text(
                      '${_names[day.date.weekday - 1]} ${_short(day.date)}${DateUtils.isSameDay(day.date, DateTime.now()) ? ' · Hoy' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    );
                    final content = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (day.error != null)
                          Text(day.error!, style: TextStyle(color: cs.error))
                        else if (day.data == null || day.data!.bloques.isEmpty)
                          const Text('Sin horario previsto para esta fecha')
                        else
                          for (final block in day.data!.bloques)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Entrada ${_time(block.entrada)}',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward, size: 16),
                                  Text(
                                    'Salida ${_time(block.salida)}',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        if (day.data?.tieneExcepcion == true) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Horario con excepción',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    );
                    if (box.maxWidth < 580 ||
                        MediaQuery.textScalerOf(context).scale(16) >= 24) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [title, const SizedBox(height: 8), content],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 180, child: title),
                        const SizedBox(width: 16),
                        Expanded(child: content),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
          if (_days.any((day) => day.error != null))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar horarios'),
              ),
            ),
        ],
      ],
    );
  }

  String _time(String value) {
    final match = RegExp(r'^(\d{2}:\d{2})(?::\d{2})?$').firstMatch(value);
    return match?.group(1) ?? (value.isEmpty ? 'Sin informar' : value);
  }
}

class _DayResult {
  const _DayResult(this.date, {this.data, this.error});
  final DateTime date;
  final HorarioEsperadoResponse? data;
  final String? error;
}
