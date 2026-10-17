import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/version/app_version_service.dart';
import 'package:ficharqr/src/presentation/version/app_version_gate.dart';
import 'package:ficharqr/src/presentation/widgets/app_startup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final composition = await AssetLottie(
      'assets/branding/fichaya_splash.json',
    ).load();
    expect(composition.duration, const Duration(seconds: 5));
    expect(composition.bounds.width, 1254);
  });
  testWidgets('splash plays once without delaying ready content', (
    tester,
  ) async {
    final ready = Completer<AppVersionCheckResult?>();
    await tester.pumpWidget(
      MaterialApp(
        home: AppVersionGate(
          checkVersion: () => ready.future,
          child: const Scaffold(body: Text('Login listo')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final animation = tester.widget<Lottie>(find.byType(Lottie));
    expect(animation.composition, isNotNull);
    expect(animation.animate, isTrue);
    expect(animation.repeat, isFalse);
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    ready.complete(null);
    await tester.pump();
    expect(find.text('Login listo'), findsOneWidget);
    expect(find.byType(AppStartupScreen), findsNothing);
  });

  testWidgets('nonanimated startup displays completed logo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: AppStartupScreen(animate: false)),
    );
    await tester.pump();
    final animation = tester.widget<Lottie>(find.byType(Lottie));
    expect(animation.controller!.value, 1);
    expect(animation.animate, isFalse);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AppStartupScreen),
      matchesGoldenFile('goldens/startup_lottie_completed.png'),
    );
  });

  testWidgets('small screens and reduced motion remain supported', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: const AppStartupScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final animation = tester.widget<Lottie>(find.byType(Lottie));
    expect(animation.composition, isNotNull);
    expect(animation.controller!.value, 1);
    expect(animation.animate, isFalse);
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      0.75,
    );
    await tester.binding.setSurfaceSize(const Size(640, 320));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Preparando tu acceso…'));
    expect(tester.takeException(), isNull);
  });
}
