import 'package:flutter/material.dart';

/// Logical pixels, never physical display resolution. Accessibility can reduce
/// the column count without shrinking text or recreating the route.
abstract final class AppLayout {
  static const compactWidth = 600.0;
  static const expandedWidth = 840.0;
  static const pageMaxWidth = 1040.0;
  static const viewportMaxWidth = 1440.0;
  static const gap = 12.0;
  static const touchTarget = 48.0;

  static int columns(
    BuildContext context,
    double width, {
    required double minWidth,
    int maxColumns = 4,
    double spacing = gap,
  }) {
    if (!width.isFinite || width <= 0) return 1;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return ((width + spacing) / (minWidth * scale + spacing)).floor().clamp(
      1,
      maxColumns,
    );
  }

  static bool keyboardVisible(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom > 0;
}
