import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/widgets/app_submission_bar.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 640),
      const Size(740, 360),
      const Size(800, 1024),
    ]) {
      testWidgets(
        'submission remains reachable $brightness $size with keyboard',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var sent = false;
          final keyboard = ValueNotifier(0.0);
          addTearDown(keyboard.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(brightness: brightness),
              home: ValueListenableBuilder<double>(
                valueListenable: keyboard,
                builder: (context, inset, _) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    viewInsets: EdgeInsets.only(bottom: inset),
                  ),
                  child: Scaffold(
                    body: const TextField(),
                    bottomNavigationBar: AppSubmissionBar(
                      summary: 'Total ARS 2500',
                      actions: [
                        OutlinedButton(
                          onPressed: () {},
                          child: const Text('Guardar borrador'),
                        ),
                        FilledButton(
                          onPressed: () => sent = true,
                          child: const Text('Enviar solicitud'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Total ARS 2500'), findsOneWidget);
          keyboard.value = 160;
          await tester.pumpAndSettle();
          expect(find.text('Total ARS 2500'), findsNothing);
          await tester.ensureVisible(find.text('Enviar solicitud'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Enviar solicitud'));
          expect(sent, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
