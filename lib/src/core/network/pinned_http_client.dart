import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../utils/app_logger.dart';

/// Crea un [http.Client] con certificate pinning a nivel Dart (BoringSSL).
///
/// En Android el pinning ya esta cubierto por [network_security_config.xml] a
/// nivel de SO. Este cliente agrega una segunda capa valida también en iOS y
/// garantiza coherencia entre plataformas.
///
/// Estrategia: [SecurityContext] con trusted roots deshabilitados + solo el
/// certificado CA definido en [_caCertAssetPath].  Cualquier conexion cuyo
/// certificado NO este firmado por esa CA sera rechazada por BoringSSL antes
/// de enviar datos.
///
/// Como actualizar el pin:
///   1. Obtener el certificado CA del backend:
///        openssl s_client -connect HOST:443 -showcerts 2>/dev/null \
///          | awk '/BEGIN CERT/{f=1} f{print} /END CERT/{f=0}' | tail -n +4
///   2. Reemplazar el archivo [_caCertAssetPath] en assets/certs/.
///   3. Actualizar tambien los pines en android/app/src/main/res/xml/network_security_config.xml.
///   4. Publicar nueva version de la app antes de que expire el certificado viejo.
class PinnedHttpClient {
  static final _log = AppLogger.get('PinnedHttpClient');

  /// Ruta del asset con el certificado CA en formato PEM.
  /// Debe ser la CA raiz (o intermediaria) que firma el certificado del backend.
  static const _caCertAssetPath = 'assets/certs/backend_ca.pem';

  /// Intenta crear un cliente con SecurityContext restringido.
  /// Si falla (asset no presente, PEM invalido), devuelve un [http.Client]
  /// estandar como fallback — en Android el NSC sigue protegiendo.
  static Future<http.Client> create() async {
    try {
      final pemBytes = await rootBundle.load(_caCertAssetPath);
      final context = SecurityContext(withTrustedRoots: false);
      context.setTrustedCertificatesBytes(pemBytes.buffer.asUint8List());
      final httpClient = HttpClient(context: context);
      httpClient.connectionTimeout = const Duration(seconds: 15);
      _log.info('Certificate pinning activo (SecurityContext)');
      return IOClient(httpClient);
    } catch (e, st) {
      // Si el asset no existe o el PEM es invalido, loguear y usar cliente
      // estandar. En Android el NSC sigue aplicando; en iOS no hay pinning
      // hasta que se agregue el archivo de certificado.
      _log.warning(
        'No se pudo activar SecurityContext pinning — usando cliente estandar. '
        'Agrega el cert CA en $_caCertAssetPath para activar pinning en iOS.',
        e,
        st,
      );
      return http.Client();
    }
  }
}
