import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/widgets/app_page_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(740, 360),
    const Size(1920, 1080),
  ]) {
    testWidgets(
      'floating actions remain readable and leave scroll clearance at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: AppViewport(child: child!),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                floatingActionButton: AppFloatingActionButton(
                  onPressed: () => pressed = true,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Marcar novedades como vistas'),
                ),
                body: AppPageBody(
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: AppFloatingActionButton.bottomPadding(context),
                    ),
                    children: [
                      for (var i = 0; i < 20; i++)
                        ListTile(title: Text('Elemento $i')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final action = find.byType(AppFloatingActionButton);
        final rect = tester.getRect(action);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        await tester.tap(find.text('Marcar novedades como vistas'));
        expect(pressed, isTrue);
        await tester.scrollUntilVisible(
          find.text('Elemento 19'),
          500,
          scrollable: find.byType(Scrollable),
        );
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Elemento 19')).bottom,
          lessThan(rect.top),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
