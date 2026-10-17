import 'package:ficharqr/src/presentation/theme/app_palette.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/theme/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'Appearance persists across controllers and defaults to system',
    () async {
      final first = ThemePreferences();
      await first.load();
      expect(first.mode, ThemeMode.system);
      await first.setMode(ThemeMode.dark);
      final restarted = ThemePreferences();
      await restarted.load();
      expect(restarted.mode, ThemeMode.dark);
      await restarted.setMode(ThemeMode.light);
      final third = ThemePreferences();
      await third.load();
      expect(third.mode, ThemeMode.light);
    },
  );

  test('Unknown saved appearance falls back to system', () async {
    FlutterSecureStorage.setMockInitialValues({
      ThemePreferences.storageKey: 'invalid',
    });
    final preferences = ThemePreferences();
    await preferences.load();
    expect(preferences.mode, ThemeMode.system);
  });

  test('Latest selection wins while loading and writing', () async {
    FlutterSecureStorage.setMockInitialValues({
      ThemePreferences.storageKey: 'light',
    });
    final preferences = ThemePreferences();
    final loading = preferences.load();
    final first = preferences.setMode(ThemeMode.light);
    final last = preferences.setMode(ThemeMode.dark);
    await Future.wait([loading, first, last]);
    expect(preferences.mode, ThemeMode.dark);
    final restarted = ThemePreferences();
    await restarted.load();
    expect(restarted.mode, ThemeMode.dark);
  });

  testWidgets(
    'System appearance follows device; explicit choice overrides it',
    (tester) async {
      final preferences = ThemePreferences();
      Brightness? current;
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: preferences,
          builder: (context, _) => MaterialApp(
            theme: buildAppTheme(),
            darkTheme: buildAppTheme(brightness: Brightness.dark),
            themeMode: preferences.mode,
            home: Builder(
              builder: (context) {
                current = Theme.of(context).brightness;
                return const Scaffold(body: Text('FichaYa'));
              },
            ),
          ),
        ),
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(current, Brightness.dark);
      await preferences.setMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(current, Brightness.light);
      await preferences.setMode(ThemeMode.system);
      await tester.pumpAndSettle();
      expect(current, Brightness.dark);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('Backend palette and readable cards in $brightness', (
      tester,
    ) async {
      final theme = buildAppTheme(brightness: brightness);
      final dark = brightness == Brightness.dark;
      expect(
        theme.scaffoldBackgroundColor,
        Color(dark ? 0xFF111720 : 0xFFF0F2F5),
      );
      expect(theme.colorScheme.surface, Color(dark ? 0xFF202A38 : 0xFFFFFFFF));
      expect(theme.colorScheme.primary, Color(dark ? 0xFF8FC3FF : 0xFF0866FF));
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
      }

      final scheme = theme.colorScheme;
      if (dark) {
        for (final surface in [
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainerHighest,
        ]) {
          expect(
            contrast(scheme.onSurfaceVariant, surface),
            greaterThanOrEqualTo(4.5),
          );
          expect(contrast(scheme.primary, surface), greaterThanOrEqualTo(4.5));
        }
        expect(
          contrast(scheme.outlineVariant, scheme.surface),
          greaterThanOrEqualTo(3),
        );
      }
      expect(
        contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(Colors.white, AppPalette.blue),
        greaterThanOrEqualTo(4.5),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              final colors = AppColors.of(context);
              expect(colors.surface(Colors.white), scheme.surface);
              for (final status in [
                AppPalette.success,
                AppPalette.warning,
                AppPalette.danger,
              ]) {
                expect(
                  contrast(colors.foreground(status), scheme.surface),
                  greaterThanOrEqualTo(4.5),
                );
              }
              return const Scaffold();
            },
          ),
        ),
      );
    });
  }
}
