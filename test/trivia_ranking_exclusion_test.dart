import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';

void main() {
  test('sin ranking por trivia conserva puntaje y acepta versiones anteriores', () {
    for (final excluded in [false, true]) {
      final json = <String, dynamic>{'trivia_id': 1, 'puntos_total': 80,
        if (excluded) 'fuera_ranking': true};
      final p = TriviaParticipacion.fromJson(json);
      final f = TriviaFinalizarResponse.fromJson({'data': json});
      final h = TriviaMyHistorialItem.fromJson(json);
      expect(p.fueraRanking, excluded);
      expect(f.fueraRanking, excluded);
      expect(h.fueraRanking, excluded);
      expect(p.puntosTotal, 80);
      expect(f.puntosTotal, 80);
      expect(h.puntosTotal, 80);
    }
  });
}
