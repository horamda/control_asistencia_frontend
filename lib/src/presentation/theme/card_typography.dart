import 'package:flutter/material.dart';

/// Shared card hierarchy; accessibility text scaling remains controlled by Flutter.
abstract final class CardTypography {
  static double _size(BuildContext context, double compact, double regular) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    final progress = ((width - 320) / 280).clamp(0.0, 1.0);
    return compact + (regular - compact) * progress;
  }

  static TextStyle label(BuildContext context) => TextStyle(
    fontSize: _size(context, 13, 15),
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static TextStyle value(BuildContext context) => TextStyle(
    fontSize: _size(context, 20, 26),
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  static TextStyle indicator(BuildContext context) => TextStyle(
    fontSize: _size(context, 18, 22),
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
}
