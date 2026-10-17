import 'package:flutter/material.dart';
import 'package:ficharqr/src/presentation/trivia/ranking_entry_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
import 'package:ficharqr/src/presentation/theme/app_theme.dart';
import 'package:ficharqr/src/presentation/trivia/trivia_ranking_screen.dart';
import 'package:ficharqr/src/presentation/trivia/trivia_annual_ranking_screen.dart';

final entry = <String, dynamic>{
  'posicion': 1,
  'empleado_id': 1,
  'empleado_nombre': 'Maria Alejandra Fernandez de los Santos',
  'sector': 'Administracion y operaciones de todas las sucursales',
  'puntos_total': 123456,
  'tiempo_total_segundos': 9876,
  'puntos_anuales': 123456,
  'correctas_totales': 12345,
  'trivias_ganadas': 123,
  'trivias_participadas': 456,
};

class _Api extends MobileApiClient {
  _Api() : super(baseUrl: 'https://example.test');
  @override
  Future<TriviaRankingResponse> getRankingTrivia({
    required String token,
    required int triviaId,
  }) async => TriviaRankingResponse.fromJson({
    'trivia': {
      'id': 1,
      'titulo': 'Trivia de conocimientos y seguridad de todas las sucursales',
    },
    'ranking': [entry],
  });
  @override
  Future<TriviaRankingAnualResponse> getRankingAnual({
    required String token,
    required int anio,
  }) async => TriviaRankingAnualResponse.fromJson({
    'anio': anio,
    'data': [entry],
  });
  @override
  Future<TriviaGanadorAnualResponse> getGanadorAnual({
    required String token,
    required int anio,
  }) async => TriviaGanadorAnualResponse.fromJson(entry);
}

void main() {
  for (final width in [320.0, 360.0, 412.0, 800.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final annual in [false, true]) {
        testWidgets('Ranking annual=$annual width=$width scale=$scale', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final api = _Api();
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(brightness: Brightness.dark),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: annual
                  ? TriviaAnnualRankingScreen(
                      apiClient: api,
                      token: 'test',
                      anio: 2026,
                      empleadoDni: '1',
                    )
                  : TriviaRankingScreen(
                      apiClient: api,
                      token: 'test',
                      triviaId: 1,
                      empleadoDni: '1',
                    ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.descendant(
              of: find.byType(RankingEntryLayout),
              matching: find.text('123456 pts'),
            ),
            250,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(entry['empleado_nombre'] as String), findsWidgets);
        });
      }
    }
  }
}
