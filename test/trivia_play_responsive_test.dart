import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/trivia/trivia_play_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('trivia opciones largas y rotacion dark=$dark', (tester) async {
      final api = MobileApiClient(baseUrl: 'https://test.invalid');
      addTearDown(api.dispose);
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const option =
          'Una respuesta extensa que debe seguir siendo legible y seleccionable en todos los dispositivos';
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: TriviaPlayScreen(
            apiClient: api,
            token: 'test',
            triviaId: 1,
            titulo: 'Trivia de seguridad laboral',
            empleadoDni: 'test',
            preguntas: const [
              TriviaQuestion(
                id: 1,
                texto:
                    'Primera pregunta con una descripcion extensa sobre las medidas de seguridad necesarias para el trabajo diario',
                opcionA: 'Respuesta A: $option',
                opcionB: option,
                opcionC: option,
                opcionD: option,
              ),
              TriviaQuestion(
                id: 2,
                texto: 'Segunda pregunta',
                opcionA: 'Respuesta A: $option',
                opcionB: option,
                opcionC: option,
                opcionD: option,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('A'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      for (final size in [
        const Size(740, 360),
        const Size(800, 1024),
        const Size(320, 640),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Siguiente pregunta'));
      await tester.pumpAndSettle();
      expect(find.text('Pregunta 2 de 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
