import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/version/app_version_service.dart';
import 'package:ficharqr/src/presentation/version/app_version_gate.dart';

AppVersionCheckResult result(AppVersionStatus status, {String? url}) =>
    AppVersionCheckResult(
      status: status,
      currentVersion: '1.0.0',
      versionMinima: '2.0.0',
      versionRecomendada: '2.1.0',
      urlDescarga: url,
    );

void main() {
  for (final url in [null, '', '   ', 'https://example.test/update']) {
    testWidgets('versión obligatoria bloquea sin montar la app: $url', (
      tester,
    ) async {
      var childBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AppVersionGate(
            checkVersion: () async =>
                result(AppVersionStatus.updateRequired, url: url),
            child: Builder(
              builder: (_) {
                childBuilds++;
                return const Text('Contenido privado');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Actualización requerida'), findsOneWidget);
      expect(find.text('Entendido'), findsNothing);
      expect(childBuilds, 0);
      expect(
        find.text('Actualizar ahora'),
        url?.trim().isNotEmpty == true ? findsOneWidget : findsNothing,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Actualización requerida'), findsOneWidget);
      expect(childBuilds, 0);
    });
  }

  testWidgets('actualización recomendada permite continuar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppVersionGate(
          checkVersion: () async => result(AppVersionStatus.updateRecommended),
          child: const Scaffold(body: Text('Contenido privado')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Más tarde'));
    await tester.pumpAndSettle();
    expect(find.text('Contenido privado'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final value in [null, result(AppVersionStatus.upToDate)]) {
    testWidgets(
      'permite acceso sin actualización requerida: ${value?.status}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AppVersionGate(
              checkVersion: () async => value,
              child: const Text('Contenido privado'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Contenido privado'), findsOneWidget);
      },
    );
  }
}
