import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/presentation/widgets/croppable_image.dart';

void main() {
  testWidgets(
    'recorte adaptable conserva controles y resultado al redimensionar',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? result;
      var initialized = 0;
      await tester.binding.setSurfaceSize(const Size(1041, 602));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => ResponsiveCropDialog(
                      title: 'Recortar adjunto',
                      cropper: const ColoredBox(color: Colors.grey),
                      initialize: () => initialized++,
                      crop: () async => 'blob:cropped',
                      rotate: (_) {},
                      scale: (_) {},
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      for (final size in [
        const Size(1041, 602),
        const Size(390, 600),
        const Size(640, 320),
        const Size(320, 480),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['Cancelar', 'Usar']) {
          final rect = tester.getRect(find.text(label));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(find.text(label).hitTestable(), findsOneWidget);
        }
      }
      expect(initialized, 1);
      await tester.tap(find.text('Usar'));
      await tester.pumpAndSettle();
      expect(result, 'blob:cropped');
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );
}
