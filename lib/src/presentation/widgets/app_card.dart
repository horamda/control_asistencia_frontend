import 'package:flutter/material.dart';

/// Shared alignment for card data, including content supplied by child widgets.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.child,
    this.margin,
    this.clipBehavior,
    this.color,
    this.shape,
    this.elevation,
    this.shadowColor,
  });
  final Widget? child;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;
  final Color? color, shadowColor;
  final ShapeBorder? shape;
  final double? elevation;

  @override
  Widget build(BuildContext context) => Card(
    margin: margin,
    clipBehavior: clipBehavior,
    color: color,
    shape: shape,
    elevation: elevation,
    shadowColor: shadowColor,
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
