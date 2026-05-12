import 'package:cached_network_image/cached_network_image.dart';

import 'employee_photo_cache_manager.dart';

class ProfilePhotoCache {
  ProfilePhotoCache._();

  /// Agrega el query param `?v={version}` a [rawUrl] para invalidar el cache
  /// cuando la imagen cambia.
  ///
  /// Devuelve cadena vacía si:
  ///   - [rawUrl] es nulo o vacío
  ///   - La URL no tiene esquema (URL relativa como `/uploads/foto.jpg`) —
  ///     estas no pueden ser descargadas por [CachedNetworkImage] sin base.
  static String withVersion(String? rawUrl, {int? version}) {
    final clean = (rawUrl ?? '').trim();
    if (clean.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(clean);
    if (uri == null) {
      return '';
    }

    // URL relativa (sin esquema) → no se puede usar directamente.
    // El llamador debería usar el fallback en su lugar.
    if (!uri.hasScheme || uri.scheme.isEmpty) {
      return '';
    }

    final query = Map<String, String>.from(uri.queryParameters);
    final safeVersion = version;
    if (safeVersion != null && safeVersion > 0) {
      query['v'] = safeVersion.toString();
    }
    return uri.replace(queryParameters: query).toString();
  }

  /// Resuelve la URL final de la foto de un empleado.
  ///
  /// Prioridad:
  ///   1. [rawUrl] si es absoluta y no vacía (se le agrega `?v={version}`)
  ///   2. [fallbackBuilder(dni, version)] si [rawUrl] no sirve y [dni] está
  ///      presente — funciona incluso con [version] nulo.
  ///   3. Cadena vacía (sin foto)
  static String resolve({
    String? rawUrl,
    String? dni,
    int? version,
    String Function(String dni, int version)? fallbackBuilder,
  }) {
    final fromRaw = withVersion(rawUrl, version: version);
    if (fromRaw.isNotEmpty) {
      return fromRaw;
    }

    final safeDni = (dni ?? '').trim();
    if (fallbackBuilder == null || safeDni.isEmpty) {
      return '';
    }
    // buildEmpleadoImagenUrl maneja version = 0 / null omitiendo el ?v= param.
    return fallbackBuilder.call(safeDni, version ?? 0);
  }

  /// Elimina la imagen del **cache en disco** ([EmployeePhotoCacheManager])
  /// y del **cache en memoria** de Flutter, para que la próxima vez se
  /// descargue la versión actualizada.
  ///
  /// Llamar a esto antes de reemplazar la foto del perfil evita que el widget
  /// muestre la imagen vieja cacheada en lugar de la nueva.
  static Future<void> evict(String? rawUrl, {int? version}) async {
    final resolved = withVersion(rawUrl, version: version);
    if (resolved.isEmpty) {
      return;
    }
    await Future.wait([
      // Cache en disco (EmployeePhotoCacheManager — el que usa EmployeePhotoWidget).
      EmployeePhotoCacheManager.instance
          .removeFile(resolved)
          .then<void>((_) {})
          .onError<Object>((_, __) {}),
      // Cache en memoria de Flutter (ImageCache).
      CachedNetworkImage.evictFromCache(resolved)
          .then<void>((_) {})
          .onError<Object>((_, __) {}),
    ]);
  }
}
