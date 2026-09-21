import 'package:flutter/material.dart';

const _ink = Color(0xFF123B53);
const _teal = Color(0xFF14745C);
const _red = Color(0xFFB33138);

/// Overview of personal evaluations; never combines scores across roles.
class SkapEvaluationsList extends StatefulWidget {
  const SkapEvaluationsList({
    super.key,
    required this.rows,
    required this.onOpen,
    required this.onRefresh,
  });
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final Future<void> Function() onRefresh;

  @override
  State<SkapEvaluationsList> createState() => _SkapEvaluationsListState();
}

class _SkapEvaluationsListState extends State<SkapEvaluationsList> {
  String? _year;

  @override
  Widget build(BuildContext context) {
    final years =
        widget.rows
            .map((r) => r['anio']?.toString())
            .whereType<String>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final selectedYear = years.contains(_year) ? _year : null;
    final visible = widget.rows
        .where(
          (r) => selectedYear == null || r['anio']?.toString() == selectedYear,
        )
        .toList();
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_ink, Color(0xFF1A5967)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  color: Color(0xFF81E0C4),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'MI DESARROLLO · SKAP',
                                    style: TextStyle(
                                      color: Color(0xFFD7EAF0),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tu progreso,\nde un vistazo',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Descubrí tus fortalezas y qué podés mejorar en cada rol.',
                              style: TextStyle(
                                color: Color(0xFFD7EAF0),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _Pill(
                                  text:
                                      '${widget.rows.length} ${widget.rows.length == 1 ? 'evaluación disponible' : 'evaluaciones disponibles'}',
                                  color: const Color(0xFFDFF5EE),
                                  foreground: _ink,
                                ),
                                const _Pill(
                                  text: 'Escala de puntaje 0–4',
                                  color: Color(0xFFDCEBF1),
                                  foreground: _ink,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Mis evaluaciones por rol',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          TextButton.icon(
                            onPressed: widget.onRefresh,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Actualizar'),
                          ),
                        ],
                      ),
                      if (years.length > 1) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos los años'),
                              selected: selectedYear == null,
                              onSelected: (_) => setState(() => _year = null),
                            ),
                            for (final year in years)
                              ChoiceChip(
                                label: Text(year),
                                selected: selectedYear == year,
                                onSelected: (_) => setState(() => _year = year),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (visible.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 42,
                                color: _ink,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Todavía no tenés evaluaciones cargadas.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Cuando estén disponibles, vas a poder consultar acá tus resultados y próximos pasos.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, box) {
                          final columns =
                              box.maxWidth >= 760 &&
                                  MediaQuery.textScalerOf(context).scale(16) <
                                      24
                              ? 2
                              : 1;
                          final width =
                              (box.maxWidth - (columns - 1) * 16) / columns;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final row in visible)
                                SizedBox(
                                  width: width,
                                  child: _EvaluationCard(
                                    row: row,
                                    onTap: () => widget.onOpen(row),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Color(0xFF58717C),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tus resultados son personales. Solo vos y los responsables autorizados pueden consultarlos.',
                              style: TextStyle(
                                color: Color(0xFF58717C),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({required this.row, required this.onTap});
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final raw = row['resumen'];
    final summary = raw is Map ? raw : const {};
    final definitive = summary['cumplimiento_pct'];
    final value = definitive ?? summary['parcial_pct'];
    final valid = value is num && value.isFinite && value >= 0 && value <= 100;
    final gaps = summary['brechas'];
    final pending = summary['faltantes'];
    final hasGaps = gaps is num && gaps > 0;
    final hasPending = pending is num && pending > 0;
    final color = hasGaps ? _red : _teal;
    final status = hasGaps
        ? 'Con oportunidades de mejora'
        : hasPending || definitive == null
        ? 'Evaluación incompleta'
        : valid
        ? 'Resultado disponible'
        : 'Resultado por revisar';
    final label = !valid
        ? 'Sin datos suficientes'
        : definitive == null
        ? 'Resultado incompleto · Parcial: ${value.toStringAsFixed(2)} %'
        : 'Cumplimiento: ${value.toStringAsFixed(2)} %';
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFDCE5EB)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_outlined, color: _ink),
                  ),
                  _Pill(
                    text: status,
                    color: hasGaps
                        ? const Color(0xFFFFE9E6)
                        : const Color(0xFFEAF2F6),
                    foreground: hasGaps ? _red : _ink,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${row['rol']} · ${row['anio']}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: Color(0xFF58717C),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${row['sucursal_nombre'] ?? 'Sucursal sin informar'}',
                      style: const TextStyle(color: Color(0xFF58717C)),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1, color: Color(0xFFE8EEF2)),
              ),
              LayoutBuilder(
                builder: (context, box) {
                  final indicator = SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: valid ? value / 100 : 0,
                            strokeWidth: 7,
                            color: color,
                            backgroundColor: const Color(0xFFEAF0F3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: FittedBox(
                            child: Text(
                              valid ? '${value.toStringAsFixed(1)}%' : '—',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  final explanation = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Objetivo: 100 % del estándar de tu rol.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF58717C),
                          height: 1.4,
                        ),
                      ),
                    ],
                  );
                  if (box.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(16) >= 24) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        indicator,
                        const SizedBox(height: 16),
                        explanation,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      indicator,
                      const SizedBox(width: 20),
                      Expanded(child: explanation),
                    ],
                  );
                },
              ),
              if (gaps != null ||
                  pending != null ||
                  summary['evaluadas'] != null) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (summary['evaluadas'] != null)
                      _Pill(
                        text: '${summary['evaluadas']} evaluadas',
                        color: const Color(0xFFEAF2F6),
                        foreground: _ink,
                      ),
                    if (gaps != null)
                      _Pill(
                        text: '$gaps ${gaps == 1 ? 'brecha' : 'brechas'}',
                        color: hasGaps
                            ? const Color(0xFFFFE9E6)
                            : const Color(0xFFE5F4EE),
                        foreground: hasGaps ? _red : _teal,
                      ),
                    if (hasPending)
                      _Pill(
                        text: '$pending sin evaluar',
                        color: const Color(0xFFFFF0D5),
                        foreground: const Color(0xFF895C12),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ver mi evaluación',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    required this.foreground,
  });
  final String text;
  final Color color;
  final Color foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: foreground,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
