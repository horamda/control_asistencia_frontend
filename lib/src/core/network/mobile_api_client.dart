import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

class MobileApiClient {
  MobileApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<LoginResponse> login({
    required String dni,
    required String password,
  }) async {
    final response = await _safePost(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({
        'dni': dni,
        'password': password,
      }),
      actionLabel: 'iniciar sesion',
    );

    if (response.statusCode != 200) {
      throw ApiException(
        message: _extractError(
          response,
          fallback: 'No se pudo iniciar sesion.',
        ),
        statusCode: response.statusCode,
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

  Future<FichadaResponse> registrarEntrada({
    required String token,
    required String qrData,
  }) {
    final now = DateTime.now();
    return _postFichada(
      path: '/me/fichadas/entrada',
      token: token,
      payload: {
        'fecha': _formatDate(now),
        'metodo': 'qr',
        'hora_entrada': _formatTime(now),
        'observaciones': 'QR:$qrData',
      },
      expectedStatus: const {200, 201},
    );
  }

  Future<FichadaResponse> registrarSalida({
    required String token,
    required String qrData,
  }) {
    final now = DateTime.now();
    return _postFichada(
      path: '/me/fichadas/salida',
      token: token,
      payload: {
        'fecha': _formatDate(now),
        'metodo': 'qr',
        'hora_salida': _formatTime(now),
        'observaciones': 'QR:$qrData',
      },
      expectedStatus: const {200, 201},
    );
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
      throw ApiException(
        message: _extractError(
          response,
          fallback: 'No se pudo registrar la fichada.',
        ),
        statusCode: response.statusCode,
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

  Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
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
  }) async {
    try {
      return await _httpClient
          .post(
            uri,
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));
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
      throw ApiException(
        message: 'Error de conexion al $actionLabel.',
      );
    }
  }

  String _extractError(http.Response response, {required String fallback}) {
    try {
      final json = _decodeObject(response.body);
      final value = json['error'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    } catch (_) {
      // Ignora parse fallido y usa fallback.
    }
    return fallback;
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
  LoginResponse({
    required this.token,
    required this.empleado,
  });

  final String token;
  final EmployeeSummary empleado;
}

class EmployeeSummary {
  EmployeeSummary({
    required this.id,
    required this.dni,
    required this.nombre,
    required this.apellido,
    required this.empresaId,
  });

  final int id;
  final String dni;
  final String nombre;
  final String? apellido;
  final int? empresaId;

  factory EmployeeSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      dni: (json['dni'] as String?) ?? '',
      nombre: (json['nombre'] as String?) ?? '',
      apellido: json['apellido'] as String?,
      empresaId: (json['empresa_id'] as num?)?.toInt(),
    );
  }

  String get nombreCompleto {
    final parts = <String>[nombre];
    if (apellido != null && apellido!.trim().isNotEmpty) {
      parts.add(apellido!.trim());
    }
    return parts.join(' ').trim();
  }
}

class FichadaResponse {
  FichadaResponse({
    required this.id,
    required this.estado,
  });

  final int id;
  final String? estado;

  factory FichadaResponse.fromJson(Map<String, dynamic> json) {
    return FichadaResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      estado: json['estado'] as String?,
    );
  }
}

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }
    return '$statusCode: $message';
  }
}
