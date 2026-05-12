import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';

class MobileApiClient {
  static final _log = AppLogger.get('MobileApiClient');

  MobileApiClient({
    required this.baseUrl,
    this.mobileApiPrefix = '/api/v1/mobile',
    http.Client? httpClient,
  })
    : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String mobileApiPrefix;
  http.Client _httpClient;
  String? Function()? _tokenProvider;
  Future<String?> Function(String expiredToken)? _onUnauthorizedRefresh;
  Future<void> Function()? _onUnauthorized;

  void configureAuth({
    String? Function()? tokenProvider,
    Future<String?> Function(String expiredToken)? onUnauthorizedRefresh,
    Future<void> Function()? onUnauthorized,
  }) {
    _tokenProvider = tokenProvider;
    _onUnauthorizedRefresh = onUnauthorizedRefresh;
    _onUnauthorized = onUnauthorized;
  }

  /// Reemplaza el cliente HTTP subyacente por uno con certificate pinning.
  /// Llamar una sola vez, justo despues de que [PinnedHttpClient.create]
  /// resuelva. Las solicitudes en vuelo no se ven afectadas.
  void upgradeHttpClient(http.Client pinnedClient) {
    _httpClient.close();
    _httpClient = pinnedClient;
    _log.info('HTTP client actualizado con certificate pinning');
  }

  Future<LoginResponse> login({
    required String dni,
    required String password,
  }) async {
    final response = await _safePost(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({'dni': dni, 'password': password}),
      actionLabel: 'iniciar sesión',
      allowAuthRecovery: false,
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo iniciar sesión.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }

    final json = _decodeObject(response.body);
    final token = json['token'];
    final empleadoJson = json['empleado'];

    if (token is! String || empleadoJson is! Map) {
      throw ApiException(
        message: 'Respuesta invalida del servidor en login.',
        statusCode: response.statusCode,
      );
    }

    return LoginResponse(
      token: token,
      empleado: EmployeeSummary.fromJson(
        Map<String, dynamic>.from(empleadoJson),
      ),
    );
  }

  Future<AttendanceConfig> getConfigAsistencia({required String token}) async {
    final response = await _safeGet(
      _uri('/me/config-asistencia'),
      headers: _headers(token: token),
      actionLabel: 'consultar configuración de asistencia',
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener la configuración de asistencia.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }

    final json = _decodeObject(response.body);
    return AttendanceConfig.fromJson(json);
  }

  Future<String> refreshToken({required String token}) async {
    final response = await _safePost(
      _uri('/auth/refresh'),
      headers: _headers(token: token),
      body: jsonEncode(<String, dynamic>{}),
      actionLabel: 'renovar sesión',
      allowAuthRecovery: false,
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo renovar la sesión.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }

    final json = _decodeObject(response.body);
    final newToken = json['token'];
    if (newToken is! String || newToken.trim().isEmpty) {
      throw ApiException(
        message: 'Respuesta inválida del servidor al renovar sesión.',
        statusCode: response.statusCode,
      );
    }
    return newToken.trim();
  }

  Future<EmployeeProfile> getMe({required String token}) async {
    final response = await _safeGet(
      _uri('/me'),
      headers: _headers(token: token),
      actionLabel: 'consultar perfil',
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el perfil.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }

    return EmployeeProfile.fromJson(_decodeObject(response.body));
  }

  String buildEmpleadoImagenUrl({required String dni, int? version}) {
    final safeDni = dni.trim();
    if (safeDni.isEmpty) {
      return '';
    }
    final base = _rootUri('/empleados/imagen/${Uri.encodeComponent(safeDni)}');
    final safeVersion = version;
    if (safeVersion == null || safeVersion <= 0) {
      return base.toString();
    }
    return base
        .replace(
          queryParameters: <String, String>{'v': safeVersion.toString()},
        )
        .toString();
  }

  Future<AsistenciasPageResult> getAsistencias({
    required String token,
    int page = 1,
    int per = 20,
    String? desde,
    String? hasta,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    final cleanDesde = desde?.trim();
    final cleanHasta = hasta?.trim();
    if (cleanDesde != null && cleanDesde.isNotEmpty) {
      query['desde'] = cleanDesde;
    }
    if (cleanHasta != null && cleanHasta.isNotEmpty) {
      query['hasta'] = cleanHasta;
    }

    final response = await _safeGet(
      _uri('/me/asistencias').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'consultar historial de asistencias',
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener asistencias.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }

    return AsistenciasPageResult.fromJson(_decodeObject(response.body));
  }

  Future<EmployeeStatsResponse> getEstadisticas({
    required String token,
    String? desde,
    String? hasta,
  }) async {
    final query = <String, String>{};
    final cleanDesde = desde?.trim();
    final cleanHasta = hasta?.trim();
    if (cleanDesde != null && cleanDesde.isNotEmpty) {
      query['desde'] = cleanDesde;
    }
    if (cleanHasta != null && cleanHasta.isNotEmpty) {
      query['hasta'] = cleanHasta;
    }

    final response = await _safeGet(
      _uri(
        '/me/estadisticas',
      ).replace(queryParameters: query.isEmpty ? null : query),
      headers: _headers(token: token),
      actionLabel: 'consultar estadisticas',
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudieron obtener estadisticas.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }

    return EmployeeStatsResponse.fromJson(_decodeObject(response.body));
  }

  Future<DashboardResponse> getDashboard({
    required String token,
    String? periodo,
    String? desde,
    String? hasta,
  }) async {
    final query = <String, String>{};
    if (periodo != null && periodo.trim().isNotEmpty) query['periodo'] = periodo.trim();
    if (desde != null && desde.trim().isNotEmpty) query['desde'] = desde.trim();
    if (hasta != null && hasta.trim().isNotEmpty) query['hasta'] = hasta.trim();
    final response = await _safeGet(
      _uri('/me/dashboard').replace(queryParameters: query.isEmpty ? null : query),
      headers: _headers(token: token),
      actionLabel: 'consultar dashboard',
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el dashboard.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }

    return DashboardResponse.fromJson(_decodeObject(response.body));
  }

  Future<JustificacionesPageResult> getJustificaciones({
    required String token,
    int page = 1,
    int per = 20,
    String? estado,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    if (estado != null && estado.trim().isNotEmpty) {
      query['estado'] = estado.trim();
    }
    final response = await _safeGet(
      _uri('/me/justificaciones').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'consultar justificaciones',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudieron obtener justificaciones.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return JustificacionesPageResult.fromJson(_decodeObject(response.body));
  }

  Future<JustificacionItem> createJustificacion({
    required String token,
    required String motivo,
    int? asistenciaId,
    String? archivo,
  }) async {
    final body = <String, dynamic>{'motivo': motivo.trim()};
    if (asistenciaId != null) body['asistencia_id'] = asistenciaId;
    if (archivo != null && archivo.trim().isNotEmpty) {
      body['archivo'] = archivo.trim();
    }
    final response = await _safePost(
      _uri('/me/justificaciones'),
      headers: _headers(token: token),
      body: jsonEncode(body),
      actionLabel: 'crear justificación',
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo crear la justificación.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return JustificacionItem.fromJson(_decodeObject(response.body));
  }

  Future<void> deleteJustificacion({
    required String token,
    required int id,
  }) async {
    final response = await _safeDelete(
      _uri('/me/justificaciones/$id'),
      headers: _headers(token: token),
      actionLabel: 'eliminar justificación',
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo eliminar la justificación.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
  }

  Future<AdelantoResumenResponse> getAdelantoResumen({
    required String token,
  }) async {
    final response = await _safeGet(
      _uri('/me/adelantos/resumen'),
      headers: _headers(token: token),
      actionLabel: 'consultar resumen de adelantos',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el resumen de adelantos.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return AdelantoResumenResponse.fromJson(_decodeObject(response.body));
  }

  Future<AdelantoEstadoResponse> getAdelantoEstado({
    required String token,
  }) async {
    final response = await _safeGet(
      _uri('/me/adelantos/estado'),
      headers: _headers(token: token),
      actionLabel: 'consultar adelanto',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo consultar el estado del adelanto.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return AdelantoEstadoResponse.fromJson(_decodeObject(response.body));
  }

  Future<AdelantoItem> createAdelanto({required String token}) async {
    final response = await _safePost(
      _uri('/me/adelantos'),
      headers: _headers(token: token),
      body: '{}',
      actionLabel: 'solicitar adelanto',
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo solicitar el adelanto.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return AdelantoItem.fromJson(_decodeObject(response.body));
  }

  Future<AdelantoItem> getAdelanto({
    required String token,
    required int id,
  }) async {
    final response = await _safeGet(
      _uri('/me/adelantos/$id'),
      headers: _headers(token: token),
      actionLabel: 'consultar adelanto',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el adelanto.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return AdelantoItem.fromJson(_decodeObject(response.body));
  }

  Future<AdelantosPageResult> getAdelantos({
    required String token,
    int page = 1,
    int per = 20,
    String? estado,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    if (estado != null && estado.trim().isNotEmpty) {
      query['estado'] = estado.trim();
    }
    final response = await _safeGet(
      _uri('/me/adelantos').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'consultar historial de adelantos',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el historial de adelantos.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return AdelantosPageResult.fromJson(_decodeObject(response.body));
  }

  Future<VacacionesPageResult> getVacaciones({
    required String token,
    int page = 1,
    int per = 20,
    String? estado,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    if (estado != null && estado.trim().isNotEmpty) {
      query['estado'] = estado.trim();
    }
    final response = await _safeGet(
      _uri('/me/vacaciones').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'consultar vacaciones',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudieron obtener las vacaciones.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return VacacionesPageResult.fromJson(_decodeObject(response.body));
  }

  Future<VacacionItem> getVacacion({
    required String token,
    required int id,
  }) async {
    final response = await _safeGet(
      _uri('/me/vacaciones/$id'),
      headers: _headers(token: token),
      actionLabel: 'consultar vacación',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener la vacacion.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return VacacionItem.fromJson(_decodeObject(response.body));
  }

  Future<VacacionItem> createVacacion({
    required String token,
    required String fechaDesde,
    required String fechaHasta,
    String? observaciones,
  }) async {
    final body = <String, dynamic>{
      'fecha_desde': fechaDesde,
      'fecha_hasta': fechaHasta,
    };
    if (observaciones != null && observaciones.trim().isNotEmpty) {
      body['observaciones'] = observaciones.trim();
    }
    final response = await _safePost(
      _uri('/me/vacaciones'),
      headers: _headers(token: token),
      body: jsonEncode(body),
      actionLabel: 'solicitar vacaciones',
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo solicitar las vacaciones.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return VacacionItem.fromJson(_decodeObject(response.body));
  }

  Future<VacacionItem> updateVacacion({
    required String token,
    required int id,
    String? fechaDesde,
    String? fechaHasta,
    String? observaciones,
  }) async {
    final body = <String, dynamic>{};
    if (fechaDesde != null) body['fecha_desde'] = fechaDesde;
    if (fechaHasta != null) body['fecha_hasta'] = fechaHasta;
    if (observaciones != null) body['observaciones'] = observaciones.trim();
    final response = await _safePut(
      _uri('/me/vacaciones/$id'),
      headers: _headers(token: token),
      body: jsonEncode(body),
      actionLabel: 'actualizar vacación',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo actualizar la vacacion.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return VacacionItem.fromJson(_decodeObject(response.body));
  }

  Future<void> deleteVacacion({
    required String token,
    required int id,
  }) async {
    final response = await _safeDelete(
      _uri('/me/vacaciones/$id'),
      headers: _headers(token: token),
      actionLabel: 'cancelar vacación',
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo cancelar la vacacion.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
  }

  Future<FrancosPageResult> getFrancos({
    required String token,
    int page = 1,
    int per = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    final response = await _safeGet(
      _uri('/me/francos').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'consultar francos',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudieron obtener los francos.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return FrancosPageResult.fromJson(_decodeObject(response.body));
  }

  Future<LegajoEventosPageResult> getLegajoEventos({
    required String token,
    int page = 1,
    int per = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    final response = await _safeGet(
      _uri('/me/legajo/eventos').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'consultar legajo',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el legajo.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return LegajoEventosPageResult.fromJson(_decodeObject(response.body));
  }

  Future<HorarioActualResponse> getHorarioActual({
    required String token,
  }) async {
    final response = await _safeGet(
      _uri('/me/horarios-asignaciones/actual'),
      headers: _headers(token: token),
      actionLabel: 'consultar horario actual',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el horario actual.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return HorarioActualResponse.fromJson(_decodeObject(response.body));
  }

  Future<List<AsignacionHorario>> getHorarios({
    required String token,
  }) async {
    final response = await _safeGet(
      _uri('/me/horarios-asignaciones'),
      headers: _headers(token: token),
      actionLabel: 'consultar horarios',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudieron obtener los horarios.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    final raw = jsonDecode(response.body);
    final list = raw is List ? raw : [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>)
          AsignacionHorario.fromJson(item)
        else if (item is Map)
          AsignacionHorario.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<JustificacionItem> getJustificacion({
    required String token,
    required int id,
  }) async {
    final response = await _safeGet(
      _uri('/me/justificaciones/$id'),
      headers: _headers(token: token),
      actionLabel: 'consultar justificación',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener la justificación.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return JustificacionItem.fromJson(_decodeObject(response.body));
  }

  Future<JustificacionItem> updateJustificacion({
    required String token,
    required int id,
    String? motivo,
    String? archivo,
  }) async {
    final body = <String, dynamic>{};
    if (motivo != null) body['motivo'] = motivo.trim();
    if (archivo != null) body['archivo'] = archivo.trim().isEmpty ? null : archivo.trim();
    final response = await _safePut(
      _uri('/me/justificaciones/$id'),
      headers: _headers(token: token),
      body: jsonEncode(body),
      actionLabel: 'actualizar justificación',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo actualizar la justificación.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return JustificacionItem.fromJson(_decodeObject(response.body));
  }

  Future<MarcasPageResult> getMarcas({
    required String token,
    int page = 1,
    int per = 20,
    String? desde,
    String? hasta,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    final cleanDesde = desde?.trim();
    final cleanHasta = hasta?.trim();
    if (cleanDesde != null && cleanDesde.isNotEmpty) {
      query['desde'] = cleanDesde;
    }
    if (cleanHasta != null && cleanHasta.isNotEmpty) {
      query['hasta'] = cleanHasta;
    }

    final response = await _safeGet(
      _uri('/me/marcas').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'consultar historial de marcas',
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener marcas.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }

    return MarcasPageResult.fromJson(_decodeObject(response.body));
  }

  Future<SecurityEventsPageResult> getEventosSeguridad({
    required String token,
    int page = 1,
    int per = 20,
    String? tipoEvento,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    final cleanTipoEvento = tipoEvento?.trim();
    if (cleanTipoEvento != null && cleanTipoEvento.isNotEmpty) {
      query['tipo_evento'] = cleanTipoEvento;
    }

    final response = await _safeGet(
      _uri('/me/eventos-seguridad').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'consultar eventos de seguridad',
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener eventos de seguridad.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }

    final json = _decodeObject(response.body);
    return SecurityEventsPageResult.fromJson(json);
  }

  Future<FichadaResponse> registrarScanQr({
    required String token,
    required String qrToken,
    double? lat,
    double? lon,
    String? foto,
    DateTime? eventAt,
  }) async {
    if (lat == null || lon == null) {
      throw ApiException(
        message: 'Latitud y longitud son obligatorias para fichar por QR.',
        statusCode: 400,
      );
    }
    final now = eventAt ?? DateTime.now();
    final payload = <String, dynamic>{
      'fecha': _formatDate(now),
      'hora': _formatTime(now),
      'qr_token': qrToken,
      'lat': lat,
      'lon': lon,
    };
    if (foto != null && foto.trim().isNotEmpty) {
      payload['foto'] = foto;
    }
    return _postFichada(
      path: '/me/fichadas/scan',
      token: token,
      payload: payload,
      expectedStatus: const {200, 201},
    );
  }

  Future<ProfileUpdateResponse> updatePerfil({
    required String token,
    String? telefono,
    String? direccion,
    String? foto,
    bool? eliminarFoto,
  }) async {
    final payload = <String, dynamic>{};
    if (telefono != null) {
      payload['telefono'] = telefono;
    }
    if (direccion != null) {
      payload['direccion'] = direccion;
    }
    if (foto != null) {
      payload['foto'] = foto;
    }
    if (eliminarFoto != null) {
      payload['eliminar_foto'] = eliminarFoto;
    }

    final response = await _safePut(
      _uri('/me/perfil'),
      headers: _headers(token: token),
      body: jsonEncode(payload),
      actionLabel: 'actualizar perfil',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo actualizar el perfil.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }
    return ProfileUpdateResponse.fromJson(_decodeObject(response.body));
  }

  Future<ProfileUpdateResponse> updatePerfilConFotoFile({
    required String token,
    required String fotoPath,
    String? telefono,
    String? direccion,
  }) async {
    final response = await _sendMultipartWithAuthRecovery(
      token: token,
      actionLabel: 'subir foto de perfil',
      requestBuilder: (effectiveToken) async {
        final request = http.MultipartRequest('PUT', _uri('/me/perfil'));
        if (effectiveToken.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $effectiveToken';
        }
        if (telefono != null) {
          request.fields['telefono'] = telefono;
        }
        if (direccion != null) {
          request.fields['direccion'] = direccion;
        }
        request.files.add(
          await http.MultipartFile.fromPath('foto_file', fotoPath),
        );
        return request;
      },
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo actualizar el perfil.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }
    return ProfileUpdateResponse.fromJson(_decodeObject(response.body));
  }

  Future<void> deleteFotoPerfil({required String token}) async {
    final response = await _safeDelete(
      _uri('/me/perfil/foto'),
      headers: _headers(token: token),
      actionLabel: 'eliminar foto de perfil',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo eliminar la foto de perfil.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }
  }

  Future<void> updatePassword({
    required String token,
    required String passwordActual,
    required String passwordNueva,
  }) async {
    final response = await _safePut(
      _uri('/me/password'),
      headers: _headers(token: token),
      body: jsonEncode({
        'password_actual': passwordActual,
        'password_nueva': passwordNueva,
      }),
      actionLabel: 'actualizar password',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo actualizar la password.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }
  }

  // ─── Pedidos de Mercadería ──────────────────────────────────────────────────

  Future<PedidoMercaderiaResumenResponse> getPedidosMercaderiaResumen({
    required String token,
  }) async {
    final response = await _safeGet(
      _uri('/me/pedidos-mercaderia/resumen'),
      headers: _headers(token: token),
      actionLabel: 'consultar resumen de pedidos de mercadería',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el resumen de pedidos de mercadería.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return PedidoMercaderiaResumenResponse.fromJson(_decodeObject(response.body));
  }

  Future<PedidoMercaderiaEstadoResponse> getPedidosMercaderiaEstado({
    required String token,
  }) async {
    final response = await _safeGet(
      _uri('/me/pedidos-mercaderia/estado'),
      headers: _headers(token: token),
      actionLabel: 'consultar estado de pedido de mercadería',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el estado de pedido de mercadería.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return PedidoMercaderiaEstadoResponse.fromJson(_decodeObject(response.body));
  }

  Future<CatalogoPedidoMercaderiaPageResult> getPedidosMercaderiaArticulos({
    required String token,
    String? q,
    int page = 1,
    int per = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    if (q != null && q.trim().isNotEmpty) query['q'] = q.trim();
    final response = await _safeGet(
      _uri('/me/pedidos-mercaderia/articulos').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'buscar artículos de mercadería',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el catálogo de artículos.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return CatalogoPedidoMercaderiaPageResult.fromJson(_decodeObject(response.body));
  }

  Future<PedidosMercaderiaPageResult> getPedidosMercaderia({
    required String token,
    int page = 1,
    int per = 20,
    String? estado,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': per.toString(),
    };
    if (estado != null && estado.trim().isNotEmpty) query['estado'] = estado.trim();
    final response = await _safeGet(
      _uri('/me/pedidos-mercaderia').replace(queryParameters: query),
      headers: _headers(token: token),
      actionLabel: 'consultar pedidos de mercadería',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudieron obtener los pedidos de mercadería.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return PedidosMercaderiaPageResult.fromJson(_decodeObject(response.body));
  }

  Future<PedidoMercaderiaItem> getPedidoMercaderia({
    required String token,
    required int id,
  }) async {
    final response = await _safeGet(
      _uri('/me/pedidos-mercaderia/$id'),
      headers: _headers(token: token),
      actionLabel: 'consultar pedido de mercadería',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el pedido de mercadería.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return PedidoMercaderiaItem.fromJson(_decodeObject(response.body));
  }

  Future<PedidoMercaderiaItem> createPedidoMercaderia({
    required String token,
    required List<PedidoMercaderiaLinea> items,
  }) async {
    final response = await _safePost(
      _uri('/me/pedidos-mercaderia'),
      headers: _headers(token: token),
      body: jsonEncode({
        'items': [
          for (final i in items)
            {'articulo_id': i.articuloId, 'cantidad_bultos': i.cantidadBultos},
        ],
      }),
      actionLabel: 'crear pedido de mercadería',
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo crear el pedido de mercadería.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return PedidoMercaderiaItem.fromJson(_decodeObject(response.body));
  }

  Future<PedidoMercaderiaItem> updatePedidoMercaderia({
    required String token,
    required int id,
    required List<PedidoMercaderiaLinea> items,
  }) async {
    final response = await _safePut(
      _uri('/me/pedidos-mercaderia/$id'),
      headers: _headers(token: token),
      body: jsonEncode({
        'items': [
          for (final i in items)
            {'articulo_id': i.articuloId, 'cantidad_bultos': i.cantidadBultos},
        ],
      }),
      actionLabel: 'actualizar pedido de mercadería',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo actualizar el pedido de mercadería.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return PedidoMercaderiaItem.fromJson(_decodeObject(response.body));
  }

  Future<PedidoMercaderiaItem> cancelPedidoMercaderia({
    required String token,
    required int id,
  }) async {
    final response = await _safeDelete(
      _uri('/me/pedidos-mercaderia/$id'),
      headers: _headers(token: token),
      actionLabel: 'cancelar pedido de mercadería',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo cancelar el pedido de mercadería.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return PedidoMercaderiaItem.fromJson(_decodeObject(response.body));
  }

  // ─── KPIs Sectoriales ────────────────────────────────────────────────────────

  Future<KpisSectorialResponse> getKpisSector({
    required String token,
    int? anio,
  }) async {
    final query = <String, String>{
      if (anio != null) 'anio': '$anio',
    };
    final response = await _safeGet(
      _uri('/me/kpis-sector').replace(queryParameters: query.isEmpty ? null : query),
      headers: _headers(token: token),
      actionLabel: 'obtener KPIs sectoriales',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudieron obtener los KPIs.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        code: error.code,
      );
    }
    return KpisSectorialResponse.fromJson(_decodeObject(response.body));
  }

  void dispose() {
    _httpClient.close();
  }

  Future<FichadaResponse> _postFichada({
    required String path,
    required String token,
    required Map<String, dynamic> payload,
    required Set<int> expectedStatus,
  }) async {
    final response = await _safePost(
      _uri(path),
      headers: _headers(token: token),
      body: jsonEncode(payload),
      actionLabel: 'registrar la fichada',
    );

    if (!expectedStatus.contains(response.statusCode)) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo registrar la fichada.',
      );
      throw ApiException(
        message: error.message,
        statusCode: response.statusCode,
        alertaFraude: error.alertaFraude,
        eventoId: error.eventoId,
        distanciaM: error.distanciaM,
        toleranciaM: error.toleranciaM,
        code: error.code,
        cooldownSegundosRestantes: error.cooldownSegundosRestantes,
      );
    }

    final json = _decodeObject(response.body);
    return FichadaResponse.fromJson(json);
  }

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final fullBase = normalizedBase.endsWith(_normalizedMobileApiPrefix)
        ? normalizedBase
        : '$normalizedBase$_normalizedMobileApiPrefix';
    return Uri.parse('$fullBase$path');
  }

  Uri _rootUri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final rootBase = normalizedBase.endsWith(_normalizedMobileApiPrefix)
        ? normalizedBase.substring(
            0,
            normalizedBase.length - _normalizedMobileApiPrefix.length,
          )
        : normalizedBase;
    return Uri.parse('$rootBase$path');
  }

  String get _normalizedMobileApiPrefix {
    final trimmed = mobileApiPrefix.trim();
    if (trimmed.isEmpty) {
      return '/api/v1/mobile';
    }
    final withLeadingSlash = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    if (withLeadingSlash.length > 1 && withLeadingSlash.endsWith('/')) {
      return withLeadingSlash.substring(0, withLeadingSlash.length - 1);
    }
    return withLeadingSlash;
  }

  String _resolveToken(String? token) {
    final provider = _tokenProvider;
    if (provider != null) {
      return provider.call()?.trim() ?? '';
    }
    return token?.trim() ?? '';
  }

  Map<String, String> _headers({String? token}) {
    final effectiveToken = _resolveToken(token);
    return {
      'Content-Type': 'application/json',
      if (effectiveToken.isNotEmpty) 'Authorization': 'Bearer $effectiveToken',
    };
  }

  Map<String, dynamic> _decodeObject(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  Future<http.Response> _safePost(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    required String actionLabel,
    bool allowAuthRecovery = true,
  }) async {
    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
      return await _recoverUnauthorized(
        response: response,
        headers: headers,
        allowAuthRecovery: allowAuthRecovery,
        sender: (nextHeaders) =>
            _httpClient.post(uri, headers: nextHeaders, body: body),
      );
    } on TimeoutException {
      throw ApiException(
        message:
            'Tiempo de espera agotado al $actionLabel. Verificá tu conexión a internet.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Verificá tu conexión a internet.',
      );
    } catch (e, stack) {
      _log.warning('Error inesperado al $actionLabel', e, stack);
      throw ApiException(message: 'Error de conexión al $actionLabel.');
    }
  }

  Future<http.Response> _safeGet(
    Uri uri, {
    required Map<String, String> headers,
    required String actionLabel,
    bool allowAuthRecovery = true,
  }) async {
    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      return await _recoverUnauthorized(
        response: response,
        headers: headers,
        allowAuthRecovery: allowAuthRecovery,
        sender: (nextHeaders) => _httpClient.get(uri, headers: nextHeaders),
      );
    } on TimeoutException {
      throw ApiException(
        message:
            'Tiempo de espera agotado al $actionLabel. Verificá tu conexión a internet.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Verificá tu conexión a internet.',
      );
    } catch (e, stack) {
      _log.warning('Error inesperado al $actionLabel', e, stack);
      throw ApiException(message: 'Error de conexión al $actionLabel.');
    }
  }

  Future<http.Response> _safePut(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    required String actionLabel,
    bool allowAuthRecovery = true,
  }) async {
    try {
      final response = await _httpClient
          .put(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
      return await _recoverUnauthorized(
        response: response,
        headers: headers,
        allowAuthRecovery: allowAuthRecovery,
        sender: (nextHeaders) =>
            _httpClient.put(uri, headers: nextHeaders, body: body),
      );
    } on TimeoutException {
      throw ApiException(
        message:
            'Tiempo de espera agotado al $actionLabel. Verificá tu conexión a internet.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Verificá tu conexión a internet.',
      );
    } catch (e, stack) {
      _log.warning('Error inesperado al $actionLabel', e, stack);
      throw ApiException(message: 'Error de conexión al $actionLabel.');
    }
  }

  Future<http.Response> _safeDelete(
    Uri uri, {
    required Map<String, String> headers,
    required String actionLabel,
    bool allowAuthRecovery = true,
  }) async {
    try {
      final response = await _httpClient
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      return await _recoverUnauthorized(
        response: response,
        headers: headers,
        allowAuthRecovery: allowAuthRecovery,
        sender: (nextHeaders) => _httpClient.delete(uri, headers: nextHeaders),
      );
    } on TimeoutException {
      throw ApiException(
        message:
            'Tiempo de espera agotado al $actionLabel. Verificá tu conexión a internet.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Verificá tu conexión a internet.',
      );
    } catch (e, stack) {
      _log.warning('Error inesperado al $actionLabel', e, stack);
      throw ApiException(message: 'Error de conexión al $actionLabel.');
    }
  }

  Future<http.Response> _recoverUnauthorized({
    required http.Response response,
    required Map<String, String> headers,
    required bool allowAuthRecovery,
    required Future<http.Response> Function(Map<String, String> headers) sender,
  }) async {
    if (!allowAuthRecovery ||
        (response.statusCode != 401 && response.statusCode != 403)) {
      return response;
    }
    final authHeader = headers['Authorization'] ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      return response;
    }
    final expiredToken = authHeader.substring('Bearer '.length).trim();
    if (expiredToken.isEmpty) {
      return response;
    }
    final refreshHandler = _onUnauthorizedRefresh;
    if (refreshHandler == null) {
      final unauthorizedHandler = _onUnauthorized;
      if (unauthorizedHandler != null) {
        await unauthorizedHandler();
      }
      return response;
    }
    try {
      final nextToken = await refreshHandler(expiredToken);
      if (nextToken == null || nextToken.trim().isEmpty) {
        final unauthorizedHandler = _onUnauthorized;
        if (unauthorizedHandler != null) {
          await unauthorizedHandler();
        }
        return response;
      }
      final nextHeaders = Map<String, String>.from(headers);
      nextHeaders['Authorization'] = 'Bearer ${nextToken.trim()}';
      final retried = await sender(
        nextHeaders,
      ).timeout(const Duration(seconds: 15));
      if ((retried.statusCode == 401 || retried.statusCode == 403) &&
          _onUnauthorized != null) {
        await _onUnauthorized!.call();
      }
      return retried;
    } catch (e) {
      _log.debug('Error en reintento de auth recovery: $e');
      return response;
    }
  }

  Future<http.StreamedResponse> _safeSendMultipart(
    http.MultipartRequest request, {
    required String actionLabel,
  }) async {
    try {
      return await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(
        message:
            'Tiempo de espera agotado al $actionLabel. Verificá tu conexión a internet.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Verificá tu conexión a internet.',
      );
    } catch (e, stack) {
      _log.warning('Error inesperado al $actionLabel', e, stack);
      throw ApiException(message: 'Error de conexión al $actionLabel.');
    }
  }

  Future<http.Response> _sendMultipartWithAuthRecovery({
    required String token,
    required String actionLabel,
    required Future<http.MultipartRequest> Function(String effectiveToken)
    requestBuilder,
    bool allowAuthRecovery = true,
  }) async {
    final initialToken = _resolveToken(token);
    final initialRequest = await requestBuilder(initialToken);
    final initialStreamedResponse = await _safeSendMultipart(
      initialRequest,
      actionLabel: actionLabel,
    );
    final initialResponse = await http.Response.fromStream(
      initialStreamedResponse,
    );
    if (!allowAuthRecovery ||
        (initialResponse.statusCode != 401 && initialResponse.statusCode != 403) ||
        initialToken.isEmpty) {
      return initialResponse;
    }
    final refreshHandler = _onUnauthorizedRefresh;
    if (refreshHandler == null) {
      final unauthorizedHandler = _onUnauthorized;
      if (unauthorizedHandler != null) {
        await unauthorizedHandler();
      }
      return initialResponse;
    }
    try {
      final nextToken = await refreshHandler(initialToken);
      if (nextToken == null || nextToken.trim().isEmpty) {
        final unauthorizedHandler = _onUnauthorized;
        if (unauthorizedHandler != null) {
          await unauthorizedHandler();
        }
        return initialResponse;
      }
      final retryRequest = await requestBuilder(nextToken.trim());
      final retryStreamedResponse = await _safeSendMultipart(
        retryRequest,
        actionLabel: actionLabel,
      );
      final retryResponse = await http.Response.fromStream(retryStreamedResponse);
      if ((retryResponse.statusCode == 401 || retryResponse.statusCode == 403) &&
          _onUnauthorized != null) {
        await _onUnauthorized!.call();
      }
      return retryResponse;
    } catch (e) {
      _log.debug('Error en reintento multipart auth recovery: $e');
      return initialResponse;
    }
  }

  _ApiErrorData _extractApiError(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final json = _decodeObject(response.body);
      var message = fallback;
      final value = json['error'];
      if (value is String && value.trim().isNotEmpty) {
        message = value.trim();
      }
      final distancia = _parseDouble(json['distancia_m']);
      final tolerancia = _parseDouble(json['tolerancia_m']);
      if (distancia != null && tolerancia != null) {
        final distStr = distancia.toStringAsFixed(1);
        final tolStr = tolerancia.toStringAsFixed(1);
        message = '$message Distancia: $distStr m. Tolerancia: $tolStr m.';
      }
      final alertaFraude = _parseBool(json['alerta_fraude']);
      final eventoId = _parseInt(json['evento_id']);
      final codeValue = json['code'];
      final code = codeValue is String ? codeValue.trim() : null;
      final cooldownSegundosRestantes = _parseInt(
        json['cooldown_segundos_restantes'],
      );
      return _ApiErrorData(
        message: message,
        alertaFraude: alertaFraude,
        eventoId: eventoId,
        distanciaM: distancia,
        toleranciaM: tolerancia,
        code: (code == null || code.isEmpty) ? null : code,
        cooldownSegundosRestantes: cooldownSegundosRestantes,
      );
    } catch (_) {
      return _ApiErrorData(message: fallback);
    }
  }

  bool? _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == '1' || normalized == 'true' || normalized == 'si') {
        return true;
      }
      if (normalized == '0' || normalized == 'false' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  }

  String _formatTime(DateTime date) {
    return '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class LoginResponse {
  LoginResponse({required this.token, required this.empleado});

  final String token;
  final EmployeeSummary empleado;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final empleado = json['empleado'];
    if (token is! String || empleado is! Map) {
      throw const FormatException('Sesión inválida.');
    }
    return LoginResponse(
      token: token,
      empleado: EmployeeSummary.fromJson(Map<String, dynamic>.from(empleado)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'token': token, 'empleado': empleado.toJson()};
  }
}

class EmployeeSummary {
  EmployeeSummary({
    required this.id,
    required this.dni,
    required this.nombre,
    required this.apellido,
    required this.empresaId,
    this.foto,
    this.imagenVersion,
  });

  final int id;
  final String dni;
  final String nombre;
  final String? apellido;
  final int? empresaId;
  final String? foto;
  final int? imagenVersion;

  factory EmployeeSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      dni: (json['dni'] as String?) ?? '',
      nombre: (json['nombre'] as String?) ?? '',
      apellido: json['apellido'] as String?,
      empresaId: (json['empresa_id'] as num?)?.toInt(),
      foto: _jsonString(json['foto']),
      imagenVersion: _jsonImagenVersion(json),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'dni': dni,
      'nombre': nombre,
      'apellido': apellido,
      'empresa_id': empresaId,
      'foto': foto,
      'imagen_version': imagenVersion,
    };
  }

  String get nombreCompleto {
    final parts = <String>[nombre];
    if (apellido != null && apellido!.trim().isNotEmpty) {
      parts.add(apellido!.trim());
    }
    return parts.join(' ').trim();
  }
}

class EmployeeProfile {
  EmployeeProfile({
    required this.id,
    this.empresaId,
    this.sucursalId,
    this.sectorId,
    this.puestoId,
    this.dni,
    this.legajo,
    this.nombre,
    this.apellido,
    this.email,
    this.telefono,
    this.direccion,
    this.foto,
    this.imagenVersion,
    this.estado,
  });

  final int id;
  final int? empresaId;
  final int? sucursalId;
  final int? sectorId;
  final int? puestoId;
  final String? dni;
  final String? legajo;
  final String? nombre;
  final String? apellido;
  final String? email;
  final String? telefono;
  final String? direccion;
  final String? foto;
  final int? imagenVersion;
  final String? estado;

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      id: _jsonInt(json['id']) ?? 0,
      empresaId: _jsonInt(json['empresa_id']),
      sucursalId: _jsonInt(json['sucursal_id']),
      sectorId: _jsonInt(json['sector_id']),
      puestoId: _jsonInt(json['puesto_id']),
      dni: _jsonString(json['dni']),
      legajo: _jsonString(json['legajo']),
      nombre: _jsonString(json['nombre']),
      apellido: _jsonString(json['apellido']),
      email: _jsonString(json['email']),
      telefono: _jsonString(json['telefono']),
      direccion: _jsonString(json['direccion']),
      foto: _jsonString(json['foto']),
      imagenVersion: _jsonImagenVersion(json),
      estado: _jsonString(json['estado']),
    );
  }

  String get nombreCompleto {
    final parts = <String>[
      if ((nombre ?? '').trim().isNotEmpty) nombre!.trim(),
      if ((apellido ?? '').trim().isNotEmpty) apellido!.trim(),
    ];
    return parts.isEmpty ? 'Sin nombre' : parts.join(' ');
  }
}

class AsistenciaItem {
  AsistenciaItem({
    required this.id,
    this.fecha,
    this.horaEntrada,
    this.horaSalida,
    this.metodoEntrada,
    this.metodoSalida,
    this.estado,
    this.observaciones,
    this.gpsOkEntrada,
    this.gpsOkSalida,
    this.gpsDistanciaEntradaM,
    this.gpsDistanciaSalidaM,
    this.gpsToleranciaEntradaM,
    this.gpsToleranciaSalidaM,
  });

  final int id;
  final String? fecha;
  final String? horaEntrada;
  final String? horaSalida;
  final String? metodoEntrada;
  final String? metodoSalida;
  final String? estado;
  final String? observaciones;
  final bool? gpsOkEntrada;
  final bool? gpsOkSalida;
  final double? gpsDistanciaEntradaM;
  final double? gpsDistanciaSalidaM;
  final double? gpsToleranciaEntradaM;
  final double? gpsToleranciaSalidaM;

  factory AsistenciaItem.fromJson(Map<String, dynamic> json) {
    return AsistenciaItem(
      id: _jsonInt(json['id']) ?? 0,
      fecha: _jsonString(json['fecha']),
      horaEntrada: _jsonString(json['hora_entrada']),
      horaSalida: _jsonString(json['hora_salida']),
      metodoEntrada: _jsonString(json['metodo_entrada']),
      metodoSalida: _jsonString(json['metodo_salida']),
      estado: _jsonString(json['estado']),
      observaciones: _jsonString(json['observaciones']),
      gpsOkEntrada: _jsonBool(json['gps_ok_entrada']),
      gpsOkSalida: _jsonBool(json['gps_ok_salida']),
      gpsDistanciaEntradaM: _jsonDouble(json['gps_distancia_entrada_m']),
      gpsDistanciaSalidaM: _jsonDouble(json['gps_distancia_salida_m']),
      gpsToleranciaEntradaM: _jsonDouble(json['gps_tolerancia_entrada_m']),
      gpsToleranciaSalidaM: _jsonDouble(json['gps_tolerancia_salida_m']),
    );
  }
}

class AsistenciasPageResult {
  AsistenciasPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<AsistenciaItem> items;
  final int page;
  final int perPage;
  final int total;

  factory AsistenciasPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <AsistenciaItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(AsistenciaItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(AsistenciaItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return AsistenciasPageResult(
      items: items,
      page: _jsonInt(json['page']) ?? 1,
      perPage: _jsonInt(json['per_page']) ?? 20,
      total: _jsonInt(json['total']) ?? items.length,
    );
  }
}

class MarcaItem {
  MarcaItem({
    required this.id,
    this.asistenciaId,
    this.fecha,
    this.hora,
    this.accion,
    this.metodo,
    this.tipoMarca,
    this.estado,
    this.observaciones,
    this.lat,
    this.lon,
    this.gpsOk,
    this.gpsDistanciaM,
    this.gpsToleranciaM,
    this.fechaCreacion,
  });

  final int id;
  final int? asistenciaId;
  final String? fecha;
  final String? hora;
  final String? accion;
  final String? metodo;
  final String? tipoMarca;
  final String? estado;
  final String? observaciones;
  final double? lat;
  final double? lon;
  final bool? gpsOk;
  final double? gpsDistanciaM;
  final double? gpsToleranciaM;
  final String? fechaCreacion;

  factory MarcaItem.fromJson(Map<String, dynamic> json) {
    return MarcaItem(
      id: _jsonInt(json['id']) ?? 0,
      asistenciaId: _jsonInt(json['asistencia_id']),
      fecha: _jsonString(json['fecha']),
      hora: _jsonString(json['hora']),
      accion: _jsonString(json['accion']),
      metodo: _jsonString(json['metodo']),
      tipoMarca: _jsonString(json['tipo_marca']),
      estado: _jsonString(json['estado']),
      observaciones: _jsonString(json['observaciones']),
      lat: _jsonDouble(json['lat']),
      lon: _jsonDouble(json['lon']),
      gpsOk: _jsonBool(json['gps_ok']),
      gpsDistanciaM: _jsonDouble(json['gps_distancia_m']),
      gpsToleranciaM: _jsonDouble(json['gps_tolerancia_m']),
      fechaCreacion: _jsonString(json['fecha_creacion']),
    );
  }
}

class MarcasPageResult {
  MarcasPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<MarcaItem> items;
  final int page;
  final int perPage;
  final int total;

  factory MarcasPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <MarcaItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(MarcaItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(MarcaItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return MarcasPageResult(
      items: items,
      page: _jsonInt(json['page']) ?? 1,
      perPage: _jsonInt(json['per_page']) ?? 20,
      total: _jsonInt(json['total']) ?? items.length,
    );
  }
}

class EmployeeStatsResponse {
  EmployeeStatsResponse({
    required this.periodo,
    required this.totales,
    required this.kpis,
    required this.jornadas,
    required this.justificaciones,
    required this.vacaciones,
    required this.ausencias,
    required this.series,
  });

  final StatsPeriodo periodo;
  final StatsTotales totales;
  final StatsKpis kpis;
  final StatsJornadas jornadas;
  final StatsJustificaciones justificaciones;
  final StatsVacaciones vacaciones;
  final StatsAusencias ausencias;
  final StatsSeries series;

  factory EmployeeStatsResponse.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return <String, dynamic>{};
    }

    return EmployeeStatsResponse(
      periodo: StatsPeriodo.fromJson(map(json['periodo'])),
      totales: StatsTotales.fromJson(map(json['totales'])),
      kpis: StatsKpis.fromJson(map(json['kpis'])),
      jornadas: StatsJornadas.fromJson(map(json['jornadas'])),
      justificaciones: StatsJustificaciones.fromJson(
        map(json['justificaciones']),
      ),
      vacaciones: StatsVacaciones.fromJson(map(json['vacaciones'])),
      ausencias: StatsAusencias.fromJson(map(json['ausencias'])),
      series: StatsSeries.fromJson(map(json['series'])),
    );
  }
}

class StatsPeriodo {
  StatsPeriodo({this.desde, this.hasta, required this.dias});

  final String? desde;
  final String? hasta;
  final int dias;

  factory StatsPeriodo.fromJson(Map<String, dynamic> json) {
    return StatsPeriodo(
      desde: _jsonString(json['desde']),
      hasta: _jsonString(json['hasta']),
      dias: _jsonInt(json['dias']) ?? 0,
    );
  }
}

class StatsTotales {
  StatsTotales({
    required this.registros,
    required this.ok,
    required this.tarde,
    required this.ausente,
    required this.salidaAnticipada,
    required this.sinEstado,
  });

  final int registros;
  final int ok;
  final int tarde;
  final int ausente;
  final int salidaAnticipada;
  final int sinEstado;

  factory StatsTotales.fromJson(Map<String, dynamic> json) {
    return StatsTotales(
      registros: _jsonInt(json['registros']) ?? 0,
      ok: _jsonInt(json['ok']) ?? 0,
      tarde: _jsonInt(json['tarde']) ?? 0,
      ausente: _jsonInt(json['ausente']) ?? 0,
      salidaAnticipada: _jsonInt(json['salida_anticipada']) ?? 0,
      sinEstado: _jsonInt(json['sin_estado']) ?? 0,
    );
  }
}

class StatsKpis {
  StatsKpis({
    required this.puntualidadPct,
    required this.ausentismoPct,
    required this.cumplimientoJornadaPct,
    required this.noShowPct,
    required this.tasaSalidaAnticipadaPct,
    required this.adherenciaPct,
    required this.horasTotales,
    required this.horasPromedio,
    required this.rachaDiasOk,
    required this.diasLaborables,
    required this.diasConRegistro,
    required this.gpsIncidencias,
  });

  final double puntualidadPct;
  final double ausentismoPct;
  final double cumplimientoJornadaPct;
  final double noShowPct;
  final double tasaSalidaAnticipadaPct;
  // v1.11.0 ──────────────────────────────
  final double adherenciaPct;
  final double horasTotales;
  final double horasPromedio;
  final int rachaDiasOk;
  final int diasLaborables;
  final int diasConRegistro;
  final int gpsIncidencias;

  factory StatsKpis.fromJson(Map<String, dynamic> json) {
    return StatsKpis(
      puntualidadPct: _jsonDouble(json['puntualidad_pct']) ?? 0.0,
      ausentismoPct: _jsonDouble(json['ausentismo_pct']) ?? 0.0,
      cumplimientoJornadaPct:
          _jsonDouble(json['cumplimiento_jornada_pct']) ?? 0.0,
      noShowPct: _jsonDouble(json['no_show_pct']) ?? 0.0,
      tasaSalidaAnticipadaPct:
          _jsonDouble(json['tasa_salida_anticipada_pct']) ?? 0.0,
      adherenciaPct: _jsonDouble(json['adherencia_pct']) ?? 0.0,
      horasTotales: _jsonDouble(json['horas_totales']) ?? 0.0,
      horasPromedio: _jsonDouble(json['horas_promedio']) ?? 0.0,
      rachaDiasOk: _jsonInt(json['racha_ok']) ?? 0,
      diasLaborables: _jsonInt(json['dias_laborables']) ?? 0,
      diasConRegistro: _jsonInt(json['dias_con_registro']) ?? 0,
      gpsIncidencias: _jsonInt(json['gps_incidencias']) ?? 0,
    );
  }
}

class StatsJornadas {
  StatsJornadas({
    required this.completas,
    required this.conMarca,
    required this.incompletas,
  });

  final int completas;
  final int conMarca;
  final int incompletas;

  factory StatsJornadas.fromJson(Map<String, dynamic> json) {
    return StatsJornadas(
      completas: _jsonInt(json['completas']) ?? 0,
      conMarca: _jsonInt(json['con_marca']) ?? 0,
      incompletas: _jsonInt(json['incompletas']) ?? 0,
    );
  }
}

class StatsJustificaciones {
  StatsJustificaciones({
    required this.total,
    required this.pendientes,
    required this.aprobadas,
    required this.rechazadas,
    required this.tasaAprobacionPct,
    required this.tasaJustificacionPct,
  });

  final int total;
  final int pendientes;
  final int aprobadas;
  final int rechazadas;
  final double tasaAprobacionPct;
  final double tasaJustificacionPct;

  factory StatsJustificaciones.fromJson(Map<String, dynamic> json) {
    return StatsJustificaciones(
      total: _jsonInt(json['total']) ?? 0,
      pendientes: _jsonInt(json['pendientes']) ?? 0,
      aprobadas: _jsonInt(json['aprobadas']) ?? 0,
      rechazadas: _jsonInt(json['rechazadas']) ?? 0,
      tasaAprobacionPct: _jsonDouble(json['tasa_aprobacion_pct']) ?? 0.0,
      tasaJustificacionPct: _jsonDouble(json['tasa_justificacion_pct']) ?? 0.0,
    );
  }
}

class StatsVacaciones {
  StatsVacaciones({required this.eventos, required this.dias});

  final int eventos;
  final int dias;

  factory StatsVacaciones.fromJson(Map<String, dynamic> json) {
    return StatsVacaciones(
      eventos: _jsonInt(json['eventos']) ?? 0,
      dias: _jsonInt(json['dias']) ?? 0,
    );
  }
}

class StatsAusencias {
  StatsAusencias({required this.total, required this.sinJustificacion});

  final int total;
  final int sinJustificacion;

  factory StatsAusencias.fromJson(Map<String, dynamic> json) {
    return StatsAusencias(
      total: _jsonInt(json['total']) ?? 0,
      sinJustificacion: _jsonInt(json['sin_justificacion']) ?? 0,
    );
  }
}

class StatsSeries {
  StatsSeries({required this.diaria, required this.semanal});

  final List<StatsDiariaItem> diaria;
  final List<StatsSemanItem> semanal;

  factory StatsSeries.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final items = <T>[];
      if (raw is! List) return items;
      for (final value in raw) {
        if (value is Map<String, dynamic>) {
          items.add(fromJson(value));
        } else if (value is Map) {
          items.add(fromJson(Map<String, dynamic>.from(value)));
        }
      }
      return items;
    }

    return StatsSeries(
      diaria: parseList(json['diaria'], StatsDiariaItem.fromJson),
      semanal: parseList(json['semanal'], StatsSemanItem.fromJson),
    );
  }
}

class StatsSemanItem {
  StatsSemanItem({
    this.semana,
    this.desde,
    this.hasta,
    required this.registros,
    required this.ok,
    required this.tarde,
    required this.ausente,
    required this.puntualidadPct,
    required this.ausentismoPct,
  });

  final String? semana;
  final String? desde;
  final String? hasta;
  final int registros;
  final int ok;
  final int tarde;
  final int ausente;
  final double puntualidadPct;
  final double ausentismoPct;

  factory StatsSemanItem.fromJson(Map<String, dynamic> json) {
    return StatsSemanItem(
      semana: _jsonString(json['semana']),
      desde: _jsonString(json['desde']),
      hasta: _jsonString(json['hasta']),
      registros: _jsonInt(json['registros']) ?? 0,
      ok: _jsonInt(json['ok']) ?? 0,
      tarde: _jsonInt(json['tarde']) ?? 0,
      ausente: _jsonInt(json['ausente']) ?? 0,
      puntualidadPct: _jsonDouble(json['puntualidad_pct']) ?? 0.0,
      ausentismoPct: _jsonDouble(json['ausentismo_pct']) ?? 0.0,
    );
  }
}

class StatsDiariaItem {
  StatsDiariaItem({
    this.fecha,
    required this.registros,
    required this.ok,
    required this.tarde,
    required this.ausente,
    required this.salidaAnticipada,
    required this.puntualidadPct,
    required this.ausentismoPct,
  });

  final String? fecha;
  final int registros;
  final int ok;
  final int tarde;
  final int ausente;
  final int salidaAnticipada;
  final double puntualidadPct;
  final double ausentismoPct;

  factory StatsDiariaItem.fromJson(Map<String, dynamic> json) {
    return StatsDiariaItem(
      fecha: _jsonString(json['fecha']),
      registros: _jsonInt(json['registros']) ?? 0,
      ok: _jsonInt(json['ok']) ?? 0,
      tarde: _jsonInt(json['tarde']) ?? 0,
      ausente: _jsonInt(json['ausente']) ?? 0,
      salidaAnticipada: _jsonInt(json['salida_anticipada']) ?? 0,
      puntualidadPct: _jsonDouble(json['puntualidad_pct']) ?? 0.0,
      ausentismoPct: _jsonDouble(json['ausentismo_pct']) ?? 0.0,
    );
  }
}

class ProfileUpdateResponse {
  ProfileUpdateResponse({
    required this.id,
    this.telefono,
    this.direccion,
    this.foto,
    this.imagenVersion,
  });

  final int id;
  final String? telefono;
  final String? direccion;
  final String? foto;
  final int? imagenVersion;

  factory ProfileUpdateResponse.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateResponse(
      id: _jsonInt(json['id']) ?? 0,
      telefono: _jsonString(json['telefono']),
      direccion: _jsonString(json['direccion']),
      foto: _jsonString(json['foto']),
      imagenVersion: _jsonImagenVersion(json),
    );
  }
}

class FichadaResponse {
  FichadaResponse({
    required this.id,
    required this.estado,
    this.accion,
    this.marcaId,
    this.tipoMarca,
    this.gpsOk,
    this.distanciaM,
    this.toleranciaM,
    this.totalMarcasDia,
  });

  final int id;
  final String? estado;
  final String? accion;
  final int? marcaId;
  final String? tipoMarca;
  final bool? gpsOk;
  final double? distanciaM;
  final double? toleranciaM;
  final int? totalMarcasDia;

  factory FichadaResponse.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value is double) {
        return value;
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value.trim());
      }
      return null;
    }

    bool? parseBool(dynamic value) {
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == '1' || normalized == 'true' || normalized == 'si') {
          return true;
        }
        if (normalized == '0' || normalized == 'false' || normalized == 'no') {
          return false;
        }
      }
      return null;
    }

    return FichadaResponse(
      id: parseInt(json['id']) ?? 0,
      estado: json['estado'] as String?,
      accion: json['accion'] as String?,
      marcaId: parseInt(json['marca_id']),
      tipoMarca: json['tipo_marca'] as String?,
      gpsOk: parseBool(json['gps_ok']),
      distanciaM: parseDouble(json['distancia_m']),
      toleranciaM: parseDouble(json['tolerancia_m']),
      totalMarcasDia: parseInt(json['total_marcas_dia']),
    );
  }
}

class AttendanceConfig {
  AttendanceConfig({
    required this.empresaId,
    required this.requiereQr,
    required this.requiereFoto,
    required this.requiereGeo,
    required this.toleranciaGlobal,
    required this.cooldownScanSegundos,
    required this.intervaloMinimoFichadasMinutos,
    required this.metodosHabilitados,
  });

  final int? empresaId;
  final bool requiereQr;
  final bool requiereFoto;
  final bool requiereGeo;
  final int? toleranciaGlobal;
  final int cooldownScanSegundos;
  final int? intervaloMinimoFichadasMinutos;
  final List<String> metodosHabilitados;

  factory AttendanceConfig.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value) {
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == '1' || normalized == 'true' || normalized == 'si';
      }
      return false;
    }

    int? parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    List<String> parseStringList(dynamic value) {
      if (value is! List) {
        return const <String>[];
      }
      final items = <String>[];
      for (final item in value) {
        if (item is String) {
          final normalized = item.trim().toLowerCase();
          if (normalized.isNotEmpty) {
            items.add(normalized);
          }
        }
      }
      return items;
    }

    final parsedMethods = parseStringList(json['metodos_habilitados']);

    return AttendanceConfig(
      empresaId: parseInt(json['empresa_id']),
      requiereQr: parseBool(json['requiere_qr']),
      requiereFoto: parseBool(json['requiere_foto']),
      requiereGeo: parseBool(json['requiere_geo']),
      toleranciaGlobal: parseInt(json['tolerancia_global']),
      cooldownScanSegundos: parseInt(json['cooldown_scan_segundos']) ?? 0,
      intervaloMinimoFichadasMinutos: parseInt(
        json['intervalo_minimo_fichadas_minutos'],
      ),
      metodosHabilitados: parsedMethods,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'empresa_id': empresaId,
      'requiere_qr': requiereQr,
      'requiere_foto': requiereFoto,
      'requiere_geo': requiereGeo,
      'tolerancia_global': toleranciaGlobal,
      'cooldown_scan_segundos': cooldownScanSegundos,
      'intervalo_minimo_fichadas_minutos': intervaloMinimoFichadasMinutos,
      'metodos_habilitados': metodosHabilitados,
    };
  }

  bool isMetodoHabilitado(String metodo) {
    final normalized = metodo.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (metodosHabilitados.isEmpty) {
      return true;
    }
    return metodosHabilitados.contains(normalized);
  }
}

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.alertaFraude,
    this.eventoId,
    this.distanciaM,
    this.toleranciaM,
    this.code,
    this.cooldownSegundosRestantes,
  });

  final String message;
  final int? statusCode;
  final bool? alertaFraude;
  final int? eventoId;
  final double? distanciaM;
  final double? toleranciaM;
  final String? code;
  final int? cooldownSegundosRestantes;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }
    return '$statusCode: $message';
  }
}

class SecurityEventsPageResult {
  SecurityEventsPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<SecurityEventItem> items;
  final int page;
  final int perPage;
  final int total;

  factory SecurityEventsPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <SecurityEventItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(SecurityEventItem.fromJson(raw));
          continue;
        }
        if (raw is Map) {
          items.add(SecurityEventItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return SecurityEventsPageResult(
      items: items,
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }
}

class SecurityEventItem {
  SecurityEventItem({
    required this.id,
    required this.tipoEvento,
    required this.severidad,
    required this.alertaFraude,
    required this.fecha,
    this.fechaOperacion,
    this.horaOperacion,
    this.lat,
    this.lon,
    this.refLat,
    this.refLon,
    this.distanciaM,
    this.toleranciaM,
    this.sucursalId,
  });

  final int id;
  final String? tipoEvento;
  final String? severidad;
  final bool alertaFraude;
  final String? fecha;
  final String? fechaOperacion;
  final String? horaOperacion;
  final double? lat;
  final double? lon;
  final double? refLat;
  final double? refLon;
  final double? distanciaM;
  final double? toleranciaM;
  final int? sucursalId;

  factory SecurityEventItem.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value is double) {
        return value;
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value.trim());
      }
      return null;
    }

    bool parseBool(dynamic value) {
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == '1' || normalized == 'true' || normalized == 'si';
      }
      return false;
    }

    return SecurityEventItem(
      id: parseInt(json['id']) ?? 0,
      tipoEvento: json['tipo_evento'] as String?,
      severidad: json['severidad'] as String?,
      alertaFraude: parseBool(json['alerta_fraude']),
      fecha: json['fecha'] as String?,
      fechaOperacion: json['fecha_operacion'] as String?,
      horaOperacion: json['hora_operacion'] as String?,
      lat: parseDouble(json['lat']),
      lon: parseDouble(json['lon']),
      refLat: parseDouble(json['ref_lat']),
      refLon: parseDouble(json['ref_lon']),
      distanciaM: parseDouble(json['distancia_m']),
      toleranciaM: parseDouble(json['tolerancia_m']),
      sucursalId: parseInt(json['sucursal_id']),
    );
  }
}

// ─── Adelantos ───────────────────────────────────────────────────────────────

class AdelantosPageResult {
  AdelantosPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<AdelantoItem> items;
  final int page;
  final int perPage;
  final int total;

  factory AdelantosPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <AdelantoItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(AdelantoItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(AdelantoItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return AdelantosPageResult(
      items: items,
      page: _jsonInt(json['page']) ?? 1,
      perPage: _jsonInt(json['per_page']) ?? 20,
      total: _jsonInt(json['total']) ?? items.length,
    );
  }
}

class AdelantoItem {
  AdelantoItem({
    required this.id,
    required this.periodo,
    required this.periodoYear,
    required this.periodoMonth,
    this.fechaSolicitud,
    this.estado,
    this.createdAt,
    this.resueltoAt,
    this.resueltoPor,
  });

  final int id;
  final String periodo;
  final int periodoYear;
  final int periodoMonth;
  final String? fechaSolicitud;
  final String? estado;
  final String? createdAt;
  final String? resueltoAt;
  final String? resueltoPor;

  factory AdelantoItem.fromJson(Map<String, dynamic> json) {
    return AdelantoItem(
      id: _jsonInt(json['id']) ?? 0,
      periodo: _jsonString(json['periodo']) ?? '',
      periodoYear: _jsonInt(json['periodo_year']) ?? 0,
      periodoMonth: _jsonInt(json['periodo_month']) ?? 0,
      fechaSolicitud: _jsonString(json['fecha_solicitud']),
      estado: _jsonString(json['estado']),
      createdAt: _jsonString(json['created_at']),
      resueltoAt: _jsonString(json['resuelto_at']),
      resueltoPor: _jsonString(json['resuelto_by_usuario']),
    );
  }
}

class AdelantoResumenResponse {
  AdelantoResumenResponse({
    required this.periodo,
    required this.periodoYear,
    required this.periodoMonth,
    required this.yaSolicitado,
    required this.totalHistorial,
    required this.pendientesTotal,
    this.adelantoMesActual,
    this.ultimoAdelanto,
  });

  final String periodo;
  final int periodoYear;
  final int periodoMonth;
  final bool yaSolicitado;
  final int totalHistorial;
  final int pendientesTotal;
  final AdelantoItem? adelantoMesActual;
  final AdelantoItem? ultimoAdelanto;

  factory AdelantoResumenResponse.fromJson(Map<String, dynamic> json) {
    AdelantoItem? parseAdelanto(dynamic raw) {
      if (raw is Map<String, dynamic>) return AdelantoItem.fromJson(raw);
      if (raw is Map) return AdelantoItem.fromJson(Map<String, dynamic>.from(raw));
      return null;
    }

    return AdelantoResumenResponse(
      periodo: _jsonString(json['periodo']) ?? '',
      periodoYear: _jsonInt(json['periodo_year']) ?? 0,
      periodoMonth: _jsonInt(json['periodo_month']) ?? 0,
      yaSolicitado: json['ya_solicitado'] == true,
      totalHistorial: _jsonInt(json['total_historial']) ?? 0,
      pendientesTotal: _jsonInt(json['pendientes_total']) ?? 0,
      adelantoMesActual: parseAdelanto(json['adelanto_mes_actual']),
      ultimoAdelanto: parseAdelanto(json['ultimo_adelanto']),
    );
  }
}

class AdelantoEstadoResponse {
  AdelantoEstadoResponse({
    required this.periodo,
    required this.periodoYear,
    required this.periodoMonth,
    required this.yaSolicitado,
    this.adelanto,
  });

  final String periodo;
  final int periodoYear;
  final int periodoMonth;
  final bool yaSolicitado;
  final AdelantoItem? adelanto;

  factory AdelantoEstadoResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['adelanto'];
    return AdelantoEstadoResponse(
      periodo: _jsonString(json['periodo']) ?? '',
      periodoYear: _jsonInt(json['periodo_year']) ?? 0,
      periodoMonth: _jsonInt(json['periodo_month']) ?? 0,
      yaSolicitado: json['ya_solicitado'] == true,
      adelanto: raw is Map<String, dynamic>
          ? AdelantoItem.fromJson(raw)
          : raw is Map
          ? AdelantoItem.fromJson(Map<String, dynamic>.from(raw))
          : null,
    );
  }
}

// ─── Pedidos de Mercadería ───────────────────────────────────────────────────

class PedidoMercaderiaLinea {
  const PedidoMercaderiaLinea({
    required this.articuloId,
    required this.cantidadBultos,
  });

  final int articuloId;
  final int cantidadBultos;
}

class PedidoMercaderiaItemLinea {
  PedidoMercaderiaItemLinea({
    required this.id,
    required this.articuloId,
    this.codigoArticulo,
    this.descripcion,
    this.unidadesPorBulto,
    required this.cantidadBultos,
  });

  final int id;
  final int articuloId;
  final String? codigoArticulo;
  final String? descripcion;
  final int? unidadesPorBulto;
  final int cantidadBultos;

  factory PedidoMercaderiaItemLinea.fromJson(Map<String, dynamic> json) {
    return PedidoMercaderiaItemLinea(
      id: _jsonInt(json['id']) ?? 0,
      articuloId: _jsonInt(json['articulo_id']) ?? 0,
      codigoArticulo: _jsonString(json['codigo_articulo']),
      descripcion: _jsonString(json['descripcion']),
      unidadesPorBulto: _jsonInt(json['unidades_por_bulto']),
      cantidadBultos: _jsonInt(json['cantidad_bultos']) ?? 0,
    );
  }
}

class PedidoMercaderiaItem {
  PedidoMercaderiaItem({
    required this.id,
    this.periodo,
    this.periodoYear,
    this.periodoMonth,
    this.fechaPedido,
    this.estado,
    this.cantidadItems,
    this.totalBultos,
    this.motivoRechazo,
    this.createdAt,
    this.resueltaAt,
    this.resueltoByUsuario,
    required this.items,
  });

  final int id;
  final String? periodo;
  final int? periodoYear;
  final int? periodoMonth;
  final String? fechaPedido;
  final String? estado;
  final int? cantidadItems;
  final int? totalBultos;
  final String? motivoRechazo;
  final String? createdAt;
  final String? resueltaAt;
  final String? resueltoByUsuario;
  final List<PedidoMercaderiaItemLinea> items;

  factory PedidoMercaderiaItem.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <PedidoMercaderiaItemLinea>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(PedidoMercaderiaItemLinea.fromJson(raw));
        } else if (raw is Map) {
          items.add(PedidoMercaderiaItemLinea.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return PedidoMercaderiaItem(
      id: _jsonInt(json['id']) ?? 0,
      periodo: _jsonString(json['periodo']),
      periodoYear: _jsonInt(json['periodo_year']),
      periodoMonth: _jsonInt(json['periodo_month']),
      fechaPedido: _jsonString(json['fecha_pedido']),
      estado: _jsonString(json['estado']),
      cantidadItems: _jsonInt(json['cantidad_items']),
      totalBultos: _jsonInt(json['total_bultos']),
      motivoRechazo: _jsonString(json['motivo_rechazo']),
      createdAt: _jsonString(json['created_at']),
      resueltaAt: _jsonString(json['resuelto_at']),
      resueltoByUsuario: _jsonString(json['resuelto_by_usuario']),
      items: items,
    );
  }
}

class PedidosMercaderiaPageResult {
  PedidosMercaderiaPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<PedidoMercaderiaItem> items;
  final int page;
  final int perPage;
  final int total;

  factory PedidosMercaderiaPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <PedidoMercaderiaItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(PedidoMercaderiaItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(PedidoMercaderiaItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return PedidosMercaderiaPageResult(
      items: items,
      page: _jsonInt(json['page']) ?? 1,
      perPage: _jsonInt(json['per_page']) ?? 20,
      total: _jsonInt(json['total']) ?? items.length,
    );
  }
}

class PedidoMercaderiaEstadoResponse {
  PedidoMercaderiaEstadoResponse({
    required this.periodo,
    required this.periodoYear,
    required this.periodoMonth,
    required this.yaSolicitado,
    this.pedido,
  });

  final String periodo;
  final int periodoYear;
  final int periodoMonth;
  final bool yaSolicitado;
  final PedidoMercaderiaItem? pedido;

  factory PedidoMercaderiaEstadoResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['pedido'];
    return PedidoMercaderiaEstadoResponse(
      periodo: _jsonString(json['periodo']) ?? '',
      periodoYear: _jsonInt(json['periodo_year']) ?? 0,
      periodoMonth: _jsonInt(json['periodo_month']) ?? 0,
      yaSolicitado: json['ya_solicitado'] == true,
      pedido: raw is Map<String, dynamic>
          ? PedidoMercaderiaItem.fromJson(raw)
          : raw is Map
          ? PedidoMercaderiaItem.fromJson(Map<String, dynamic>.from(raw))
          : null,
    );
  }
}

class PedidoMercaderiaResumenResponse {
  PedidoMercaderiaResumenResponse({
    required this.periodo,
    required this.periodoYear,
    required this.periodoMonth,
    required this.yaSolicitado,
    required this.totalHistorial,
    required this.historialAprobadosTotal,
    required this.pendientesTotal,
    this.pedidoMesActual,
    this.ultimoPedido,
    this.ultimoPedidoAprobado,
  });

  final String periodo;
  final int periodoYear;
  final int periodoMonth;
  final bool yaSolicitado;
  final int totalHistorial;
  final int historialAprobadosTotal;
  final int pendientesTotal;
  final PedidoMercaderiaItem? pedidoMesActual;
  final PedidoMercaderiaItem? ultimoPedido;
  final PedidoMercaderiaItem? ultimoPedidoAprobado;

  factory PedidoMercaderiaResumenResponse.fromJson(Map<String, dynamic> json) {
    PedidoMercaderiaItem? parseItem(dynamic raw) {
      if (raw is Map<String, dynamic>) return PedidoMercaderiaItem.fromJson(raw);
      if (raw is Map) return PedidoMercaderiaItem.fromJson(Map<String, dynamic>.from(raw));
      return null;
    }

    return PedidoMercaderiaResumenResponse(
      periodo: _jsonString(json['periodo']) ?? '',
      periodoYear: _jsonInt(json['periodo_year']) ?? 0,
      periodoMonth: _jsonInt(json['periodo_month']) ?? 0,
      yaSolicitado: json['ya_solicitado'] == true,
      totalHistorial: _jsonInt(json['total_historial']) ?? 0,
      historialAprobadosTotal: _jsonInt(json['historial_aprobados_total']) ?? 0,
      pendientesTotal: _jsonInt(json['pendientes_total']) ?? 0,
      pedidoMesActual: parseItem(json['pedido_mes_actual']),
      ultimoPedido: parseItem(json['ultimo_pedido']),
      ultimoPedidoAprobado: parseItem(json['ultimo_pedido_aprobado']),
    );
  }
}

class CatalogoPedidoMercaderiaItem {
  CatalogoPedidoMercaderiaItem({
    required this.id,
    this.codigoArticulo,
    this.descripcion,
    this.unidadesPorBulto,
    this.bultosPorPallet,
    this.marca,
    this.familia,
    this.sabor,
    this.division,
  });

  final int id;
  final String? codigoArticulo;
  final String? descripcion;
  final int? unidadesPorBulto;
  final int? bultosPorPallet;
  final String? marca;
  final String? familia;
  final String? sabor;
  final String? division;

  factory CatalogoPedidoMercaderiaItem.fromJson(Map<String, dynamic> json) {
    return CatalogoPedidoMercaderiaItem(
      id: _jsonInt(json['id']) ?? 0,
      codigoArticulo: _jsonString(json['codigo_articulo']),
      descripcion: _jsonString(json['descripcion']),
      unidadesPorBulto: _jsonInt(json['unidades_por_bulto']),
      bultosPorPallet: _jsonInt(json['bultos_por_pallet']),
      marca: _jsonString(json['marca']),
      familia: _jsonString(json['familia']),
      sabor: _jsonString(json['sabor']),
      division: _jsonString(json['division']),
    );
  }
}

class CatalogoPedidoMercaderiaPageResult {
  CatalogoPedidoMercaderiaPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<CatalogoPedidoMercaderiaItem> items;
  final int page;
  final int perPage;
  final int total;

  factory CatalogoPedidoMercaderiaPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <CatalogoPedidoMercaderiaItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(CatalogoPedidoMercaderiaItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(CatalogoPedidoMercaderiaItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return CatalogoPedidoMercaderiaPageResult(
      items: items,
      page: _jsonInt(json['page']) ?? 1,
      perPage: _jsonInt(json['per_page']) ?? 20,
      total: _jsonInt(json['total']) ?? items.length,
    );
  }
}

// ─── Justificaciones ─────────────────────────────────────────────────────────

class JustificacionItem {
  JustificacionItem({
    required this.id,
    this.asistenciaId,
    this.asistenciaFecha,
    this.motivo,
    this.archivo,
    this.estado,
    this.createdAt,
  });

  final int id;
  final int? asistenciaId;
  final String? asistenciaFecha;
  final String? motivo;
  final String? archivo;
  final String? estado;
  final String? createdAt;

  factory JustificacionItem.fromJson(Map<String, dynamic> json) {
    return JustificacionItem(
      id: _jsonInt(json['id']) ?? 0,
      asistenciaId: _jsonInt(json['asistencia_id']),
      asistenciaFecha: _jsonString(json['asistencia_fecha']),
      motivo: _jsonString(json['motivo']),
      archivo: _jsonString(json['archivo']),
      estado: _jsonString(json['estado']),
      createdAt: _jsonString(json['created_at']),
    );
  }
}

class JustificacionesPageResult {
  JustificacionesPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<JustificacionItem> items;
  final int page;
  final int perPage;
  final int total;

  factory JustificacionesPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <JustificacionItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(JustificacionItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(JustificacionItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return JustificacionesPageResult(
      items: items,
      page: _jsonInt(json['page']) ?? 1,
      perPage: _jsonInt(json['per_page']) ?? 20,
      total: _jsonInt(json['total']) ?? items.length,
    );
  }
}

// ─── Dashboard (GET /me/dashboard) ───────────────────────────────────────────

class DashboardResponse {
  DashboardResponse({
    required this.periodo,
    required this.asistencia,
    required this.legajo,
    required this.vacacionesActivas,
    required this.francosProximos,
    this.horarioActual,
  });

  final DashboardPeriodo periodo;
  final EmployeeStatsResponse asistencia;
  final LegajoStats legajo;
  final List<VacacionItem> vacacionesActivas;
  final List<FrancoItem> francosProximos;
  final AsignacionHorarioConDias? horarioActual;

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> sub(String key) {
      final v = json[key];
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return {};
    }

    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = json[key];
      if (raw is! List) return [];
      final result = <T>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        } else if (item is Map) {
          result.add(fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return result;
    }

    final rawHorario = json['horario_actual'];
    AsignacionHorarioConDias? horarioActual;
    if (rawHorario is Map<String, dynamic>) {
      horarioActual = AsignacionHorarioConDias.fromJson(rawHorario);
    } else if (rawHorario is Map) {
      horarioActual = AsignacionHorarioConDias.fromJson(Map<String, dynamic>.from(rawHorario));
    }

    return DashboardResponse(
      periodo: DashboardPeriodo.fromJson(sub('periodo')),
      asistencia: EmployeeStatsResponse.fromJson(sub('asistencia')),
      legajo: LegajoStats.fromJson(sub('legajo')),
      vacacionesActivas: parseList('vacaciones_activas', VacacionItem.fromJson),
      francosProximos: parseList('francos_proximos', FrancoItem.fromJson),
      horarioActual: horarioActual,
    );
  }
}

class DashboardPeriodo {
  DashboardPeriodo({this.desde, this.hasta, this.preset, this.diasHabiles});

  final String? desde;
  final String? hasta;
  final String? preset;
  final int? diasHabiles;

  factory DashboardPeriodo.fromJson(Map<String, dynamic> json) {
    return DashboardPeriodo(
      desde: _jsonString(json['desde']),
      hasta: _jsonString(json['hasta']),
      preset: _jsonString(json['preset']),
      diasHabiles: _jsonInt(json['dias_habiles']),
    );
  }
}

class LegajoStats {
  LegajoStats({
    required this.historico,
    required this.periodo,
    required this.porTipo,
    required this.porSeveridad,
    required this.recientes,
  });

  final LegajoHistorico historico;
  final LegajoPeriodoStats periodo;
  final List<LegajoPorTipoItem> porTipo;
  final List<LegajoPorSeveridadItem> porSeveridad;
  final List<LegajoEventoItem> recientes;

  factory LegajoStats.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> sub(String key) {
      final v = json[key];
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return {};
    }

    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = json[key];
      if (raw is! List) return [];
      final result = <T>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          result.add(fromJson(item));
        } else if (item is Map) {
          result.add(fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return result;
    }

    return LegajoStats(
      historico: LegajoHistorico.fromJson(sub('historico')),
      periodo: LegajoPeriodoStats.fromJson(sub('periodo')),
      porTipo: parseList('por_tipo', LegajoPorTipoItem.fromJson),
      porSeveridad: parseList('por_severidad', LegajoPorSeveridadItem.fromJson),
      recientes: parseList('recientes', LegajoEventoItem.fromJson),
    );
  }
}

class LegajoHistorico {
  LegajoHistorico({required this.total, required this.vigentes, required this.anulados});

  final int total;
  final int vigentes;
  final int anulados;

  factory LegajoHistorico.fromJson(Map<String, dynamic> json) {
    return LegajoHistorico(
      total: _jsonInt(json['total']) ?? 0,
      vigentes: _jsonInt(json['vigentes']) ?? 0,
      anulados: _jsonInt(json['anulados']) ?? 0,
    );
  }
}

class LegajoPeriodoStats {
  LegajoPeriodoStats({required this.total, required this.graves, required this.media, required this.leve});

  final int total;
  final int graves;
  final int media;
  final int leve;

  factory LegajoPeriodoStats.fromJson(Map<String, dynamic> json) {
    return LegajoPeriodoStats(
      total: _jsonInt(json['total']) ?? 0,
      graves: _jsonInt(json['graves']) ?? 0,
      media: _jsonInt(json['media']) ?? 0,
      leve: _jsonInt(json['leve']) ?? 0,
    );
  }
}

class LegajoPorTipoItem {
  LegajoPorTipoItem({required this.label, required this.total, required this.pct});

  final String label;
  final int total;
  final double pct;

  factory LegajoPorTipoItem.fromJson(Map<String, dynamic> json) {
    return LegajoPorTipoItem(
      label: _jsonString(json['label']) ?? '',
      total: _jsonInt(json['total']) ?? 0,
      pct: _jsonDouble(json['pct']) ?? 0.0,
    );
  }
}

class LegajoPorSeveridadItem {
  LegajoPorSeveridadItem({required this.severidad, required this.total, required this.pct});

  final String? severidad;
  final int total;
  final double pct;

  factory LegajoPorSeveridadItem.fromJson(Map<String, dynamic> json) {
    return LegajoPorSeveridadItem(
      severidad: _jsonString(json['severidad']),
      total: _jsonInt(json['total']) ?? 0,
      pct: _jsonDouble(json['pct']) ?? 0.0,
    );
  }
}

class AsignacionHorarioConDias {
  AsignacionHorarioConDias({
    required this.id,
    this.horarioId,
    this.horarioNombre,
    this.fechaDesde,
    this.fechaHasta,
    this.dias = const [],
  });

  final int id;
  final int? horarioId;
  final String? horarioNombre;
  final String? fechaDesde;
  final String? fechaHasta;
  final List<int> dias;

  factory AsignacionHorarioConDias.fromJson(Map<String, dynamic> json) {
    final rawDias = json['dias'];
    final dias = <int>[];
    if (rawDias is List) {
      for (final d in rawDias) {
        if (d is Map) {
          final n = _jsonInt(d['dia_semana']);
          if (n != null) dias.add(n);
        }
      }
    }
    return AsignacionHorarioConDias(
      id: _jsonInt(json['id']) ?? 0,
      horarioId: _jsonInt(json['horario_id']),
      horarioNombre: _jsonString(json['horario_nombre']),
      fechaDesde: _jsonString(json['fecha_desde']),
      fechaHasta: _jsonString(json['fecha_hasta']),
      dias: dias,
    );
  }
}

int? _jsonInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

double? _jsonDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

bool? _jsonBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == '1' || normalized == 'true' || normalized == 'si') {
      return true;
    }
    if (normalized == '0' || normalized == 'false' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

String? _jsonString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

int? _jsonImagenVersion(Map<String, dynamic> json) {
  return _jsonInt(json['imagen_version']) ??
      _jsonInt(json['foto_version']) ??
      _jsonInt(json['image_version']);
}

// ─── Vacaciones ───────────────────────────────────────────────────────────────

class VacacionItem {
  VacacionItem({
    required this.id,
    this.empleadoId,
    this.fechaDesde,
    this.fechaHasta,
    this.observaciones,
  });

  final int id;
  final int? empleadoId;
  final String? fechaDesde;
  final String? fechaHasta;
  final String? observaciones;

  factory VacacionItem.fromJson(Map<String, dynamic> json) {
    return VacacionItem(
      id: _jsonInt(json['id']) ?? 0,
      empleadoId: _jsonInt(json['empleado_id']),
      fechaDesde: _jsonString(json['fecha_desde']),
      fechaHasta: _jsonString(json['fecha_hasta']),
      observaciones: _jsonString(json['observaciones']),
    );
  }
}

class VacacionesPageResult {
  VacacionesPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<VacacionItem> items;
  final int page;
  final int perPage;
  final int total;

  factory VacacionesPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <VacacionItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(VacacionItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(VacacionItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return VacacionesPageResult(
      items: items,
      page: _jsonInt(json['page']) ?? 1,
      perPage: _jsonInt(json['per_page']) ?? 20,
      total: _jsonInt(json['total']) ?? items.length,
    );
  }
}

// ─── Francos ──────────────────────────────────────────────────────────────────

class FrancoItem {
  FrancoItem({
    required this.id,
    this.empleadoId,
    this.fecha,
    this.motivo,
  });

  final int id;
  final int? empleadoId;
  final String? fecha;
  final String? motivo;

  factory FrancoItem.fromJson(Map<String, dynamic> json) {
    return FrancoItem(
      id: _jsonInt(json['id']) ?? 0,
      empleadoId: _jsonInt(json['empleado_id']),
      fecha: _jsonString(json['fecha']),
      motivo: _jsonString(json['motivo']),
    );
  }
}

class FrancosPageResult {
  FrancosPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<FrancoItem> items;
  final int page;
  final int perPage;
  final int total;

  factory FrancosPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <FrancoItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(FrancoItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(FrancoItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return FrancosPageResult(
      items: items,
      page: _jsonInt(json['page']) ?? 1,
      perPage: _jsonInt(json['per_page']) ?? 20,
      total: _jsonInt(json['total']) ?? items.length,
    );
  }
}

// ─── Legajo ───────────────────────────────────────────────────────────────────

class LegajoEventoItem {
  LegajoEventoItem({
    required this.id,
    this.tipoId,
    this.tipoCodigo,
    this.tipoNombre,
    this.fechaEvento,
    this.fechaDesde,
    this.fechaHasta,
    this.titulo,
    this.descripcion,
    this.estado,
    this.severidad,
  });

  final int id;
  final int? tipoId;
  final String? tipoCodigo;
  final String? tipoNombre;
  final String? fechaEvento;
  final String? fechaDesde;
  final String? fechaHasta;
  final String? titulo;
  final String? descripcion;
  final String? estado;
  final String? severidad;

  factory LegajoEventoItem.fromJson(Map<String, dynamic> json) {
    return LegajoEventoItem(
      id: _jsonInt(json['id']) ?? 0,
      tipoId: _jsonInt(json['tipo_id']),
      tipoCodigo: _jsonString(json['tipo_codigo']),
      tipoNombre: _jsonString(json['tipo_nombre']),
      fechaEvento: _jsonString(json['fecha_evento']),
      fechaDesde: _jsonString(json['fecha_desde']),
      fechaHasta: _jsonString(json['fecha_hasta']),
      titulo: _jsonString(json['titulo']),
      descripcion: _jsonString(json['descripcion']),
      estado: _jsonString(json['estado']),
      severidad: _jsonString(json['severidad']),
    );
  }
}

class LegajoEventosPageResult {
  LegajoEventosPageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<LegajoEventoItem> items;
  final int page;
  final int perPage;
  final int total;

  factory LegajoEventosPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <LegajoEventoItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(LegajoEventoItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(LegajoEventoItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return LegajoEventosPageResult(
      items: items,
      page: _jsonInt(json['page']) ?? 1,
      perPage: _jsonInt(json['per_page']) ?? 20,
      total: _jsonInt(json['total']) ?? items.length,
    );
  }
}

// ─── Horarios ─────────────────────────────────────────────────────────────────

class AsignacionHorario {
  AsignacionHorario({
    required this.id,
    this.horarioId,
    this.horarioNombre,
    this.fechaDesde,
    this.fechaHasta,
  });

  final int id;
  final int? horarioId;
  final String? horarioNombre;
  final String? fechaDesde;
  final String? fechaHasta;

  factory AsignacionHorario.fromJson(Map<String, dynamic> json) {
    return AsignacionHorario(
      id: _jsonInt(json['id']) ?? 0,
      horarioId: _jsonInt(json['horario_id']),
      horarioNombre: _jsonString(json['horario_nombre']),
      fechaDesde: _jsonString(json['fecha_desde']),
      fechaHasta: _jsonString(json['fecha_hasta']),
    );
  }
}

class HorarioActualResponse {
  HorarioActualResponse({this.asignacion, this.dias = const []});

  final AsignacionHorario? asignacion;
  final List<int> dias;

  factory HorarioActualResponse.fromJson(Map<String, dynamic> json) {
    final rawAsignacion = json['asignacion'];
    AsignacionHorario? asignacion;
    if (rawAsignacion is Map<String, dynamic>) {
      asignacion = AsignacionHorario.fromJson(rawAsignacion);
    } else if (rawAsignacion is Map) {
      asignacion = AsignacionHorario.fromJson(Map<String, dynamic>.from(rawAsignacion));
    }

    final rawDias = json['dias'];
    final dias = <int>[];
    if (rawDias is List) {
      for (final d in rawDias) {
        if (d is Map) {
          final n = _jsonInt(d['dia_semana']);
          if (n != null) dias.add(n);
        }
      }
    }

    return HorarioActualResponse(asignacion: asignacion, dias: dias);
  }
}

// ─── KPIs Sectoriales ────────────────────────────────────────────────────────

class KpiSectorialItem {
  KpiSectorialItem({
    required this.kpiId,
    required this.codigo,
    required this.nombre,
    this.unidad,
    this.tipoAcumulacion,
    this.mayorEsMejor = true,
    this.condicion,
    this.condicionSimbolo,
    required this.objetivoAnual,
    this.valorMin,
    this.valorMax,
    required this.resultadoAcumulado,
    required this.progresoPct,
    required this.progresoEsperadoPct,
    required this.semaforo,
    this.recomendacion,
  });

  final int kpiId;
  final String codigo;
  final String nombre;
  final String? unidad;
  final String? tipoAcumulacion;
  final bool mayorEsMejor;
  final String? condicion;       // gte | lte | eq | between
  final String? condicionSimbolo; // ≥ | ≤ | = | entre
  final double objetivoAnual;
  final double? valorMin;
  final double? valorMax;
  final double resultadoAcumulado;
  final double progresoPct;
  final double progresoEsperadoPct;
  final String semaforo; // verde | amarillo | rojo | gris
  final String? recomendacion;

  bool get isBetween => condicion == 'between';

  factory KpiSectorialItem.fromJson(Map<String, dynamic> json) {
    return KpiSectorialItem(
      kpiId: _jsonInt(json['kpi_id']) ?? 0,
      codigo: _jsonString(json['codigo']) ?? '',
      nombre: _jsonString(json['nombre']) ?? '',
      unidad: _jsonString(json['unidad']),
      tipoAcumulacion: _jsonString(json['tipo_acumulacion']),
      mayorEsMejor: json['mayor_es_mejor'] != false,
      condicion: _jsonString(json['condicion']),
      condicionSimbolo: _jsonString(json['condicion_simbolo']),
      objetivoAnual: _jsonDouble(json['objetivo_anual']) ?? 0,
      valorMin: _jsonDouble(json['valor_min']),
      valorMax: _jsonDouble(json['valor_max']),
      resultadoAcumulado: _jsonDouble(json['resultado_acumulado']) ?? 0,
      progresoPct: _jsonDouble(json['progreso_pct']) ?? 0,
      progresoEsperadoPct: _jsonDouble(json['progreso_esperado_pct']) ?? 0,
      semaforo: _jsonString(json['semaforo']) ?? 'gris',
      recomendacion: _jsonString(json['recomendacion']),
    );
  }
}

class KpisSectorialSector {
  KpisSectorialSector({this.id, this.nombre});

  final int? id;
  final String? nombre;

  factory KpisSectorialSector.fromJson(Map<String, dynamic> json) {
    return KpisSectorialSector(
      id: _jsonInt(json['id']),
      nombre: _jsonString(json['nombre']),
    );
  }
}

class KpisSectorialResponse {
  KpisSectorialResponse({
    required this.anio,
    required this.sector,
    required this.kpis,
  });

  final int anio;
  final KpisSectorialSector sector;
  final List<KpiSectorialItem> kpis;

  factory KpisSectorialResponse.fromJson(Map<String, dynamic> json) {
    final rawSector = json['sector'];
    final sector = rawSector is Map
        ? KpisSectorialSector.fromJson(Map<String, dynamic>.from(rawSector))
        : KpisSectorialSector(id: null, nombre: null);

    final rawKpis = json['kpis'];
    final kpis = <KpiSectorialItem>[];
    if (rawKpis is List) {
      for (final k in rawKpis) {
        if (k is Map) {
          kpis.add(KpiSectorialItem.fromJson(Map<String, dynamic>.from(k)));
        }
      }
    }

    return KpisSectorialResponse(
      anio: _jsonInt(json['anio']) ?? 0,
      sector: sector,
      kpis: kpis,
    );
  }
}

class _ApiErrorData {
  const _ApiErrorData({
    required this.message,
    this.alertaFraude,
    this.eventoId,
    this.distanciaM,
    this.toleranciaM,
    this.code,
    this.cooldownSegundosRestantes,
  });

  final String message;
  final bool? alertaFraude;
  final int? eventoId;
  final double? distanciaM;
  final double? toleranciaM;
  final String? code;
  final int? cooldownSegundosRestantes;
}
