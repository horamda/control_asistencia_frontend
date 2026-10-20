import 'app_visual.dart';
import 'app_layout.dart';
import 'app_palette.dart';
import 'package:flutter/material.dart';

/// Shared type and control sizes for every route; system text scaling is preserved.
ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: AppPalette.blue,
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFF8FC3FF) : AppPalette.blue,
        onPrimary: dark ? const Color(0xFF101E30) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF263951)
            : const Color(0xFFE7F0FF),
        onPrimaryContainer: dark
            ? const Color(0xFFB9D8FF)
            : const Color(0xFF0757D6),
        secondaryContainer: dark
            ? const Color(0xFF263951)
            : const Color(0xFFE7F0FF),
        onSecondaryContainer: dark
            ? const Color(0xFFB9D8FF)
            : const Color(0xFF0757D6),
        tertiary: dark ? const Color(0xFFE1A230) : AppPalette.warning,
        onTertiary: dark ? const Color(0xFF211A0D) : Colors.white,
        tertiaryContainer: dark
            ? const Color(0xFF3B301B)
            : const Color(0xFFFFF0D5),
        onTertiaryContainer: dark
            ? const Color(0xFFFFDFA3)
            : const Color(0xFF684000),
        errorContainer: dark
            ? const Color(0xFF44242D)
            : const Color(0xFFFFE9E6),
        onErrorContainer: dark
            ? const Color(0xFFFFB3C1)
            : const Color(0xFF8F1930),
        secondary: dark ? const Color(0xFF7DC8F5) : AppPalette.blueLight,
        surface: dark ? const Color(0xFF202A38) : Colors.white,
        surfaceContainerLowest: dark ? const Color(0xFF111720) : Colors.white,
        surfaceContainerLow: dark
            ? const Color(0xFF263244)
            : const Color(0xFFF7F8FA),
        surfaceContainer: dark
            ? const Color(0xFF2B3748)
            : const Color(0xFFF7F8FA),
        surfaceContainerHigh: dark
            ? const Color(0xFF344257)
            : const Color(0xFFEEF3FF),
        surfaceContainerHighest: dark
            ? const Color(0xFF3E4D63)
            : const Color(0xFFEEF3FF),
        onSurface: dark ? const Color(0xFFF1F5FA) : const Color(0xFF111827),
        onSurfaceVariant: dark ? const Color(0xFFCBD5E1) : AppPalette.muted,
        outline: dark ? const Color(0xFF94A3B8) : const Color(0xFF737B89),
        outlineVariant: dark ? const Color(0xFF65758A) : AppPalette.border,
        error: dark ? const Color(0xFFFF8FA3) : AppPalette.danger,
      );
  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: colors.outlineVariant),
  );
  final buttonStyle = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xFF111720)
        : AppPalette.background,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 32,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: AppVisual.sectionTitle,
          titleSmall: const TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
          bodyMedium: AppVisual.body,
          bodySmall: const TextStyle(fontSize: 13, height: 1.4),
          labelLarge: const TextStyle(
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: const TextStyle(
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: const TextStyle(
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(
        color: colors.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      errorMaxLines: 3,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppVisual.cardRadius),
        side: BorderSide(
          color: dark
              ? colors.outline.withValues(alpha: .65)
              : colors.outlineVariant,
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: buttonStyle.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? null : AppPalette.blue,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? null : Colors.white,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppVisual.cardRadius),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 10,
      titleTextStyle: base.textTheme.titleMedium?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
        height: 1.4,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceContainerLow,
      selectedColor: colors.primaryContainer,
      side: BorderSide(color: colors.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        color: colors.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: const BoxConstraints(maxWidth: 840),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, thickness: 1),
    tabBarTheme: const TabBarThemeData(
      labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      dividerHeight: 0,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF202A38),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(fontSize: 14, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Keeps routes readable on wide desktops, while all navigation and dialogs use
/// the same constrained viewport and the original accessibility text scaler.
class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth > AppLayout.viewportMaxWidth
          ? AppLayout.viewportMaxWidth
          : box.maxWidth;
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: SizedBox(
            width: width,
            height: box.maxHeight,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(size: Size(width, box.maxHeight)),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// A wrapping layout with natural-height cards, including at large text sizes.
class ResponsiveCards extends StatelessWidget {
  const ResponsiveCards({
    super.key,
    required this.children,
    this.minWidth = 260,
    this.maxColumns = 4,
  });
  final List<Widget> children;
  final double minWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = AppLayout.columns(
        context,
        box.maxWidth,
        minWidth: minWidth,
        maxColumns: maxColumns,
      );
      final width = (box.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
