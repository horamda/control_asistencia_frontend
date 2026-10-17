import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/theme/theme_preferences.dart';
import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'package:ficharqr/src/presentation/attendance/widgets/attendance_dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Card content inherits centered text, including child widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: AppCard(
            child: Padding(padding: EdgeInsets.all(16), child: _CardData()),
          ),
        ),
      ),
    );
    final text = tester.renderObject<RenderParagraph>(
      find.text('Datos de la tarjeta'),
    );
    expect(text.textAlign, TextAlign.center);
    final card = tester.getRect(find.byType(Card));
    final content = tester.getRect(find.byType(_CardData));
    expect(content.center.dx, closeTo(card.center.dx, .1));
  });

  testWidgets('Metric titles and values remain centered with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: DashboardStatCard(
                title: 'Asistencias registradas',
                value: '128',
                icon: Icons.check_circle,
                accent: Colors.green,
              ),
            ),
          ),
        ),
      ),
    );
    for (final label in ['Asistencias registradas', '128']) {
      expect(
        tester.renderObject<RenderParagraph>(find.text(label)).textAlign,
        TextAlign.center,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Appearance selector changes theme and saves the choice', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await ThemePreferences.instance.setMode(ThemeMode.system);
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: ThemePreferences.instance,
        builder: (context, _) => MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: ThemePreferences.instance.mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const AppearancePage(),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Oscuro'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(AppearancePage))).brightness,
      Brightness.dark,
    );
    final reloaded = ThemePreferences();
    await reloaded.load();
    expect(reloaded.mode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });
}

class _CardData extends StatelessWidget {
  const _CardData();
  @override
  Widget build(BuildContext context) => const Text('Datos de la tarjeta');
}
