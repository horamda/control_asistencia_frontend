import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/feedback/app_rating_service.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/widgets/app_rating_dialog.dart';

void main() {
  for (final width in [320.0, 440.0, 800.0]) {
    testWidgets('rating fits $width with large text and keyboard', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = MobileApiClient(baseUrl: 'https://example.test');
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 260),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppRatingDialog(
                  context,
                  ratingService: AppRatingService(
                    apiClient: api,
                    token: 'test',
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final star = find.byTooltip('5 de 5 estrellas');
      await tester.ensureVisible(star);
      await tester.tap(star);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Funciona bien');
      await tester.ensureVisible(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
