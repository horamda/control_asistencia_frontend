import 'package:flutter_test/flutter_test.dart';
import 'package:ficharqr/src/core/network/mobile_api_client.dart';
void main() {
  test('marcas reconoce correcciones e historial virtual sin romper versiones previas', () {
    final old=MarcaItem.fromJson({'id':1,'metodo':'qr'});
    expect(old.corregidaManualmente,false);
    expect(old.esResumen,false);
    final edited=MarcaItem.fromJson({'id':1,'metodo':'qr','corregida_manualmente':true});
    expect(edited.corregidaManualmente,true);
    expect(edited.metodo,'qr');
    final legacy=MarcaItem.fromJson({'id':-20,'asistencia_id':10,'es_resumen':true});
    expect(legacy.id,-20);
    expect(legacy.asistenciaId,10);
    expect(legacy.esResumen,true);
  });
}
