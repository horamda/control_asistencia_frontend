import '../../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../../../core/network/feedback_api_models.dart';

const _blue = AppPalette.blue;
const _ink = AppPalette.navy;
const _green = AppPalette.success;
const _red = AppPalette.danger;

double? _ratio(int? part, int? total) =>
    part == null || total == null || total <= 0 || part < 0 || part > total
    ? null
    : part / total;
String _percent(double? ratio) =>
    ratio == null ? 'Sin datos' : '${(ratio * 100).toStringAsFixed(1)} %';
String _count(int? value) => value?.toString() ?? '—';

class FeedbackSummaryDashboard extends StatelessWidget {
  const FeedbackSummaryDashboard({super.key, required this.dashboard});
  final FeedbackDashboardResponse dashboard;

  @override
  Widget build(BuildContext context) {
    final summary = dashboard.resumen;
    final personal = dashboard.personal;
    final slaTotal =
        summary.resueltosEnSla == null || summary.resueltosFueraSla == null
        ? null
        : summary.resueltosEnSla! + summary.resueltosFueraSla!;
    final resolution = _ratio(summary.resueltos, summary.total);
    final sla = _ratio(summary.resueltosEnSla, slaTotal);
    final contribution = _ratio(personal?.totalCargados, summary.total);
    final participation = _ratio(
      dashboard.totales.empleadosConCarga,
      dashboard.totales.empleadosActivos,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          color: _blue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'FEEDBACK DE CALLE',
                style: TextStyle(
                  color: AppColors.of(
                    context,
                  ).foreground(const Color(0xFFDCEBFF)),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, box) {
                  final ring = SizedBox(
                    width: 112,
                    height: 112,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: resolution ?? 0,
                            strokeWidth: 8,
                            backgroundColor: AppColors.of(
                              context,
                            ).surface(Colors.white.withValues(alpha: .2)),
                            color: AppColors.of(
                              context,
                            ).foreground(const Color(0xFF8DE7CE)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: FittedBox(
                            child: Text(
                              resolution == null
                                  ? '—'
                                  : '${(resolution * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  final info = Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Resolución del equipo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_count(summary.resueltos)} de ${_count(summary.total)} feedbacks resueltos',
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Resumen general · Tus cargas se muestran por separado.',
                        style: TextStyle(
                          color: AppColors.of(
                            context,
                          ).foreground(const Color(0xFFDCEBFF)),
                          fontSize: 13,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                  if (box.maxWidth < 310 ||
                      MediaQuery.textScalerOf(context).scale(16) >= 24) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [ring, const SizedBox(height: 20), info],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ring,
                      const SizedBox(width: 24),
                      Expanded(child: info),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Grid(
          children: [
            _Metric(
              title: 'Resueltos a tiempo',
              value: _percent(sla),
              detail:
                  '${_count(summary.resueltosEnSla)} de ${_count(slaTotal)} cierres con plazo evaluado',
              icon: Icons.verified_rounded,
              color: _green,
              ratio: sla,
            ),
            _Metric(
              title: 'Requieren atención',
              value: _count(summary.vencidos),
              detail:
                  '${_percent(_ratio(summary.vencidos, summary.total))} del total · Vencidos sin resolver',
              icon: Icons.warning_amber_rounded,
              color: (summary.vencidos ?? 0) > 0 ? _red : _ink,
              ratio: _ratio(summary.vencidos, summary.total),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Heading(icon: Icons.person_rounded, text: 'Tu aporte'),
              if (dashboard.empleado != null) ...[
                const SizedBox(height: 8),
                Text(
                  dashboard.empleado!.displayName,
                  style: TextStyle(
                    color: AppColors.of(context).foreground(_ink),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              _Grid(
                children: [
                  _Number(
                    label: 'Feedbacks que cargaste',
                    value: _count(personal?.totalCargados),
                    color: _blue,
                  ),
                  _Number(
                    label: 'Tu participación en el total',
                    value: _percent(contribution),
                    color: _blue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Bar(value: contribution, color: _blue),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    'Posición por cantidad de cargas: ${personal?.posicionRanking == null ? 'Sin posición' : '#${personal!.posicionRanking}'}',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Promedio por empleado activo: ${personal?.promedioPorEmpleado?.toStringAsFixed(2) ?? '—'}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'La participación y la posición miden cantidad de cargas, no calidad ni desempeño.',
                style: TextStyle(
                  color: AppColors.of(context).foreground(AppPalette.muted),
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Heading(
                icon: Icons.donut_small_rounded,
                text: 'Estado de los feedbacks',
              ),
              const SizedBox(height: 6),
              Text(
                '${_count(summary.total)} registros en el resumen general',
                style: TextStyle(
                  color: AppColors.of(context).foreground(AppPalette.muted),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              for (final state in [
                ('Resueltos', summary.resueltos, _green),
                ('Pendientes en plazo', summary.pendientes, _blue),
                ('En proceso', summary.enProceso, const Color(0xFF7258A8)),
                ('Vencidos sin resolver', summary.vencidos, _red),
              ]) ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      state.$1,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${_count(state.$2)} · ${_percent(_ratio(state.$2, summary.total))}',
                      style: TextStyle(
                        color: AppColors.of(context).foreground(state.$3),
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _Bar(value: _ratio(state.$2, summary.total), color: state.$3),
                const SizedBox(height: 16),
              ],
              Text(
                'Resueltos fuera de plazo: ${_count(summary.resueltosFueraSla)}',
                style: TextStyle(
                  color: AppColors.of(context).foreground(_red),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Los vencidos se muestran aparte de los pendientes en plazo. SLA indica el plazo previsto de resolución.',
                style: TextStyle(
                  color: AppColors.of(context).foreground(AppPalette.muted),
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Grid(
          children: [
            _Metric(
              title: 'Participación del equipo',
              value: _percent(participation),
              detail:
                  '${_count(dashboard.totales.empleadosConCarga)} de ${_count(dashboard.totales.empleadosActivos)} empleados activos tienen cargas',
              icon: Icons.groups_rounded,
              color: _blue,
              ratio: participation,
            ),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const _Heading(
                    icon: Icons.storefront_rounded,
                    text: 'Alcance del feedback',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_count(summary.clientesDistintos)} clientes',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.of(context).foreground(_ink),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_count(summary.motivosDistintos)} motivos distintos',
                    style: TextStyle(
                      color: AppColors.of(context).foreground(AppPalette.muted),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FeedbackMotivosChart extends StatelessWidget {
  const FeedbackMotivosChart({
    super.key,
    required this.items,
    required this.total,
  });
  final List<FeedbackTopMotivo> items;
  final int? total;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Porcentaje sobre el total de feedbacks',
        style: TextStyle(
          color: AppColors.of(context).foreground(AppPalette.muted),
          fontSize: 13,
        ),
      ),
      for (final item in items.take(5)) ...[
        const SizedBox(height: 16),
        Text(
          item.motivoNombre ?? 'Motivo sin nombre',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '${_count(item.total)} cargas · ${_percent(_ratio(item.total, total))} · ${_count(item.resueltos)} resueltos',
        ),
        const SizedBox(height: 8),
        _Bar(value: _ratio(item.total, total), color: _blue),
      ],
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.of(context).surface(color),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.of(
          context,
        ).border(color == Colors.white ? AppPalette.border : color),
      ),
    ),
    child: DefaultTextStyle.merge(
      textAlign: TextAlign.center,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: child,
      ),
    ),
  );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns =
          box.maxWidth >= 370 && MediaQuery.textScalerOf(context).scale(16) < 24
          ? 2
          : 1;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: (box.maxWidth - (columns - 1) * 12) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    this.ratio,
  });
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final double? ratio;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, color: AppColors.of(context).foreground(color)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.of(context).foreground(_ink),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.of(context).foreground(color),
          ),
        ),
        const SizedBox(height: 10),
        _Bar(value: ratio, color: color),
        const SizedBox(height: 10),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.of(context).foreground(AppPalette.muted),
          ),
        ),
      ],
    ),
  );
}

class _Number extends StatelessWidget {
  const _Number({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.of(context).foreground(color),
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.of(context).foreground(AppPalette.muted),
          fontSize: 13,
        ),
      ),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 22, color: AppColors.of(context).foreground(_ink)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.of(context).foreground(_ink),
          ),
        ),
      ),
    ],
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});
  final double? value;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: value == null ? 'Porcentaje no disponible' : _percent(value),
    child: LinearProgressIndicator(
      value: value ?? 0,
      color: AppColors.of(
        context,
      ).foreground(value == null ? Colors.blueGrey : color),
      backgroundColor: AppColors.of(context).surface(const Color(0xFFEAF0F4)),
      minHeight: 7,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
