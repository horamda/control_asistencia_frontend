import '../theme/app_layout.dart';
import 'package:ficharqr/src/presentation/theme/app_palette.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Equal-width actions that stack when space or accessibility text requires it.
class AppAdaptiveActions extends StatelessWidget {
  const AppAdaptiveActions({
    super.key,
    required this.children,
    this.minWidth = 180,
  });
  final List<Widget> children;
  final double minWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (children.isEmpty) return const SizedBox.shrink();
      final columns = AppLayout.columns(
        context,
        box.maxWidth,
        minWidth: minWidth,
        maxColumns: children.length,
      );
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: width,
              child: DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                child: child,
              ),
            ),
        ],
      );
    },
  );
}

/// Keeps forms and lists readable while the background fills the screen.
class AppPageBody extends StatelessWidget {
  const AppPageBody({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.pageMaxWidth,
  });
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

/// Floating action with the vacation screen's appearance, but natural height
/// so long labels and accessibility text sizes stay inside the viewport.
class AppFloatingActionButton extends StatelessWidget {
  const AppFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tooltip,
  });
  final VoidCallback? onPressed;
  final Widget icon, label;
  final String? tooltip;

  static double bottomPadding(BuildContext context) =>
      math.max(96, 64 + MediaQuery.textScalerOf(context).scale(80)) +
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final disabled = onPressed == null;
    final foreground = disabled
        ? colors.onSurfaceVariant
        : colors.onPrimaryContainer;
    final button = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(
          440,
          math.max(0, MediaQuery.sizeOf(context).width - 32),
        ),
        minHeight: 56,
      ),
      child: Material(
        elevation: disabled ? 0 : 3,
        color: disabled
            ? colors.surfaceContainerHighest
            : colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          enabled: !disabled,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: IconTheme(
                data: IconThemeData(
                  color: AppColors.of(context).foreground(foreground),
                  size: 24,
                ),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: AppColors.of(context).foreground(foreground),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 10),
                      Flexible(child: label),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
