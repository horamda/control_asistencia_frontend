import 'package:flutter/material.dart';

/// Brand and semantic colors shared by the application.
abstract final class AppPalette {
  // Source: backend/static/css/panel.css and panel-theme.css.
  static const navy = Color(0xFF0757D6);
  static const blue = Color(0xFF0866FF);
  static const blueLight = Color(0xFF1F5F8F);
  static const background = Color(0xFFF0F2F5);
  static const success = Color(0xFF1E7A4F);
  static const danger = Color(0xFFB32135);
  static const warning = Color(0xFF855000);
  static const border = Color(0xFFDADDE1);
  static const muted = Color(0xFF5F6774);
  static const brandGradient = [navy, blue, blueLight];
}

/// Adapts module-specific status colors to the panel's light/dark surfaces.
/// White labels on solid banners and camera overlays remain white.
class AppColors {
  AppColors.of(BuildContext context) : scheme = Theme.of(context).colorScheme;
  final ColorScheme scheme;
  bool get isDark => scheme.brightness == Brightness.dark;

  List<Color> get brandGradient => isDark
      ? const [Color(0xFF203653), Color(0xFF2B4562)]
      : AppPalette.brandGradient;

  Color? optionalForeground(Color? color) =>
      color == null ? null : foreground(color);
  Color? optionalSurface(Color? color) => color == null ? null : surface(color);
  Color? optionalBorder(Color? color) => color == null ? null : border(color);

  Color foreground(Color color) {
    if (color.a < .5 || color == Colors.transparent) return color;
    if (color.r > .94 && color.g > .94 && color.b > .94) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < .18) {
      return (hsl.lightness < .25 ? scheme.onSurface : scheme.onSurfaceVariant)
          .withValues(alpha: color.a);
    }
    if (!isDark) return color;
    if (color == AppPalette.success) return const Color(0xFF6EE7A0);
    if (color == AppPalette.warning) return const Color(0xFFF6C76B);
    if (color == AppPalette.danger) return const Color(0xFFFF8FA3);
    if (color == AppPalette.blue || color == AppPalette.navy) {
      return scheme.primary;
    }
    return hsl.withLightness(hsl.lightness.clamp(.68, .85)).toColor();
  }

  Color surface(Color color) {
    if (color.a < .5 || color == Colors.transparent) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < .72) return color; // Solid banners retain white labels.
    if (hsl.saturation < .2 || hsl.lightness > .97) return scheme.surface;
    if (!isDark) return color;
    return Color.alphaBlend(
      hsl.withLightness(.6).toColor().withValues(alpha: .14),
      scheme.surface,
    );
  }

  Color border(Color color) =>
      isDark && color.a >= .5 ? scheme.outlineVariant : color;
}
