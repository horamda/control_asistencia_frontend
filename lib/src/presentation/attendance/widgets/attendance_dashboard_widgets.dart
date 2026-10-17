import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import '../../theme/app_palette.dart';
import '../../theme/card_typography.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/employee_photo_widget.dart';
import '../../theme/app_theme.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _heroDate() {
  const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final n = DateTime.now();
  return '${days[n.weekday - 1]} ${n.day} de ${months[n.month - 1]}';
}

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
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      color: hasErrors ? cs.errorContainer : cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasErrors ? Icons.error_rounded : Icons.wifi_off_rounded,
                  color: hasErrors
                      ? cs.onErrorContainer
                      : cs.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasErrors
                        ? 'Acción requerida: fichadas con error'
                        : 'Pendientes de sincronización',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: hasErrors
                          ? cs.onErrorContainer
                          : cs.onTertiaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pendientes: $pendingCleanCount | Con error: $failedCount',
              style: TextStyle(
                color: hasErrors ? cs.onErrorContainer : cs.onTertiaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Última sincronización: $lastSyncText',
              style: TextStyle(
                color: hasErrors ? cs.onErrorContainer : cs.onTertiaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            if ((statusMessage ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                statusMessage!,
                style: TextStyle(
                  color: hasErrors
                      ? cs.onErrorContainer
                      : cs.onTertiaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _FilledActionButton(action: primaryAction),
                OutlinedButton.icon(
                  onPressed: secondaryAction.onPressed,
                  icon: Icon(secondaryAction.icon),
                  label: Text(
                    secondaryAction.label,
                    textAlign: TextAlign.center,
                  ),
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
    required this.greeting,
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
  final String greeting;
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
    // First name only for the greeting
    final firstName = employeeName.split(' ').first;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.of(context).brandGradient,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
                final stacked =
                    constraints.maxWidth < 280 ||
                    (scale > 1.4 && constraints.maxWidth < 500);
                final photo = Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .08),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: EmployeePhotoWidget(
                    photoUrl: photoUrl,
                    token: token,
                    radius: 34,
                  ),
                );
                final identity = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$greeting,',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'DNI: $employeeDni',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: stacked
                        ? Column(
                            children: [
                              photo,
                              const SizedBox(height: 12),
                              identity,
                            ],
                          )
                        : Row(
                            children: [
                              photo,
                              const SizedBox(width: 20),
                              Expanded(child: identity),
                            ],
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            // ── Status pills ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _heroDate(),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                const _LiveClock(),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                DashboardStatusPill(
                  icon: Icons.cloud_done_rounded,
                  text: syncText,
                  background: const Color(0x26FFFFFF),
                  foreground: Colors.white,
                ),
                DashboardStatusPill(
                  icon: Icons.shield_moon_rounded,
                  text: sessionText,
                  background: sessionColor.withAlpha(225),
                  foreground: sessionForeground,
                ),
                DashboardStatusPill(
                  icon: Icons.place_rounded,
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

// ─── Status banner (estilo "Mis Puntos ServiClub") ────────────────────────────

class AttendanceStatusBanner extends StatelessWidget {
  const AttendanceStatusBanner({
    super.key,
    required this.pendingTotal,
    required this.pendingFailed,
    required this.lastClockText,
    required this.hasClockToday,
    required this.hasFreshGps,
    required this.onTap,
  });

  final int pendingTotal;
  final int pendingFailed;
  final String lastClockText;
  final bool hasClockToday;
  final bool hasFreshGps;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasPendingErrors = pendingFailed > 0;
    final hasPending = pendingTotal > 0;

    final Color bg;
    final Color fg;
    final IconData icon;
    final String title;
    final String subtitle;
    final String badge;

    if (hasPendingErrors) {
      bg = const Color(0xFFB71C1C);
      fg = Colors.white;
      icon = Icons.error_rounded;
      title = 'Fichadas con error';
      subtitle = 'Revisar y reintentar';
      badge = '$pendingFailed';
    } else if (hasPending) {
      bg = const Color(0xFFE65100);
      fg = Colors.white;
      icon = Icons.cloud_upload_rounded;
      title = 'Fichadas en cola';
      subtitle = 'Pendientes de sincronización';
      badge = '$pendingTotal';
    } else if (!hasClockToday) {
      bg = const Color(0xFF1565C0);
      fg = Colors.white;
      icon = Icons.qr_code_scanner_rounded;
      title = 'Sin fichar hoy';
      subtitle = 'Escanea el QR para registrar ingreso';
      badge = '!';
    } else {
      bg = const Color(0xFF1B5E20);
      fg = Colors.white;
      icon = Icons.check_circle_rounded;
      title = 'Jornada registrada';
      subtitle = 'Última fichada: $lastClockText';
      badge = 'OK';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.of(context).surface(bg),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.of(
                  context,
                ).surface(Colors.white.withValues(alpha: 0.15)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.of(context).foreground(fg),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.of(context).foreground(fg),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.of(
                        context,
                      ).foreground(fg.withValues(alpha: 0.8)),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.of(
                  context,
                ).surface(Colors.white.withValues(alpha: 0.20)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    badge,
                    style: TextStyle(
                      color: AppColors.of(context).foreground(fg),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.of(context).foreground(fg),
                      size: 18,
                    ),
                  ],
                ],
              ),
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
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.route_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Siguiente paso',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surface(priorityBackground),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    priorityLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.of(
                        context,
                      ).foreground(priorityForeground),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            _FilledActionButton(action: primaryAction),
            if (secondaryAction != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: secondaryAction!.onPressed,
                icon: Icon(secondaryAction!.icon),
                label: Text(
                  secondaryAction!.label,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carrusel de 2x2 tarjetas de stats — muestra todas en una grilla compacta
/// o en PageView de pares si la pantalla es muy angosta.
class AttendanceStatsCarousel extends StatelessWidget {
  const AttendanceStatsCarousel({super.key, required this.items});

  final List<AttendanceStatItem> items;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCards(
      minWidth: 145,
      children: [
        for (final item in items)
          DashboardStatCard(
            title: item.title,
            value: item.value,
            icon: item.icon,
            accent: item.accent,
          ),
      ],
    );
  }
}

class AttendanceClockPanel extends StatelessWidget {
  const AttendanceClockPanel({
    super.key,
    this.sectionTitle,
    this.sectionSubtitle,
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

  final String? sectionTitle;
  final String? sectionSubtitle;
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
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if ((sectionTitle ?? '').isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded),
                  const SizedBox(width: 8),
                  Text(
                    sectionTitle!,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              if ((sectionSubtitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(sectionSubtitle!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.of(context).surface(const Color(0xFFF6F8FB)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.of(context).border(const Color(0xFFD8E1EA)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Preparación de fichada',
                          style: Theme.of(context).textTheme.titleSmall,
                          textAlign: TextAlign.center,
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
                    alignment: WrapAlignment.center,
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
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chequeado $readinessCheckText.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if ((phaseText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.of(context).surface(const Color(0xFFFFF8E1)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.of(
                      context,
                    ).border(const Color(0xFFFFCC02)),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                          color: AppColors.of(
                            context,
                          ).foreground(const Color(0xFF92400E)),
                        ),
                        textAlign: TextAlign.center,
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
              color: mainAction.color ?? AppPalette.blue,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < secondaryActions.length; i++) ...[
                      Expanded(
                        child: _OutlinedActionButton(
                          action: secondaryActions[i],
                        ),
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
              textAlign: TextAlign.center,
            ),
            if ((lastQrText ?? '').trim().isNotEmpty)
              Text(
                'Último QR: $lastQrText',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

/// Grilla de accesos rapidos — 2 columnas en pantallas angostas, 4 en anchas.
class AttendanceQuickActionsCard extends StatelessWidget {
  const AttendanceQuickActionsCard({super.key, required this.items});

  final List<AttendanceQuickActionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.widgets_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Accesos rapidos',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final cols =
                    ((constraints.maxWidth + spacing) /
                            (120 * textScale + spacing))
                        .floor()
                        .clamp(1, 4);
                return Column(
                  children: [
                    for (var start = 0; start < items.length; start += cols)
                      Padding(
                        padding: EdgeInsets.only(top: start == 0 ? 0 : spacing),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var column = 0; column < cols; column++) ...[
                                if (column > 0) const SizedBox(width: spacing),
                                Expanded(
                                  child: start + column < items.length
                                      ? _QuickActionGridItem(
                                          icon: items[start + column].icon,
                                          label: items[start + column].label,
                                          onTap: items[start + column].onTap,
                                          horizontal: cols == 1,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
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

class _QuickActionGridItem extends StatelessWidget {
  const _QuickActionGridItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fg = enabled
        ? cs.onSurfaceVariant
        : cs.onSurface.withValues(alpha: 0.38);
    return Material(
      color: enabled ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outline.withValues(alpha: .65)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: horizontal
              ? Row(
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: AppColors.of(context).foreground(fg),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: AppColors.of(context).foreground(fg),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.of(context).foreground(fg),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Compact readiness strip ───────────────────────────────────────────────────

/// Tira compacta de chips de preparacion de fichada.
/// Reemplaza al [AttendanceClockPanel] en el home para reducir la densidad visual.
class AttendanceReadinessStrip extends StatelessWidget {
  const AttendanceReadinessStrip({
    super.key,
    required this.warming,
    required this.badges,
    this.phaseText,
  });

  final bool warming;
  final List<AttendanceReadinessBadgeData> badges;
  final String? phaseText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allReady = badges.every((b) => b.ready);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  allReady ? Icons.check_circle_rounded : Icons.bolt_rounded,
                  size: 15,
                  color: allReady ? Colors.green.shade700 : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  allReady ? 'Listo para fichar' : 'Preparación',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: allReady
                        ? Colors.green.shade700
                        : cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (warming)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: badges
                  .map(
                    (b) =>
                        AttendanceReadinessChip(text: b.text, ready: b.ready),
                  )
                  .toList(growable: false),
            ),
            if ((phaseText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.of(context).surface(const Color(0xFFFFF8E1)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.of(
                      context,
                    ).border(const Color(0xFFFFCC02)),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phaseText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.of(
                            context,
                          ).foreground(const Color(0xFF92400E)),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    return AppCard(
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: const Text('Diagnóstico y reglas', textAlign: TextAlign.center),
        subtitle: const Text(
          'Información técnica para soporte.',
          textAlign: TextAlign.center,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          if (ruleBadges.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: ruleBadges,
            ),
          if (hasMetrics) ...[
            const SizedBox(height: 10),
            Text(
              'Rendimiento de fichada',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Muestras: $sampleCount${(lastClockText ?? '').trim().isNotEmpty ? ' | Última: $lastClockText' : ''}',
              textAlign: TextAlign.center,
            ),
            if ((lastTotalText ?? '').trim().isNotEmpty)
              Text('Último total: $lastTotalText', textAlign: TextAlign.center),
            if ((lastApiText ?? '').trim().isNotEmpty)
              Text('Última API: $lastApiText', textAlign: TextAlign.center),
            if ((lastGpsText ?? '').trim().isNotEmpty)
              Text('Último GPS: $lastGpsText', textAlign: TextAlign.center),
            if ((lastPhotoText ?? '').trim().isNotEmpty)
              Text('Última foto: $lastPhotoText', textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'Promedio total: $averageTotalText',
              textAlign: TextAlign.center,
            ),
            Text('Promedio API: $averageApiText', textAlign: TextAlign.center),
          ],
          if ((lastQrText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Último QR: $lastQrText', textAlign: TextAlign.center),
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
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text('$label: ${enabled ? "requerido" : "opcional"}'),
      backgroundColor: enabled
          ? cs.primaryContainer
          : cs.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: enabled ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
    );
  }
}

class AttendanceInfoChip extends StatelessWidget {
  const AttendanceInfoChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text(text),
      backgroundColor: cs.secondaryContainer,
      labelStyle: TextStyle(color: cs.onSecondaryContainer),
    );
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
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text(text),
      backgroundColor: ready ? cs.primaryContainer : cs.tertiaryContainer,
      labelStyle: TextStyle(
        color: ready ? cs.onPrimaryContainer : cs.onTertiaryContainer,
      ),
      side: BorderSide(
        color: ready
            ? cs.primary.withValues(alpha: 0.4)
            : cs.tertiary.withValues(alpha: 0.4),
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
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface(background),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.of(context).foreground(foreground),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.of(context).foreground(foreground),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
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
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.of(context).border(accent.withAlpha(95)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.of(context).foreground(accent)),
          const SizedBox(height: 4),
          Text(
            title,
            softWrap: true,
            textAlign: TextAlign.center,
            style: CardTypography.label(context).copyWith(
              color: AppColors.of(context).foreground(const Color(0xFF4F637A)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            softWrap: true,
            textAlign: TextAlign.center,
            style: CardTypography.value(context),
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
    final cs = Theme.of(context).colorScheme;
    final fg = enabled
        ? cs.onSurfaceVariant
        : cs.onSurface.withValues(alpha: 0.38);
    return Material(
      color: enabled ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.of(context).foreground(fg)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.of(context).foreground(fg),
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
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
          backgroundColor: AppColors.of(context).surface(color),
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
            side: BorderSide(
              color: AppColors.of(context).border(Colors.white24),
              width: 1.5,
            ),
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
  const AttendanceReadinessBadgeData({required this.text, required this.ready});

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

// ── Live clock ────────────────────────────────────────────────────────────────

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final h = n.hour.toString().padLeft(2, '0');
    final m = n.minute.toString().padLeft(2, '0');
    // Mostramos HH:MM (sin segundos) para no comprimir la columna del nombre
    // en pantallas angostas.
    return Text(
      '$h:$m',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
      textAlign: TextAlign.center,
    );
  }
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
