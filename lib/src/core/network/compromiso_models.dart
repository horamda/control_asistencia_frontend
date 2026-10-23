/// Indice de compromiso (contrato 1.55.0, GET /me/compromiso).
class CompromisoNivel {
  const CompromisoNivel({
    required this.nombre,
    this.indice,
    this.calculado = false,
    this.anterior,
    this.variacion,
  });

  final String nombre;

  /// 0 a 100, o null si no hay dato.
  final double? indice;

  /// true: no se cargo un total y es el promedio de las areas.
  final bool calculado;
  final double? anterior;

  /// Diferencia en puntos contra el año anterior (null si falta alguno).
  final double? variacion;

  factory CompromisoNivel.fromJson(dynamic json, String porDefecto) {
    final map = json is Map ? json : const {};
    double? numero(dynamic v) => v is num ? v.toDouble() : null;
    final nombre = map['nombre'];
    return CompromisoNivel(
      nombre: nombre is String && nombre.trim().isNotEmpty
          ? nombre
          : porDefecto,
      indice: numero(map['indice']),
      calculado: map['calculado'] == true,
      anterior: numero(map['anterior']),
      variacion: numero(map['variacion']),
    );
  }
}

class CompromisoResponse {
  const CompromisoResponse({
    required this.anio,
    required this.aniosDisponibles,
    required this.area,
    required this.sucursal,
    required this.empresa,
  });

  final int anio;
  final List<int> aniosDisponibles;
  final CompromisoNivel area;
  final CompromisoNivel sucursal;
  final CompromisoNivel empresa;

  bool get sinDatos =>
      area.indice == null && sucursal.indice == null && empresa.indice == null;

  factory CompromisoResponse.fromJson(Map<String, dynamic> json) {
    final anios = json['anios_disponibles'];
    return CompromisoResponse(
      anio: json['anio'] is num
          ? (json['anio'] as num).toInt()
          : DateTime.now().year,
      aniosDisponibles: anios is List
          ? anios.whereType<num>().map((a) => a.toInt()).toList()
          : const [],
      area: CompromisoNivel.fromJson(json['area'], 'Mi área'),
      sucursal: CompromisoNivel.fromJson(json['sucursal'], 'Mi sucursal'),
      empresa: CompromisoNivel.fromJson(json['empresa'], 'Empresa'),
    );
  }
}
