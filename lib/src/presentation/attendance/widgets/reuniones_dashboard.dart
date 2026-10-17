import 'package:flutter/material.dart';
import '../../../core/network/reuniones_models.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_card.dart';

class ReunionWeekSummary extends StatelessWidget {
  const ReunionWeekSummary({
    super.key,
    required this.data,
    this.showTitle = true,
  });
  final Map<String, dynamic> data;
  final bool showTitle;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (showTitle) ...[
            const Text(
              'Tu semana de reuniones',
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              for (final field in const {
                'reuniones': 'Reuniones',
                'horas': 'Horas',
                'registradas': 'Registradas',
                'tarde': 'Tarde',
                'pendientes': 'Pendientes',
                'ausentes': 'Ausentes',
                'justificadas': 'Justificadas',
                'canceladas': 'Canceladas',
                'superpuestas': 'Superpuestas',
              }.entries)
                Text(
                  '${field.value}: ${data[field.key] ?? 0}',
                  style: const TextStyle(fontSize: 12, height: 1.3),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ReunionesViewport extends StatelessWidget {
  const ReunionesViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: child,
      ),
    ),
  );
}

/// Natural-height cards: larger fonts never get clipped by a fixed grid ratio.
class ReunionesResponsiveGrid extends StatelessWidget {
  const ReunionesResponsiveGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth >= 720 * scale.clamp(1, 1.5) ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class ReunionesAgendaOverview extends StatelessWidget {
  const ReunionesAgendaOverview({
    super.key,
    required this.items,
    this.onScan,
    this.onDetail,
  });
  final List<ReunionOccurrence> items;
  final VoidCallback? onScan;
  final ValueChanged<int>? onDetail;

  @override
  Widget build(BuildContext context) {
    final active = items.where((item) => !item.cancelada).toList();
    final upcoming =
        active
            .where(
              (item) => item.estado == 'abierta' || item.estado == 'pendiente',
            )
            .toList()
          ..sort((a, b) {
            if (a.estado == 'abierta' && b.estado != 'abierta') return -1;
            if (b.estado == 'abierta' && a.estado != 'abierta') return 1;
            return a.inicio.compareTo(b.inicio);
          });
    final next = upcoming.firstOrNull;
    final open = active.where((item) => item.estado == 'abierta').length;
    final attended = active
        .where((item) => ['presente', 'tarde'].contains(item.estado))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.of(context).brandGradient,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.groups_2_outlined,
                    color: Colors.white70,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      next?.estado == 'abierta'
                          ? 'REGISTRO ABIERTO'
                          : 'TU PRÓXIMA REUNIÓN',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                next?.nombre ?? 'Todo al día',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (next != null) ...[
                _HeroLine(
                  icon: Icons.schedule_rounded,
                  text:
                      '${reunionDateTime(next.data['inicio'])} · hora Argentina',
                ),
                if (next.location.isNotEmpty)
                  _HeroLine(
                    icon: Icons.location_on_outlined,
                    text: next.location,
                  ),
                if (next.data['motivo_cambio'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      next.data['motivo_cambio'].toString(),
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (next.estado == 'abierta')
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.of(
                            context,
                          ).surface(Colors.white),
                          foregroundColor: AppColors.of(
                            context,
                          ).foreground(AppPalette.navy),
                        ),
                        onPressed: onScan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text(
                          'Registrar asistencia',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: AppColors.of(context).border(Colors.white54),
                        ),
                      ),
                      onPressed: onDetail == null
                          ? null
                          : () => onDetail!(next.reunionId),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text(
                        'Ver reunión',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ] else
                const Text(
                  'No tenés reuniones pendientes esta semana.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 500 ? 3 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AgendaMetric(
                  width: width,
                  value: '${active.length}',
                  label: 'Esta semana',
                  icon: Icons.calendar_month_outlined,
                  color: AppPalette.blue,
                ),
                _AgendaMetric(
                  width: width,
                  value: '$open',
                  label: 'Registro abierto',
                  icon: Icons.qr_code_rounded,
                  color: AppPalette.warning,
                ),
                _AgendaMetric(
                  width: width,
                  value: '$attended',
                  label: 'Ya registradas',
                  icon: Icons.task_alt_rounded,
                  color: AppPalette.success,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          'Agenda de la semana',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Horarios y sedes según tu convocatoria.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.of(context).foreground(AppPalette.muted),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _AgendaMetric extends StatelessWidget {
  const _AgendaMetric({
    required this.width,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final double width;
  final String value, label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.of(context).surface(color.withValues(alpha: .06)),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppColors.of(context).border(color.withValues(alpha: .15)),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: AppColors.of(context).foreground(color)),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.of(context).foreground(color),
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.of(context).foreground(AppPalette.muted),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class ReunionStatusBadge extends StatelessWidget {
  const ReunionStatusBadge({super.key, required this.state});
  final String state;
  static Color color(String state) => switch (state) {
    'presente' => AppPalette.success,
    'tarde' => AppPalette.warning,
    'ausente' => AppPalette.danger,
    'abierta' => AppPalette.blue,
    _ => AppPalette.muted,
  };
  @override
  Widget build(BuildContext context) {
    final accent = color(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface(accent.withValues(alpha: .09)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        reunionStateLabel(state),
        style: TextStyle(
          color: AppColors.of(context).foreground(accent),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class ReunionPercentPanel extends StatelessWidget {
  const ReunionPercentPanel({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.caption,
  });
  final String label, caption;
  final num? value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.of(context).surface(color.withValues(alpha: .055)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.of(context).foreground(color),
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          value == null
              ? 'Sin datos'
              : '${value!.toStringAsFixed(value == value!.roundToDouble() ? 0 : 1)}%',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.of(context).foreground(color),
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (value != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (value!.toDouble() / 100).clamp(0, 1),
              color: AppColors.of(context).foreground(color),
              backgroundColor: AppColors.of(
                context,
              ).surface(color.withValues(alpha: .1)),
              minHeight: 7,
              semanticsLabel: label,
              semanticsValue: '$value%',
            ),
          ),
        const SizedBox(height: 10),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.of(context).foreground(AppPalette.muted),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
