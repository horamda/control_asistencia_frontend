import 'package:flutter/material.dart';

const _navy = Color(0xFF123B53);
const _green = Color(0xFF14745C);
const _red = Color(0xFFB33138);
const _amber = Color(0xFF895C12);

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
num? _number(dynamic value) => value is num && value.isFinite ? value : null;
String _score(dynamic value) => _number(value)?.toString() ?? '—';
String _pct(num value) => '${value.toStringAsFixed(2)} %';
bool _gap(Map<String, dynamic> row) =>
    row['estado'] == 'evaluado' &&
    _number(row['puntaje']) != null &&
    _number(row['estandar']) != null &&
    (row['puntaje'] as num) < (row['estandar'] as num);

/// Read-only dashboard. Scores and summaries retain the backend's semantics.
class SkapMatrixDashboard extends StatefulWidget {
  const SkapMatrixDashboard({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  State<SkapMatrixDashboard> createState() => _SkapMatrixDashboardState();
}

class _SkapMatrixDashboardState extends State<SkapMatrixDashboard> {
  String _filter = 'Todas';
  final _resultsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final summary = _map(data['resumen']);
    final responses = (data['respuestas'] as List? ?? []).map(_map).toList();
    final actions = (data['acciones'] as List? ?? []).map(_map).toList();
    final gaps = responses.where(_gap).length;
    final pending = responses.where((r) => r['estado'] == 'sin_evaluar').length;
    final visible = responses
        .where(
          (r) => switch (_filter) {
            'A mejorar' => _gap(r),
            'Sin evaluar' => r['estado'] == 'sin_evaluar',
            _ => true,
          },
        )
        .toList();
    // Put gaps first without conflating missing results with low scores.
    visible.sort((a, b) {
      int priority(Map<String, dynamic> r) =>
          _gap(r) ? (r['criticidad'] == 'A' ? 0 : 1) : 2;
      return priority(a).compareTo(priority(b));
    });
    final blocks = {
      ...visible.map((r) => r['bloque']?.toString() ?? 'Sin bloque'),
      if (_filter == 'Todas') ..._map(summary['bloques']).keys,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 600 ? 16.0 : 28.0;
        return SingleChildScrollView(
          key: const PageStorageKey('skap-matrix-detail'),
          padding: EdgeInsets.fromLTRB(padding, 12, padding, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'MIS EVALUACIONES / MATRIZ OPERATIVA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _navy,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${data['rol']} · ${data['anio']}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${data['sucursal'] ?? 'Sucursal sin informar'} · Escala 0–4',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (data['fecha_evaluacion'] != null)
                    Text('Fecha de evaluación: ${data['fecha_evaluacion']}'),
                  const SizedBox(height: 20),
                  _Overview(summary: summary),
                  const SizedBox(height: 16),
                  _AdaptiveCards(
                    children: [
                      _Metric(
                        title: 'Competencias críticas',
                        summary: _map(summary['criticas']),
                        icon: Icons.verified_user_outlined,
                      ),
                      _Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Label(
                              icon: Icons.flag_outlined,
                              text: 'Tu próximo paso',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              gaps > 0
                                  ? gaps == 1
                                        ? '1 competencia a mejorar'
                                        : '$gaps competencias a mejorar'
                                  : pending > 0
                                  ? 'Completar la evaluación'
                                  : 'Seguí desarrollándote',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: gaps > 0 ? _red : _navy,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              gaps > 0
                                  ? 'Revisá las brechas y tu plan de desarrollo. Priorizá las competencias críticas.'
                                  : 'Consultá los resultados por competencia y el seguimiento de tu plan.',
                            ),
                            if (gaps > 0) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  setState(() => _filter = 'A mejorar');
                                  final target = _resultsKey.currentContext;
                                  if (target != null) {
                                    await Scrollable.ensureVisible(
                                      target,
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.filter_alt_outlined),
                                label: const Text('Ver qué mejorar'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((_number(summary['criticidad_sin_definir']) ?? 0) >
                      0) ...[
                    const SizedBox(height: 12),
                    _Notice(
                      text:
                          '${summary['criticidad_sin_definir']} competencias con criticidad sin definir; resultado crítico incompleto.',
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Resultado vs. objetivo',
                    key: _resultsKey,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cada tarjeta muestra tu puntaje y el nivel esperado para tu rol.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in {
                        'Todas': responses.length,
                        'A mejorar': gaps,
                        'Sin evaluar': pending,
                      }.entries)
                        ChoiceChip(
                          label: Text('${entry.key} (${entry.value})'),
                          selected: _filter == entry.key,
                          onSelected: (_) =>
                              setState(() => _filter = entry.key),
                        ),
                    ],
                  ),
                  if (blocks.isEmpty) ...[
                    const SizedBox(height: 16),
                    _Panel(
                      child: Text(
                        _filter == 'A mejorar'
                            ? 'No hay brechas en las competencias evaluadas.'
                            : _filter == 'Sin evaluar'
                            ? 'No hay competencias pendientes de evaluación.'
                            : 'Todavía no hay competencias cargadas.',
                      ),
                    ),
                  ],
                  for (final block in blocks) ...[
                    const SizedBox(height: 20),
                    _BlockHeader(
                      name: block,
                      summary: _map(_map(summary['bloques'])[block]),
                    ),
                    const SizedBox(height: 12),
                    _AdaptiveCards(
                      children: [
                        for (final row in visible.where(
                          (r) =>
                              (r['bloque']?.toString() ?? 'Sin bloque') ==
                              block,
                        ))
                          _Competency(row: row),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Mi plan de desarrollo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (actions.isEmpty)
                    const _Panel(
                      child: Text(
                        'Todavía no hay acciones de desarrollo cargadas.',
                      ),
                    ),
                  if (actions.isNotEmpty) ...[
                    const Text(
                      'Las propuestas son próximos pasos, no capacitaciones realizadas. Tu responsable gestiona el seguimiento.',
                    ),
                    const SizedBox(height: 12),
                    for (final action in actions) ...[
                      _ActionCard(action: action),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 20),
                  const _Panel(
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('¿Cómo se calcula el resultado?'),
                      leading: Icon(Icons.info_outline),
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'El objetivo es alcanzar el estándar de cada competencia. El cumplimiento tiene un máximo de 100 %: superar un objetivo no compensa otra brecha. “No aplica” se excluye del cálculo. Si faltan evaluaciones, se muestra un resultado parcial. El puntaje 0 es una evaluación válida.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.color = Colors.white, this.border});
  final Widget child;
  final Color color;
  final Color? border;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: border ?? const Color(0xFFE0E7EB)),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class _AdaptiveCards extends StatelessWidget {
  const _AdaptiveCards({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 740 &&
          MediaQuery.textScalerOf(context).scale(16) < 24;
      final width = wide
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _Label extends StatelessWidget {
  const _Label({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _navy, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, color: _navy),
        ),
      ),
    ],
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) {
    final definitive = _number(summary['cumplimiento_pct']);
    final value = definitive ?? _number(summary['parcial_pct']);
    final valid = value != null && value >= 0 && value <= 100;
    final ring = SizedBox(
      width: 106,
      height: 106,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: valid ? value / 100 : 0,
              strokeWidth: 8,
              backgroundColor: Colors.white.withValues(alpha: .16),
              color: const Color(0xFF70DEC0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: FittedBox(
              child: Text(
                valid ? '${value.toStringAsFixed(1)}%' : '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          definitive == null ? 'Tu avance hasta hoy' : 'Tu resultado general',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          !valid
              ? 'Sin un porcentaje válido para mostrar.'
              : definitive == null
              ? 'Resultado incompleto · Parcial: ${_pct(value)}'
              : 'Cumplimiento: ${_pct(value)}',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
    return _Panel(
      color: _navy,
      border: _navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(16) >= 24) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: ring),
                    const SizedBox(height: 20),
                    heading,
                  ],
                );
              }
              return Row(
                children: [
                  ring,
                  const SizedBox(width: 22),
                  Expanded(child: heading),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            'Objetivo: alcanzar el estándar de cada competencia.',
            style: TextStyle(color: Color(0xFFCEE0EA)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                text: '${summary['evaluadas'] ?? 0} evaluadas',
                color: const Color(0xFFDFF5EE),
              ),
              _Badge(
                text:
                    '${summary['brechas'] ?? 0} ${(summary['brechas'] ?? 0) == 1 ? 'brecha' : 'brechas'}',
                color: const Color(0xFFFFE4E4),
                foreground: _red,
              ),
              _Badge(
                text: '${summary['faltantes'] ?? 0} sin evaluar',
                color: const Color(0xFFFFF0D5),
                foreground: _amber,
              ),
              _Badge(
                text: '${summary['no_aplica'] ?? 0} no aplican',
                color: const Color(0xFFE6EEF5),
                foreground: _navy,
              ),
              if ((_number(summary['expertas']) ?? 0) > 0)
                _Badge(
                  text: '${summary['expertas']} de nivel experto',
                  color: const Color(0xFFDFF5EE),
                ),
            ],
          ),
          if (summary['acreditado'] != null && summary['esperado'] != null) ...[
            const SizedBox(height: 12),
            Text(
              'Puntaje acreditado: ${summary['acreditado']} / ${summary['esperado']}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
          if (value != null && !valid) ...[
            const SizedBox(height: 12),
            _InvalidPercent(value: value),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    this.foreground = _green,
  });
  final String text;
  final Color color;
  final Color foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: foreground,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.summary,
    required this.icon,
  });
  final String title;
  final Map<String, dynamic> summary;
  final IconData icon;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(icon: icon, text: title),
        const SizedBox(height: 14),
        _SummaryProgress(summary: summary),
        const SizedBox(height: 10),
        Text(
          '${summary['evaluadas'] ?? 0} evaluadas · ${summary['brechas'] ?? 0} brechas · ${summary['faltantes'] ?? 0} sin evaluar',
        ),
      ],
    ),
  );
}

class _SummaryProgress extends StatelessWidget {
  const _SummaryProgress({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) {
    final definitive = _number(summary['cumplimiento_pct']);
    final value = definitive ?? _number(summary['parcial_pct']);
    if (value != null && (value < 0 || value > 100)) {
      return _InvalidPercent(value: value);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value == null
              ? 'Sin datos suficientes'
              : definitive == null
              ? 'Resultado incompleto · Parcial: ${_pct(value)}'
              : 'Cumplimiento: ${_pct(value)}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
        ),
        const SizedBox(height: 10),
        if (value != null)
          Semantics(
            label: 'Cumplimiento ${_pct(value)}. Objetivo 100 por ciento.',
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              color: (summary['brechas'] as num? ?? 0) > 0 ? _amber : _green,
              backgroundColor: const Color(0xFFE8EEF0),
            ),
          ),
      ],
    );
  }
}

class _InvalidPercent extends StatelessWidget {
  const _InvalidPercent({required this.value});
  final num value;
  @override
  Widget build(BuildContext context) => _Notice(
    text:
        'Resultado por revisar: el servidor informó ${_pct(value)}. El cumplimiento debe estar entre 0 y 100 %. Consultá los puntajes por competencia.',
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3DE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20, color: _amber),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: _amber)),
        ),
      ],
    ),
  );
}

class _BlockHeader extends StatelessWidget {
  const _BlockHeader({required this.name, required this.summary});
  final String name;
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: _navy,
        ),
      ),
      if (summary.isNotEmpty) ...[
        const SizedBox(height: 8),
        _SummaryProgress(summary: summary),
      ],
    ],
  );
}

class _Competency extends StatelessWidget {
  const _Competency({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final gap = _gap(row);
    final value = row['estado'] == 'evaluado' ? _number(row['puntaje']) : null;
    final target = _number(row['estandar']);
    final na = row['estado'] == 'no_aplica';
    final met = value != null && target != null && !gap;
    final color = gap
        ? _red
        : met
        ? _green
        : _amber;
    final status = gap
        ? 'A mejorar'
        : met
        ? value > target
              ? 'Supera el objetivo'
              : 'Objetivo alcanzado'
        : na
        ? 'No aplica'
        : 'Sin evaluar';
    return _Panel(
      color: gap ? const Color(0xFFFFF7F6) : Colors.white,
      border: gap ? const Color(0xFFF0B7B4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                text: status,
                color: gap
                    ? const Color(0xFFFFE3E1)
                    : met
                    ? const Color(0xFFE0F3EC)
                    : const Color(0xFFFFF0D5),
                foreground: color,
              ),
              if (row['criticidad'] == 'A')
                const _Badge(
                  text: 'Crítica · A',
                  color: Color(0xFFE6EEF5),
                  foreground: _navy,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${row['competencia'] ?? 'Competencia'}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              Text(
                'Puntaje: ${value != null
                    ? _score(value)
                    : na
                    ? 'No aplica'
                    : 'Sin evaluar'}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              Text(
                'Objetivo: ${_score(target)} / 4',
                style: const TextStyle(color: _navy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                'Puntaje ${value ?? status}. Objetivo ${target ?? 'sin definir'} de 4.',
            child: Row(
              children: [
                for (var step = 1; step <= 4; step++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: step == 4 ? 0 : 5),
                      child: Column(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: value != null && value >= step
                                  ? color
                                  : const Color(0xFFE5EAED),
                              borderRadius: BorderRadius.circular(3),
                              border: target == step
                                  ? Border.all(color: _navy, width: 2)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$step',
                            style: TextStyle(
                              fontSize: 11,
                              color: target == step ? _navy : Colors.blueGrey,
                              fontWeight: target == step
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                gap
                    ? Icons.trending_up
                    : met
                    ? Icons.check_circle_outline
                    : Icons.remove_circle_outline,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  gap
                      ? target! - value! == 1
                            ? 'Te falta 1 punto para el objetivo.'
                            : 'Te faltan ${_score(target - value)} puntos para el objetivo.'
                      : met
                      ? 'Alcanzaste el nivel esperado para tu rol.'
                      : na
                      ? 'Esta competencia no entra en el cálculo.'
                      : 'Todavía no hay un puntaje registrado.',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
          if (row['criticidad'] != 'A') ...[
            const SizedBox(height: 8),
            Text(
              'Criticidad: ${row['criticidad'] ?? 'Sin definir'}',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});
  final Map<String, dynamic> action;
  @override
  Widget build(BuildContext context) {
    final progress = _number(action['progreso']);
    final state = switch (action['estado']) {
      'propuesta' => 'Propuesta',
      'pendiente' => 'Pendiente',
      'en_proceso' => 'En proceso',
      'completado' => 'Completada',
      'cancelado' => 'Cancelada',
      _ => 'Sin estado',
    };
    return _Panel(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('${action['accion']}'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$state · ${progress == null ? 'Sin avance informado' : '${_score(progress)} %'}',
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (progress / 100).clamp(0.0, 1.0),
                  color: _green,
                  backgroundColor: const Color(0xFFE5EAED),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Responsable: ${action['responsable'] ?? 'Sin asignar'}',
                  ),
                  Text('Inicio: ${action['fecha_inicio'] ?? 'Sin definir'}'),
                  Text('Fin: ${action['fecha_fin'] ?? 'Sin definir'}'),
                  if (action['comentarios'] != null)
                    Text('${action['comentarios']}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
