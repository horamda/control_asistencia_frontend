import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

class MobileApiClient {
  MobileApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;
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

  Future<LoginResponse> login({
    required String dni,
    required String password,
  }) async {
    final response = await _safePost(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({'dni': dni, 'password': password}),
      actionLabel: 'iniciar sesion',
      allowAuthRecovery: false,
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo iniciar sesion.',
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
      actionLabel: 'consultar configuracion de asistencia',
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener la configuracion de asistencia.',
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
      actionLabel: 'renovar sesion',
      allowAuthRecovery: false,
    );

    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo renovar la sesion.',
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
        message: 'Respuesta invalida del servidor al renovar sesion.',
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

  Future<HorarioEsperadoResponse?> getHorarioEsperado({
    required String token,
    String? fecha,
  }) async {
    final query = <String, String>{};
    final cleanFecha = fecha?.trim();
    if (cleanFecha != null && cleanFecha.isNotEmpty) {
      query['fecha'] = cleanFecha;
    }

    final response = await _safeGet(
      _uri(
        '/me/horario-esperado',
      ).replace(queryParameters: query.isEmpty ? null : query),
      headers: _headers(token: token),
      actionLabel: 'consultar horario esperado',
    );

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo obtener el horario esperado.',
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
    return HorarioEsperadoResponse.fromJson(_decodeObject(response.body));
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
      'per': per.toString(),
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

  Future<MarcasPageResult> getMarcas({
    required String token,
    int page = 1,
    int per = 20,
    String? desde,
    String? hasta,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per': per.toString(),
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
      'per': per.toString(),
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
  }) {
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

  Future<FichadaResponse> registrarEntradaLegacy({
    required String token,
    required String metodo,
    String? fecha,
    String? horaEntrada,
    String? qrToken,
    double? lat,
    double? lon,
    String? foto,
    String? observaciones,
  }) {
    final payload = <String, dynamic>{'metodo': metodo.trim().toLowerCase()};
    if ((fecha ?? '').trim().isNotEmpty) {
      payload['fecha'] = fecha!.trim();
    }
    if ((horaEntrada ?? '').trim().isNotEmpty) {
      payload['hora_entrada'] = horaEntrada!.trim();
    }
    if ((qrToken ?? '').trim().isNotEmpty) {
      payload['qr_token'] = qrToken!.trim();
    }
    if (lat != null) {
      payload['lat'] = lat;
    }
    if (lon != null) {
      payload['lon'] = lon;
    }
    if ((foto ?? '').trim().isNotEmpty) {
      payload['foto'] = foto!.trim();
    }
    if ((observaciones ?? '').trim().isNotEmpty) {
      payload['observaciones'] = observaciones!.trim();
    }
    return _postFichada(
      path: '/me/fichadas/entrada',
      token: token,
      payload: payload,
      expectedStatus: const {201},
    );
  }

  Future<FichadaResponse> registrarSalidaLegacy({
    required String token,
    required String metodo,
    String? fecha,
    String? horaSalida,
    String? horaEntrada,
    String? qrToken,
    double? lat,
    double? lon,
    String? foto,
    String? observaciones,
  }) {
    final payload = <String, dynamic>{'metodo': metodo.trim().toLowerCase()};
    if ((fecha ?? '').trim().isNotEmpty) {
      payload['fecha'] = fecha!.trim();
    }
    if ((horaSalida ?? '').trim().isNotEmpty) {
      payload['hora_salida'] = horaSalida!.trim();
    }
    if ((horaEntrada ?? '').trim().isNotEmpty) {
      payload['hora_entrada'] = horaEntrada!.trim();
    }
    if ((qrToken ?? '').trim().isNotEmpty) {
      payload['qr_token'] = qrToken!.trim();
    }
    if (lat != null) {
      payload['lat'] = lat;
    }
    if (lon != null) {
      payload['lon'] = lon;
    }
    if ((foto ?? '').trim().isNotEmpty) {
      payload['foto'] = foto!.trim();
    }
    if ((observaciones ?? '').trim().isNotEmpty) {
      payload['observaciones'] = observaciones!.trim();
    }
    return _postFichada(
      path: '/me/fichadas/salida',
      token: token,
      payload: payload,
      expectedStatus: const {200},
    );
  }

  Future<QrGeneradoResponse> generarQr({
    required String token,
    String accion = 'auto',
    String scope = 'empresa',
    String tipoMarca = 'jornada',
    int? vigenciaSegundos,
  }) async {
    final payload = <String, dynamic>{
      'accion': accion.trim().toLowerCase(),
      'scope': scope.trim().toLowerCase(),
      'tipo_marca': tipoMarca.trim().toLowerCase(),
    };
    if (vigenciaSegundos != null) {
      payload['vigencia_segundos'] = vigenciaSegundos;
    }

    final response = await _safePost(
      _uri('/me/qr'),
      headers: _headers(token: token),
      body: jsonEncode(payload),
      actionLabel: 'generar QR',
    );
    if (response.statusCode != 200) {
      final error = _extractApiError(
        response,
        fallback: 'No se pudo generar QR.',
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
    return QrGeneradoResponse.fromJson(_decodeObject(response.body));
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
    final request = http.MultipartRequest('PUT', _uri('/me/perfil'));
    final effectiveToken = _resolveToken(token);
    if (effectiveToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $effectiveToken';
    }

    if (telefono != null) {
      request.fields['telefono'] = telefono;
    }
    if (direccion != null) {
      request.fields['direccion'] = direccion;
    }
    request.files.add(await http.MultipartFile.fromPath('foto_file', fotoPath));

    final streamedResponse = await _safeSendMultipart(
      request,
      actionLabel: 'subir foto de perfil',
    );
    final response = await http.Response.fromStream(streamedResponse);

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
    final effectiveToken = _resolveToken(token);
    final response = await _safeDelete(
      _uri('/me/perfil/foto'),
      headers: {
        if (effectiveToken.isNotEmpty)
          'Authorization': 'Bearer $effectiveToken',
      },
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
    return Uri.parse('$normalizedBase/api/v1/mobile$path');
  }

  Uri _rootUri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    const mobilePrefix = '/api/v1/mobile';
    final rootBase = normalizedBase.endsWith(mobilePrefix)
        ? normalizedBase.substring(0, normalizedBase.length - mobilePrefix.length)
        : normalizedBase;
    return Uri.parse('$rootBase$path');
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
            'Tiempo de espera agotado al $actionLabel. Verifica conectividad con $baseUrl.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Revisa API_BASE_URL: $baseUrl.',
      );
    } catch (_) {
      throw ApiException(message: 'Error de conexion al $actionLabel.');
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
            'Tiempo de espera agotado al $actionLabel. Verifica conectividad con $baseUrl.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Revisa API_BASE_URL: $baseUrl.',
      );
    } catch (_) {
      throw ApiException(message: 'Error de conexion al $actionLabel.');
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
            'Tiempo de espera agotado al $actionLabel. Verifica conectividad con $baseUrl.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Revisa API_BASE_URL: $baseUrl.',
      );
    } catch (_) {
      throw ApiException(message: 'Error de conexion al $actionLabel.');
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
            'Tiempo de espera agotado al $actionLabel. Verifica conectividad con $baseUrl.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Revisa API_BASE_URL: $baseUrl.',
      );
    } catch (_) {
      throw ApiException(message: 'Error de conexion al $actionLabel.');
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
    } catch (_) {
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
            'Tiempo de espera agotado al $actionLabel. Verifica conectividad con $baseUrl.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'No se pudo conectar al servidor para $actionLabel. Revisa API_BASE_URL: $baseUrl.',
      );
    } catch (_) {
      throw ApiException(message: 'Error de conexion al $actionLabel.');
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
      throw const FormatException('Sesion invalida.');
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

class HorarioBloque {
  HorarioBloque({required this.entrada, required this.salida});

  final String? entrada;
  final String? salida;

  factory HorarioBloque.fromJson(Map<String, dynamic> json) {
    return HorarioBloque(
      entrada: _jsonString(json['entrada']),
      salida: _jsonString(json['salida']),
    );
  }
}

class HorarioEsperadoResponse {
  HorarioEsperadoResponse({
    required this.tieneExcepcion,
    required this.bloques,
    this.tolerancia,
  });

  final bool tieneExcepcion;
  final List<HorarioBloque> bloques;
  final int? tolerancia;

  factory HorarioEsperadoResponse.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['bloques'];
    final blocks = <HorarioBloque>[];
    if (rawBlocks is List) {
      for (final raw in rawBlocks) {
        if (raw is Map<String, dynamic>) {
          blocks.add(HorarioBloque.fromJson(raw));
        } else if (raw is Map) {
          blocks.add(HorarioBloque.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return HorarioEsperadoResponse(
      tieneExcepcion: _jsonBool(json['tiene_excepcion']) ?? false,
      bloques: blocks,
      tolerancia: _jsonInt(json['tolerancia']),
    );
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
  });

  final double puntualidadPct;
  final double ausentismoPct;
  final double cumplimientoJornadaPct;
  final double noShowPct;
  final double tasaSalidaAnticipadaPct;

  factory StatsKpis.fromJson(Map<String, dynamic> json) {
    return StatsKpis(
      puntualidadPct: _jsonDouble(json['puntualidad_pct']) ?? 0.0,
      ausentismoPct: _jsonDouble(json['ausentismo_pct']) ?? 0.0,
      cumplimientoJornadaPct:
          _jsonDouble(json['cumplimiento_jornada_pct']) ?? 0.0,
      noShowPct: _jsonDouble(json['no_show_pct']) ?? 0.0,
      tasaSalidaAnticipadaPct:
          _jsonDouble(json['tasa_salida_anticipada_pct']) ?? 0.0,
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
  });

  final int total;
  final int pendientes;
  final int aprobadas;
  final int rechazadas;
  final double tasaAprobacionPct;

  factory StatsJustificaciones.fromJson(Map<String, dynamic> json) {
    return StatsJustificaciones(
      total: _jsonInt(json['total']) ?? 0,
      pendientes: _jsonInt(json['pendientes']) ?? 0,
      aprobadas: _jsonInt(json['aprobadas']) ?? 0,
      rechazadas: _jsonInt(json['rechazadas']) ?? 0,
      tasaAprobacionPct: _jsonDouble(json['tasa_aprobacion_pct']) ?? 0.0,
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
  StatsSeries({required this.diaria});

  final List<StatsDiariaItem> diaria;

  factory StatsSeries.fromJson(Map<String, dynamic> json) {
    final raw = json['diaria'];
    final items = <StatsDiariaItem>[];
    if (raw is List) {
      for (final value in raw) {
        if (value is Map<String, dynamic>) {
          items.add(StatsDiariaItem.fromJson(value));
          continue;
        }
        if (value is Map) {
          items.add(StatsDiariaItem.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }
    return StatsSeries(diaria: items);
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

class QrGeneradoResponse {
  QrGeneradoResponse({
    this.accion,
    this.scope,
    this.tipoMarca,
    this.empresaId,
    this.empleadoId,
    this.vigenciaSegundos,
    this.expiraAt,
    this.qrToken,
    this.qrPngBase64,
  });

  final String? accion;
  final String? scope;
  final String? tipoMarca;
  final int? empresaId;
  final int? empleadoId;
  final int? vigenciaSegundos;
  final String? expiraAt;
  final String? qrToken;
  final String? qrPngBase64;

  factory QrGeneradoResponse.fromJson(Map<String, dynamic> json) {
    return QrGeneradoResponse(
      accion: _jsonString(json['accion']),
      scope: _jsonString(json['scope']),
      tipoMarca: _jsonString(json['tipo_marca']),
      empresaId: _jsonInt(json['empresa_id']),
      empleadoId: _jsonInt(json['empleado_id']),
      vigenciaSegundos: _jsonInt(json['vigencia_segundos']),
      expiraAt: _jsonString(json['expira_at']),
      qrToken: _jsonString(json['qr_token']),
      qrPngBase64: _jsonString(json['qr_png_base64']),
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
