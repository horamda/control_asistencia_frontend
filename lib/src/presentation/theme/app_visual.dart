import 'package:flutter/material.dart';

/// Visual foundation adopted progressively, starting with the home screen.
/// Sizes are logical pixels; Flutter retains the user's text scaling.
abstract final class AppVisual {
  static const cardRadius = 16.0;
  static const cardPadding = 16.0;
  static const sectionGap = 16.0;
  static const actionHeight = 64.0;

  static const identity = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  static const sectionTitle = TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(fontSize: 14, height: 1.35);
  static const caption = TextStyle(fontSize: 12, height: 1.35);
}
