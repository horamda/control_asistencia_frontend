import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class EmployeePhotoCacheManager {
  EmployeePhotoCacheManager._();

  static const String _cacheKey = 'employee_photo_cache_v1';
  static const Duration _stalePeriod = Duration(days: 30);

  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: _stalePeriod,
      maxNrOfCacheObjects: 200,
      // FileService custom que ignora los Cache-Control del servidor.
      // Sin esto, si el backend responde con max-age corto (ej: 60s),
      // flutter_cache_manager lo respeta y vuelve a descargar en cada sesion.
      fileService: _LongCacheFileService(stalePeriod: _stalePeriod),
    ),
  );
}

/// [FileService] que descarga con [HttpFileService] pero reemplaza el
/// [validTill] de la respuesta por [stalePeriod], ignorando los headers
/// Cache-Control del servidor. La foto de perfil no cambia salvo que el
/// empleado la actualice (en ese caso se evicta manualmente via
/// [ProfilePhotoCache.evict]).
class _LongCacheFileService extends FileService {
  _LongCacheFileService({required this.stalePeriod});

  final Duration stalePeriod;
  final _inner = HttpFileService();

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _inner.get(url, headers: headers);
    return _OverriddenValidTillResponse(
      response,
      validTill: DateTime.now().add(stalePeriod),
    );
  }
}

class _OverriddenValidTillResponse implements FileServiceResponse {
  _OverriddenValidTillResponse(this._inner, {required this.validTill});

  final FileServiceResponse _inner;

  @override
  final DateTime validTill;

  @override
  Stream<List<int>> get content => _inner.content;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;

  @override
  int get statusCode => _inner.statusCode;
}
