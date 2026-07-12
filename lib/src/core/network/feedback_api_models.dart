String? _asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final raw = value.toString().trim().toLowerCase();
  if (raw.isEmpty) return null;
  if (raw == '1' ||
      raw == 'true' ||
      raw == 'si' ||
      raw == 's\u00ed' ||
      raw == 'y') {
    return true;
  }
  if (raw == '0' || raw == 'false' || raw == 'no' || raw == 'n') {
    return false;
  }
  return null;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

class FeedbackEmpleadoRef {
  const FeedbackEmpleadoRef({this.id, this.nombre, this.legajo, this.dni});

  final int? id;
  final String? nombre;
  final String? legajo;
  final String? dni;

  String get displayName {
    final parts = <String>[];
    final nombreValue = nombre?.trim();
    final legajoValue = legajo?.trim();
    if (nombreValue != null && nombreValue.isNotEmpty) parts.add(nombreValue);
    if (legajoValue != null && legajoValue.isNotEmpty) {
      parts.add('Legajo $legajoValue');
    }
    return parts.isEmpty ? 'Empleado' : parts.join(' - ');
  }

  factory FeedbackEmpleadoRef.fromJson(Map<String, dynamic> json) {
    return FeedbackEmpleadoRef(
      id: _asInt(json['id']),
      nombre: _asString(json['nombre']),
      legajo: _asString(json['legajo']),
      dni: _asString(json['dni']),
    );
  }
}

class FeedbackCliente {
  const FeedbackCliente({
    this.id,
    this.codigo,
    this.razonSocial,
    this.nombreFantasia,
    this.tipo,
    this.sucursalOrigen,
    this.telefonos,
    this.movil,
    this.email,
    this.domicilio,
    this.localidad,
    this.provincia,
  });

  final int? id;
  final String? codigo;
  final String? razonSocial;
  final String? nombreFantasia;
  final String? tipo;
  final String? sucursalOrigen;
  final String? telefonos;
  final String? movil;
  final String? email;
  final String? domicilio;
  final String? localidad;
  final String? provincia;

  String get displayName {
    final candidates = [nombreFantasia, razonSocial, codigo, tipo];
    for (final raw in candidates) {
      final value = raw?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Cliente';
  }

  factory FeedbackCliente.fromJson(Map<String, dynamic> json) {
    return FeedbackCliente(
      id: _asInt(json['id']),
      codigo:
          _asString(json['codigo']) ??
          _asString(json['codigo_externo']) ??
          _asString(json['numero_cliente']) ??
          _asString(json['numero']),
      razonSocial: _asString(json['razon_social']),
      nombreFantasia:
          _asString(json['nombre_fantasia']) ??
          _asString(json['nombre_negocio']) ??
          _asString(json['fantasia']),
      tipo: _asString(json['tipo']),
      sucursalOrigen: _asString(json['sucursal_origen']),
      telefonos: _asString(json['telefonos']),
      movil: _asString(json['movil']),
      email: _asString(json['email']),
      domicilio: _asString(json['domicilio']),
      localidad: _asString(json['localidad']),
      provincia: _asString(json['provincia']),
    );
  }
}

class FeedbackMotivo {
  const FeedbackMotivo({this.id, this.nombre, this.descripcion, this.slaDias});

  final int? id;
  final String? nombre;
  final String? descripcion;
  final int? slaDias;

  String get displayName {
    final value = nombre?.trim();
    return (value == null || value.isEmpty) ? 'Motivo' : value;
  }

  factory FeedbackMotivo.fromJson(Map<String, dynamic> json) {
    return FeedbackMotivo(
      id: _asInt(json['id']),
      nombre: _asString(json['nombre']),
      descripcion: _asString(json['descripcion']),
      slaDias: _asInt(json['sla_dias']),
    );
  }
}

class FeedbackItem {
  const FeedbackItem({
    this.id,
    this.empresaId,
    this.estado,
    this.estadoActual,
    this.descripcion,
    this.fechaVencimiento,
    this.createdAt,
    this.updatedAt,
    this.resueltoAt,
    this.resueltoEnSla,
    this.resolucionDescripcion,
    this.diasRestantes,
    this.empleado,
    this.jefeDirecto,
    this.cliente,
    this.motivo,
    this.resueltoPor,
  });

  final int? id;
  final int? empresaId;
  final String? estado;
  final String? estadoActual;
  final String? descripcion;
  final String? fechaVencimiento;
  final String? createdAt;
  final String? updatedAt;
  final String? resueltoAt;
  final bool? resueltoEnSla;
  final String? resolucionDescripcion;
  final int? diasRestantes;
  final FeedbackEmpleadoRef? empleado;
  final FeedbackEmpleadoRef? jefeDirecto;
  final FeedbackCliente? cliente;
  final FeedbackMotivo? motivo;
  final FeedbackEmpleadoRef? resueltoPor;

  bool get isResolved => (estado ?? '').trim().toLowerCase() == 'resuelto';

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    final empleadoRaw = _asMap(json['empleado']);
    final jefeRaw = _asMap(json['jefe_directo']);
    final clienteRaw = _asMap(json['cliente']);
    final motivoRaw = _asMap(json['motivo']);
    final resueltoPorRaw = _asMap(json['resuelto_por']);
    return FeedbackItem(
      id: _asInt(json['id']),
      empresaId: _asInt(json['empresa_id']),
      estado: _asString(json['estado']),
      estadoActual: _asString(json['estado_actual']),
      descripcion: _asString(json['descripcion']),
      fechaVencimiento: _asString(json['fecha_vencimiento']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
      resueltoAt: _asString(json['resuelto_at']),
      resueltoEnSla: _asBool(json['resuelto_en_sla']),
      resolucionDescripcion: _asString(json['resolucion_descripcion']),
      diasRestantes: _asInt(json['dias_restantes']),
      empleado: empleadoRaw.isEmpty
          ? null
          : FeedbackEmpleadoRef.fromJson(empleadoRaw),
      jefeDirecto: jefeRaw.isEmpty
          ? null
          : FeedbackEmpleadoRef.fromJson(jefeRaw),
      cliente: clienteRaw.isEmpty ? null : FeedbackCliente.fromJson(clienteRaw),
      motivo: motivoRaw.isEmpty ? null : FeedbackMotivo.fromJson(motivoRaw),
      resueltoPor: resueltoPorRaw.isEmpty
          ? null
          : FeedbackEmpleadoRef.fromJson(resueltoPorRaw),
    );
  }
}

class FeedbackDashboardSummary {
  const FeedbackDashboardSummary({
    this.total,
    this.resueltos,
    this.pendientes,
    this.enProceso,
    this.vencidos,
    this.resueltosEnSla,
    this.resueltosFueraSla,
    this.motivosDistintos,
    this.clientesDistintos,
    this.empleadosConCarga,
  });

  final int? total;
  final int? resueltos;
  final int? pendientes;
  final int? enProceso;
  final int? vencidos;
  final int? resueltosEnSla;
  final int? resueltosFueraSla;
  final int? motivosDistintos;
  final int? clientesDistintos;
  final int? empleadosConCarga;

  factory FeedbackDashboardSummary.fromJson(Map<String, dynamic> json) {
    return FeedbackDashboardSummary(
      total: _asInt(json['total']),
      resueltos: _asInt(json['resueltos']),
      pendientes: _asInt(json['pendientes']),
      enProceso: _asInt(json['en_proceso']),
      vencidos: _asInt(json['vencidos']),
      resueltosEnSla: _asInt(json['resueltos_en_sla']),
      resueltosFueraSla: _asInt(json['resueltos_fuera_sla']),
      motivosDistintos: _asInt(json['motivos_distintos']),
      clientesDistintos: _asInt(json['clientes_distintos']),
      empleadosConCarga: _asInt(json['empleados_con_carga']),
    );
  }
}

class FeedbackTopMotivo {
  const FeedbackTopMotivo({
    this.motivoId,
    this.motivoNombre,
    this.total,
    this.resueltos,
  });

  final int? motivoId;
  final String? motivoNombre;
  final int? total;
  final int? resueltos;

  factory FeedbackTopMotivo.fromJson(Map<String, dynamic> json) {
    return FeedbackTopMotivo(
      motivoId: _asInt(json['motivo_id']),
      motivoNombre: _asString(json['motivo_nombre']),
      total: _asInt(json['total']),
      resueltos: _asInt(json['resueltos']),
    );
  }
}

class FeedbackRankingItem {
  const FeedbackRankingItem({
    this.empleadoId,
    this.legajo,
    this.apellido,
    this.nombre,
    this.total,
  });

  final int? empleadoId;
  final String? legajo;
  final String? apellido;
  final String? nombre;
  final int? total;

  String get displayName {
    final pieces = <String>[];
    final fullName = [
      apellido?.trim(),
      nombre?.trim(),
    ].where((value) => value != null && value.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) pieces.add(fullName);
    final legajoValue = legajo?.trim();
    if (legajoValue != null && legajoValue.isNotEmpty) {
      pieces.add('Legajo $legajoValue');
    }
    return pieces.isEmpty ? 'Empleado' : pieces.join(' - ');
  }

  factory FeedbackRankingItem.fromJson(Map<String, dynamic> json) {
    return FeedbackRankingItem(
      empleadoId: _asInt(json['empleado_id']),
      legajo: _asString(json['legajo']),
      apellido: _asString(json['apellido']),
      nombre: _asString(json['nombre']),
      total: _asInt(json['total']),
    );
  }
}

class FeedbackPersonalStats {
  const FeedbackPersonalStats({
    this.empleadoId,
    this.totalCargados,
    this.posicionRanking,
    this.totalPersonalActivo,
    this.promedioPorEmpleado,
    this.porcentajeSobreTotal,
  });

  final int? empleadoId;
  final int? totalCargados;
  final int? posicionRanking;
  final int? totalPersonalActivo;
  final double? promedioPorEmpleado;
  final double? porcentajeSobreTotal;

  factory FeedbackPersonalStats.fromJson(Map<String, dynamic> json) {
    return FeedbackPersonalStats(
      empleadoId: _asInt(json['empleado_id']),
      totalCargados: _asInt(json['total_cargados']),
      posicionRanking: _asInt(json['posicion_ranking']),
      totalPersonalActivo: _asInt(json['total_personal_activo']),
      promedioPorEmpleado: _asDouble(json['promedio_por_empleado']),
      porcentajeSobreTotal: _asDouble(json['porcentaje_sobre_total']),
    );
  }
}

class FeedbackTotals {
  const FeedbackTotals({this.empleadosActivos, this.empleadosConCarga});

  final int? empleadosActivos;
  final int? empleadosConCarga;

  factory FeedbackTotals.fromJson(Map<String, dynamic> json) {
    return FeedbackTotals(
      empleadosActivos: _asInt(json['empleados_activos']),
      empleadosConCarga: _asInt(json['empleados_con_carga']),
    );
  }
}

class FeedbackEmployeeSummary {
  const FeedbackEmployeeSummary({
    this.id,
    this.nombre,
    this.apellido,
    this.legajo,
    this.empresaId,
  });

  final int? id;
  final String? nombre;
  final String? apellido;
  final String? legajo;
  final int? empresaId;

  String get displayName {
    final fullName = [
      apellido?.trim(),
      nombre?.trim(),
    ].where((value) => value != null && value.isNotEmpty).join(' ');
    return fullName.isEmpty ? 'Empleado' : fullName;
  }

  factory FeedbackEmployeeSummary.fromJson(Map<String, dynamic> json) {
    return FeedbackEmployeeSummary(
      id: _asInt(json['id']),
      nombre: _asString(json['nombre']),
      apellido: _asString(json['apellido']),
      legajo: _asString(json['legajo']),
      empresaId: _asInt(json['empresa_id']),
    );
  }
}

class FeedbackDashboardResponse {
  const FeedbackDashboardResponse({
    required this.resumen,
    required this.topMotivos,
    required this.ranking,
    required this.personal,
    required this.totales,
    required this.empleado,
  });

  final FeedbackDashboardSummary resumen;
  final List<FeedbackTopMotivo> topMotivos;
  final List<FeedbackRankingItem> ranking;
  final FeedbackPersonalStats? personal;
  final FeedbackTotals totales;
  final FeedbackEmployeeSummary? empleado;

  factory FeedbackDashboardResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('resumen') || json.containsKey('top_motivos')
        ? json
        : _asMap(json['data']);
    final rawTopMotivos = _asMapList(data['top_motivos']);
    final rawRanking = _asMapList(data['ranking']);
    final resumenRaw = _asMap(data['resumen']);
    final personalRaw = _asMap(data['personal']);
    final totalesRaw = _asMap(data['totales']);
    final empleadoRaw = _asMap(data['empleado']);
    return FeedbackDashboardResponse(
      resumen: FeedbackDashboardSummary.fromJson(resumenRaw),
      topMotivos: rawTopMotivos
          .map(FeedbackTopMotivo.fromJson)
          .toList(growable: false),
      ranking: rawRanking
          .map(FeedbackRankingItem.fromJson)
          .toList(growable: false),
      personal: personalRaw.isEmpty
          ? null
          : FeedbackPersonalStats.fromJson(personalRaw),
      totales: FeedbackTotals.fromJson(totalesRaw),
      empleado: empleadoRaw.isEmpty
          ? null
          : FeedbackEmployeeSummary.fromJson(empleadoRaw),
    );
  }
}

class FeedbackMotivosResponse {
  const FeedbackMotivosResponse({required this.items, required this.total});

  final List<FeedbackMotivo> items;
  final int total;

  factory FeedbackMotivosResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('items') ? json : _asMap(json['data']);
    final rawItems = _asMapList(data['items']);
    return FeedbackMotivosResponse(
      items: rawItems.map(FeedbackMotivo.fromJson).toList(growable: false),
      total: _asInt(data['total']) ?? rawItems.length,
    );
  }
}

class FeedbackClientesResponse {
  const FeedbackClientesResponse({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<FeedbackCliente> items;
  final int page;
  final int perPage;
  final int total;

  factory FeedbackClientesResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('items') ? json : _asMap(json['data']);
    final rawItems = _asMapList(data['items']);
    return FeedbackClientesResponse(
      items: rawItems.map(FeedbackCliente.fromJson).toList(growable: false),
      page: _asInt(data['page']) ?? 1,
      perPage: _asInt(data['per_page']) ?? 20,
      total: _asInt(data['total']) ?? rawItems.length,
    );
  }
}

class FeedbackListResponse {
  const FeedbackListResponse({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<FeedbackItem> items;
  final int page;
  final int perPage;
  final int total;

  factory FeedbackListResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('items') ? json : _asMap(json['data']);
    final rawItems = _asMapList(data['items']);
    return FeedbackListResponse(
      items: rawItems.map(FeedbackItem.fromJson).toList(growable: false),
      page: _asInt(data['page']) ?? 1,
      perPage: _asInt(data['per_page']) ?? 20,
      total: _asInt(data['total']) ?? rawItems.length,
    );
  }
}

class FeedbackMutationResponse {
  const FeedbackMutationResponse({required this.ok, required this.feedback});

  final bool ok;
  final FeedbackItem feedback;

  factory FeedbackMutationResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('feedback') || json.containsKey('ok')
        ? json
        : _asMap(json['data']);
    return FeedbackMutationResponse(
      ok: _asBool(data['ok']) ?? false,
      feedback: FeedbackItem.fromJson(_asMap(data['feedback'])),
    );
  }
}

class FeedbackDetailResponse {
  const FeedbackDetailResponse({required this.feedback});

  final FeedbackItem feedback;

  factory FeedbackDetailResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('feedback') ? json : _asMap(json['data']);
    return FeedbackDetailResponse(
      feedback: FeedbackItem.fromJson(_asMap(data['feedback'])),
    );
  }
}
