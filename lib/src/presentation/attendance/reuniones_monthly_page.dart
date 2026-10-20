import 'package:flutter/material.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/network/reuniones_models.dart';
import '../widgets/app_card.dart';
import '../theme/app_layout.dart';

class ReunionesMonthlyPage extends StatefulWidget {
  const ReunionesMonthlyPage({
    super.key,
    required this.api,
    required this.token,
    required this.onOpen,
  });
  final MobileApiClient api;
  final String token;
  final ValueChanged<int> onOpen;
  @override
  State<ReunionesMonthlyPage> createState() => _ReunionesMonthlyPageState();
}

class _ReunionesMonthlyPageState extends State<ReunionesMonthlyPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic> calendar = {}, stats = {}, evolution = {};
  bool loading = true;
  String? error, evolutionError;
  int generation = 0, months = 6;
  String? day;
  String keyMonth(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = ++generation;
    setState(() {
      loading = true;
      error = null;
      evolutionError = null;
    });
    try {
      final result = await Future.wait([
        widget.api.getReuniones(
          token: widget.token,
          path: '/calendario',
          query: {'mes': keyMonth(month)},
        ),
        widget.api.getReuniones(
          token: widget.token,
          path: '/estadisticas',
          query: {'mes': keyMonth(month)},
        ),
      ]);
      if (!mounted || id != generation) return;
      setState(() {
        calendar = result[0];
        stats = result[1];
      });
    } catch (e) {
      if (mounted && id == generation) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No se pudo cargar el mes.',
        );
      }
    }
    try {
      final result = await widget.api.getReuniones(
        token: widget.token,
        path: '/estadisticas/evolucion',
        query: {
          'desde_mes': keyMonth(DateTime(month.year, month.month - months + 1)),
          'hasta_mes': keyMonth(month),
        },
      );
      if (mounted && id == generation) setState(() => evolution = result);
    } catch (e) {
      if (mounted && id == generation) {
        setState(() {
          evolution = {};
          evolutionError = 'No se pudo cargar la evolución.';
        });
      }
    }
    if (mounted && id == generation) setState(() => loading = false);
  }

  Widget card(List<Widget> children) => AppCard(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget metric(String label, dynamic value) => Column(
    children: [
      Text(
        value == null ? 'Sin datos' : '$value',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      Text(label, textAlign: TextAlign.center),
    ],
  );
  Widget bar(String label, dynamic raw, num max, {bool hours = false}) {
    final value = raw is num ? raw : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$label: ${value == null
                ? 'Sin datos'
                : hours
                ? '${(value / 60).toStringAsFixed(1)} h'
                : '$value'}',
            textAlign: TextAlign.center,
          ),
          if (value != null)
            LinearProgressIndicator(
              value: max > 0 ? (value / max).clamp(0, 1).toDouble() : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = stats['totales'] as Map? ?? {};
    final occurrences = reunionMaps(calendar['items']);
    final days = occurrences.map((e) => '${e['fecha']}').toSet();
    final definitions = stats['definiciones'] as Map? ?? {};
    final maxMinutes = [
      totals['minutos_planificados'],
      totals['minutos_realizados'],
      totals['minutos_asistidos'],
    ].whereType<num>().fold<num>(0, (a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario y resumen mensual')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Mes anterior',
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  month = DateTime(month.year, month.month - 1);
                                  day = null;
                                });
                                load();
                              },
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Flexible(
                        child: Text(
                          keyMonth(month),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mes siguiente',
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  month = DateTime(month.year, month.month + 1);
                                  day = null;
                                });
                                load();
                              },
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else if (error != null)
                    card([
                      Text(error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: load,
                        child: const Text('Reintentar'),
                      ),
                    ])
                  else ...[
                    card([
                      const Text(
                        'Calendario mensual',
                        textAlign: TextAlign.center,
                      ),
                      LayoutBuilder(
                        builder: (context, c) {
                          final start =
                              DateTime(month.year, month.month, 1).weekday - 1;
                          final count = DateTime(
                            month.year,
                            month.month + 1,
                            0,
                          ).day;
                          return Wrap(
                            children: [
                              for (final label in [
                                'L',
                                'M',
                                'M',
                                'J',
                                'V',
                                'S',
                                'D',
                              ])
                                SizedBox(
                                  width: c.maxWidth / 7,
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              for (var i = 0; i < start; i++)
                                SizedBox(width: c.maxWidth / 7, height: 48),
                              for (var d = 1; d <= count; d++)
                                SizedBox(
                                  width: c.maxWidth / 7,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 48),
                                      backgroundColor:
                                          day ==
                                              '${keyMonth(month)}-${d.toString().padLeft(2, '0')}'
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.secondaryContainer
                                          : null,
                                    ),
                                    onPressed: () => setState(
                                      () => day =
                                          '${keyMonth(month)}-${d.toString().padLeft(2, '0')}',
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$d',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (days.contains(
                                          '${keyMonth(month)}-${d.toString().padLeft(2, '0')}',
                                        ))
                                          const Icon(Icons.circle, size: 5),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      if (day != null)
                        TextButton(
                          onPressed: () => setState(() => day = null),
                          child: const Text('Ver todo el mes'),
                        ),
                      if (occurrences
                          .where((e) => day == null || e['fecha'] == day)
                          .isEmpty)
                        const Text(
                          'Sin reuniones para la selección.',
                          textAlign: TextAlign.center,
                        ),
                      for (final e in occurrences.where(
                        (e) => day == null || e['fecha'] == day,
                      ))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Text(
                                '${e['nombre'] ?? 'Reunión'}',
                                style: Theme.of(context).textTheme.titleSmall,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                '${reunionDateTime(e['inicio'] ?? e['fecha'])} · ${e['duracion_min'] ?? '—'} min',
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                '${reunionStateLabel(e['estado']?.toString())}${e['definitivo'] == false ? ' · Provisorio' : ''}',
                                textAlign: TextAlign.center,
                              ),
                              if (e['motivo_cambio'] != null)
                                Text(
                                  '${e['motivo_cambio']}',
                                  textAlign: TextAlign.center,
                                ),
                              if (e['motivo_cancelacion'] != null)
                                Text(
                                  '${e['motivo_cancelacion']}',
                                  textAlign: TextAlign.center,
                                ),
                              if (e['reunion_id'] is num)
                                TextButton(
                                  onPressed: () => widget.onOpen(
                                    (e['reunion_id'] as num).toInt(),
                                  ),
                                  child: const Text('Ver reunión'),
                                ),
                            ],
                          ),
                        ),
                    ]),
                    card([
                      Text(
                        'Mi dashboard del mes',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (stats['provisional'] == true)
                        const Text(
                          'Datos provisorios: pueden cambiar.',
                          textAlign: TextAlign.center,
                        ),
                      LayoutBuilder(
                        builder: (context, c) {
                          final cols = AppLayout.columns(
                            context,
                            c.maxWidth,
                            minWidth: 150,
                            maxColumns: 4,
                          );
                          final entries = {
                            'Planificadas': 'planificadas',
                            'Realizadas': 'realizadas',
                            'Próximas': 'proximas',
                            'Asistidas': 'asistidas',
                            'Ausencias definitivas': 'ausentes',
                            'Ausencias provisorias': 'ausentes_provisionales',
                            'Justificadas': 'justificados',
                            'Canceladas': 'canceladas',
                          };
                          return Wrap(
                            spacing: 12,
                            runSpacing: 16,
                            children: [
                              for (final e in entries.entries)
                                SizedBox(
                                  width: (c.maxWidth - 12 * (cols - 1)) / cols,
                                  child: metric(e.key, totals[e.value]),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      metric(
                        'Asistencia',
                        totals['asistencia_pct'] == null
                            ? null
                            : '${totals['asistencia_pct']}%',
                      ),
                      metric(
                        'Puntualidad',
                        totals['puntualidad_pct'] == null
                            ? null
                            : '${totals['puntualidad_pct']}%',
                      ),
                      bar(
                        'Horas planificadas',
                        totals['minutos_planificados'],
                        maxMinutes,
                        hours: true,
                      ),
                      bar(
                        'Horas realizadas',
                        totals['minutos_realizados'],
                        maxMinutes,
                        hours: true,
                      ),
                      bar(
                        'Horas de reuniones asistidas',
                        totals['minutos_asistidos'],
                        maxMinutes,
                        hours: true,
                      ),
                      const Text(
                        'Horas según duración programada. No mide permanencia real. Las reuniones futuras no cuentan como ausencias.',
                        textAlign: TextAlign.center,
                      ),
                      if (definitions.isNotEmpty)
                        ExpansionTile(
                          title: const Text('Cómo se calculan'),
                          children: [
                            for (final d in definitions.values)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('$d', textAlign: TextAlign.center),
                              ),
                          ],
                        ),
                    ]),
                    card([
                      Text(
                        'Evolución mensual',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          for (final n in [6, 12])
                            ChoiceChip(
                              label: Text('$n meses'),
                              selected: months == n,
                              onSelected: (_) {
                                setState(() => months = n);
                                load();
                              },
                            ),
                        ],
                      ),
                      if (evolutionError != null) ...[
                        Text(evolutionError!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: load,
                          child: const Text('Reintentar evolución'),
                        ),
                      ],
                      for (final m in reunionMaps(evolution['meses'])) ...[
                        const Divider(),
                        Text(
                          '${m['mes']}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        bar(
                          'Realizadas',
                          m['realizadas'],
                          (m['realizadas'] as num?) ?? 0,
                        ),
                        bar(
                          'Asistidas',
                          m['asistidas'],
                          (m['realizadas'] as num?) ?? 0,
                        ),
                        bar(
                          'Horas realizadas',
                          m['minutos_realizados'],
                          (m['minutos_realizados'] as num?) ?? 0,
                          hours: true,
                        ),
                        bar(
                          'Horas asistidas',
                          m['minutos_asistidos'],
                          (m['minutos_realizados'] as num?) ?? 0,
                          hours: true,
                        ),
                        Text(
                          m['asistencia_pct'] == null
                              ? 'Asistencia: Sin datos'
                              : 'Asistencia: ${m['asistencia_pct']}%',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
