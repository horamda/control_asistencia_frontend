import 'package:flutter/material.dart';

import '../../widgets/employee_photo_widget.dart';

class AttendancePendingBanner extends StatelessWidget {
  const AttendancePendingBanner({
    super.key,
    required this.hasErrors,
    required this.pendingCleanCount,
    required this.failedCount,
    required this.lastSyncText,
    this.statusMessage,
    required this.primaryAction,
    required this.secondaryAction,
  });

  final bool hasErrors;
  final int pendingCleanCount;
  final int failedCount;
  final String lastSyncText;
  final String? statusMessage;
  final AttendanceActionButtonData primaryAction;
  final AttendanceActionButtonData secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: hasErrors ? const Color(0xFFFFE7E7) : const Color(0xFFFFF7E8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasErrors ? Icons.error_outline : Icons.wifi_off_outlined,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasErrors
                        ? 'Accion requerida: fichadas con error'
                        : 'Pendientes de sincronizacion',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pendientes: $pendingCleanCount | Con error: $failedCount',
            ),
            Text('Ultima sincronizacion: $lastSyncText'),
            if ((statusMessage ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(statusMessage!),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilledActionButton(action: primaryAction),
                OutlinedButton.icon(
                  onPressed: secondaryAction.onPressed,
                  icon: Icon(secondaryAction.icon),
                  label: Text(secondaryAction.label),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceHeroCard extends StatelessWidget {
  const AttendanceHeroCard({
    super.key,
    required this.photoUrl,
    required this.token,
    required this.employeeName,
    required this.employeeDni,
    this.employeeCompany,
    required this.syncText,
    required this.sessionText,
    required this.sessionColor,
    required this.sessionForeground,
    required this.gpsStatusText,
  });

  final String photoUrl;
  final String token;
  final String employeeName;
  final String employeeDni;
  final String? employeeCompany;
  final String syncText;
  final String sessionText;
  final Color sessionColor;
  final Color sessionForeground;
  final String gpsStatusText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D3B66),
            Color(0xFF1B5C8A),
            Color(0xFF2A789E),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmployeePhotoWidget(
                  photoUrl: photoUrl,
                  token: token,
                  radius: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DNI: $employeeDni',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if ((employeeCompany ?? '').trim().isNotEmpty)
                        Text(
                          employeeCompany!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DashboardStatusPill(
                  icon: Icons.cloud_done_outlined,
                  text: syncText,
                  background: const Color(0x26FFFFFF),
                  foreground: Colors.white,
                ),
                DashboardStatusPill(
                  icon: Icons.shield_moon_outlined,
                  text: sessionText,
                  background: sessionColor.withAlpha(225),
                  foreground: sessionForeground,
                ),
                DashboardStatusPill(
                  icon: Icons.place_outlined,
                  text: gpsStatusText,
                  background: const Color(0x26FFFFFF),
                  foreground: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceNextStepCard extends StatelessWidget {
  const AttendanceNextStepCard({
    super.key,
    required this.priorityLabel,
    required this.priorityBackground,
    required this.priorityForeground,
    required this.title,
    required this.body,
    required this.primaryAction,
    this.secondaryAction,
  });

  final String priorityLabel;
  final Color priorityBackground;
  final Color priorityForeground;
  final String title;
  final String body;
  final AttendanceActionButtonData primaryAction;
  final AttendanceActionButtonData? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Siguiente paso',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: priorityBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    priorityLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: priorityForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(body),
            const SizedBox(height: 12),
            _FilledActionButton(action: primaryAction),
            if (secondaryAction != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: secondaryAction!.onPressed,
                icon: Icon(secondaryAction!.icon),
                label: Text(secondaryAction!.label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AttendanceStatsGrid extends StatelessWidget {
  const AttendanceStatsGrid({
    super.key,
    required this.items,
  });

  final List<AttendanceStatItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final cardsPerRow = constraints.maxWidth >= 640
            ? 4
            : constraints.maxWidth >= 380
            ? 2
            : 1;
        final cardWidth = cardsPerRow == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (cardsPerRow - 1))) /
                cardsPerRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: DashboardStatCard(
                    title: item.title,
                    value: item.value,
                    icon: item.icon,
                    accent: item.accent,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class AttendanceClockPanel extends StatelessWidget {
  const AttendanceClockPanel({
    super.key,
    required this.warming,
    required this.readinessBadges,
    required this.readinessSummary,
    required this.readinessCheckText,
    this.phaseText,
    required this.mainAction,
    required this.secondaryActions,
    required this.gpsText,
    this.lastQrText,
  });

  final bool warming;
  final List<AttendanceReadinessBadgeData> readinessBadges;
  final String readinessSummary;
  final String readinessCheckText;
  final String? phaseText;
  final AttendanceActionButtonData mainAction;
  final List<AttendanceActionButtonData> secondaryActions;
  final String gpsText;
  final String? lastQrText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD8E1EA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Preparacion de fichada',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (warming)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: readinessBadges
                        .map(
                          (badge) => AttendanceReadinessChip(
                            text: badge.text,
                            ready: badge.ready,
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    readinessSummary,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chequeado $readinessCheckText.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if ((phaseText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCC02), width: 1.5),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        phaseText!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            PhysicalClockButton(
              label: mainAction.label,
              icon: mainAction.icon,
              color: mainAction.color ?? const Color(0xFF0E5A8A),
              enabled: mainAction.onPressed != null,
              loading: mainAction.loading,
              onPressed: mainAction.onPressed ?? () {},
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 430;
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < secondaryActions.length; i++) ...[
                        _OutlinedActionButton(action: secondaryActions[i]),
                        if (i + 1 < secondaryActions.length)
                          const SizedBox(height: 8),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < secondaryActions.length; i++) ...[
                      Expanded(
                        child: _OutlinedActionButton(action: secondaryActions[i]),
                      ),
                      if (i + 1 < secondaryActions.length)
                        const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'GPS: $gpsText',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if ((lastQrText ?? '').trim().isNotEmpty)
              Text(
                'Ultimo QR: $lastQrText',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class AttendanceQuickActionsCard extends StatelessWidget {
  const AttendanceQuickActionsCard({
    super.key,
    required this.columns,
    required this.ratio,
    required this.items,
  });

  final int columns;
  final double ratio;
  final List<AttendanceQuickActionItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.widgets_outlined),
                const SizedBox(width: 8),
                Text(
                  'Accesos rapidos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: ratio,
              children: items
                  .map(
                    (item) => DashboardQuickActionTile(
                      icon: item.icon,
                      label: item.label,
                      enabled: item.onTap != null,
                      onTap: item.onTap ?? () {},
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceDiagnosticsCard extends StatelessWidget {
  const AttendanceDiagnosticsCard({
    super.key,
    required this.ruleBadges,
    required this.hasMetrics,
    required this.sampleCount,
    this.lastClockText,
    this.lastTotalText,
    this.lastApiText,
    this.lastGpsText,
    this.lastPhotoText,
    required this.averageTotalText,
    required this.averageApiText,
    this.lastQrText,
  });

  final List<Widget> ruleBadges;
  final bool hasMetrics;
  final int sampleCount;
  final String? lastClockText;
  final String? lastTotalText;
  final String? lastApiText;
  final String? lastGpsText;
  final String? lastPhotoText;
  final String averageTotalText;
  final String averageApiText;
  final String? lastQrText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: const Text('Diagnostico y reglas'),
        subtitle: const Text('Informacion tecnica para soporte.'),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          if (ruleBadges.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: ruleBadges,
            ),
          if (hasMetrics) ...[
            const SizedBox(height: 10),
            Text(
              'Rendimiento de fichada',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Muestras: $sampleCount${(lastClockText ?? '').trim().isNotEmpty ? ' | Ultima: $lastClockText' : ''}',
            ),
            if ((lastTotalText ?? '').trim().isNotEmpty)
              Text('Ultimo total: $lastTotalText'),
            if ((lastApiText ?? '').trim().isNotEmpty)
              Text('Ultima API: $lastApiText'),
            if ((lastGpsText ?? '').trim().isNotEmpty)
              Text('Ultimo GPS: $lastGpsText'),
            if ((lastPhotoText ?? '').trim().isNotEmpty)
              Text('Ultima foto: $lastPhotoText'),
            const SizedBox(height: 4),
            Text('Promedio total: $averageTotalText'),
            Text('Promedio API: $averageApiText'),
          ],
          if ((lastQrText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Ultimo QR: $lastQrText'),
          ],
        ],
      ),
    );
  }
}

class AttendanceRuleChip extends StatelessWidget {
  const AttendanceRuleChip({
    super.key,
    required this.label,
    required this.enabled,
  });

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: ${enabled ? "requerido" : "opcional"}'),
      backgroundColor: enabled
          ? const Color(0xFFE6F4EA)
          : const Color(0xFFF1F3F5),
    );
  }
}

class AttendanceInfoChip extends StatelessWidget {
  const AttendanceInfoChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(text), backgroundColor: const Color(0xFFE8EEF7));
  }
}

class AttendanceReadinessChip extends StatelessWidget {
  const AttendanceReadinessChip({
    super.key,
    required this.text,
    required this.ready,
  });

  final String text;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      backgroundColor: ready
          ? const Color(0xFFE6F4EA)
          : const Color(0xFFFFF3DF),
      side: BorderSide(
        color: ready ? const Color(0xFF9FD0AA) : const Color(0xFFE2B66F),
      ),
    );
  }
}

class DashboardStatusPill extends StatelessWidget {
  const DashboardStatusPill({
    super.key,
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(95)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF4F637A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class DashboardQuickActionTile extends StatelessWidget {
  const DashboardQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? const Color(0xFF173A57) : const Color(0xFF8090A2);
    return Material(
      color: enabled ? const Color(0xFFF3F8FC) : const Color(0xFFEAF0F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhysicalClockButton extends StatelessWidget {
  const PhysicalClockButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: Colors.black45,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white24, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(icon, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                loading ? 'Procesando fichada...' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceActionButtonData {
  const AttendanceActionButtonData({
    required this.label,
    required this.icon,
    this.onPressed,
    this.loading = false,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
}

class AttendanceQuickActionItem {
  const AttendanceQuickActionItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class AttendanceReadinessBadgeData {
  const AttendanceReadinessBadgeData({
    required this.text,
    required this.ready,
  });

  final String text;
  final bool ready;
}

class AttendanceStatItem {
  const AttendanceStatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
}

class _FilledActionButton extends StatelessWidget {
  const _FilledActionButton({required this.action});

  final AttendanceActionButtonData action;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: action.onPressed,
      icon: action.loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(action.icon),
      label: Text(action.label),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({required this.action});

  final AttendanceActionButtonData action;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: action.onPressed,
      icon: action.loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(action.icon),
      label: Text(action.label),
    );
  }
}
