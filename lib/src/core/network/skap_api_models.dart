String? _skapString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int? _skapInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _skapDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool? _skapBool(dynamic value) {
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

Map<String, dynamic> _skapMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _skapMapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

class SkapEmpleadoRef {
  const SkapEmpleadoRef({this.id, this.legajo, this.dni, this.nombre});

  final int? id;
  final String? legajo;
  final String? dni;
  final String? nombre;

  String get displayName {
    final fullName = nombre?.trim();
    final legajoValue = legajo?.trim();
    if (fullName == null || fullName.isEmpty) {
      return legajoValue == null || legajoValue.isEmpty
          ? 'Empleado'
          : 'Legajo $legajoValue';
    }
    if (legajoValue == null || legajoValue.isEmpty) {
      return fullName;
    }
    return '$fullName - Legajo $legajoValue';
  }

  factory SkapEmpleadoRef.fromJson(Map<String, dynamic> json) {
    return SkapEmpleadoRef(
      id: _skapInt(json['id']),
      legajo: _skapString(json['legajo']),
      dni: _skapString(json['dni']),
      nombre: _skapString(json['nombre']),
    );
  }
}

class SkapSimpleRef {
  const SkapSimpleRef({this.id, this.nombre});

  final int? id;
  final String? nombre;

  String get displayName {
    final value = nombre?.trim();
    return (value == null || value.isEmpty) ? 'Sin nombre' : value;
  }

  factory SkapSimpleRef.fromJson(Map<String, dynamic> json) {
    return SkapSimpleRef(
      id: _skapInt(json['id']),
      nombre: _skapString(json['nombre']),
    );
  }
}

class SkapCategoriaCard {
  const SkapCategoriaCard({
    this.categoria,
    this.label,
    this.promedio,
    this.esperado,
    this.nivel,
    this.respuestas,
    this.badge,
  });

  final String? categoria;
  final String? label;
  final double? promedio;
  final double? esperado;
  final String? nivel;
  final int? respuestas;
  final String? badge;

  String get displayLabel {
    final value = label?.trim();
    return (value == null || value.isEmpty)
        ? (categoria ?? 'Categoria')
        : value;
  }

  factory SkapCategoriaCard.fromJson(Map<String, dynamic> json) {
    return SkapCategoriaCard(
      categoria: _skapString(json['categoria']),
      label: _skapString(json['label']),
      promedio: _skapDouble(json['promedio']),
      esperado: _skapDouble(json['esperado']),
      nivel: _skapString(json['nivel']),
      respuestas: _skapInt(json['respuestas']),
      badge: _skapString(json['badge']),
    );
  }
}

class SkapPregunta {
  const SkapPregunta({
    this.id,
    this.sectorId,
    this.sectorNombre,
    this.categoria,
    this.categoriaLabel,
    this.descripcion,
    this.peso,
    this.puntajeEsperado,
    this.requiereObservacion,
    this.requiereEvidencia,
  });

  final int? id;
  final int? sectorId;
  final String? sectorNombre;
  final String? categoria;
  final String? categoriaLabel;
  final String? descripcion;
  final double? peso;
  final double? puntajeEsperado;
  final bool? requiereObservacion;
  final bool? requiereEvidencia;

  factory SkapPregunta.fromJson(Map<String, dynamic> json) {
    return SkapPregunta(
      id: _skapInt(json['id']),
      sectorId: _skapInt(json['sector_id']),
      sectorNombre: _skapString(json['sector_nombre']),
      categoria: _skapString(json['categoria']),
      categoriaLabel: _skapString(json['categoria_label']),
      descripcion: _skapString(json['descripcion']),
      peso: _skapDouble(json['peso']),
      puntajeEsperado: _skapDouble(json['puntaje_esperado']),
      requiereObservacion: _skapBool(json['requiere_observacion']),
      requiereEvidencia: _skapBool(json['requiere_evidencia']),
    );
  }
}

class SkapDetalleRespuesta {
  const SkapDetalleRespuesta({
    this.id,
    this.evaluacionId,
    this.preguntaId,
    this.categoria,
    this.categoriaLabel,
    this.descripcion,
    this.peso,
    this.puntajeEsperado,
    this.puntajeObtenido,
    this.observacion,
    this.evidencia,
  });

  final int? id;
  final int? evaluacionId;
  final int? preguntaId;
  final String? categoria;
  final String? categoriaLabel;
  final String? descripcion;
  final double? peso;
  final double? puntajeEsperado;
  final double? puntajeObtenido;
  final String? observacion;
  final String? evidencia;

  factory SkapDetalleRespuesta.fromJson(Map<String, dynamic> json) {
    return SkapDetalleRespuesta(
      id: _skapInt(json['id']),
      evaluacionId: _skapInt(json['evaluacion_id']),
      preguntaId: _skapInt(json['pregunta_id']),
      categoria: _skapString(json['categoria']),
      categoriaLabel: _skapString(json['categoria_label']),
      descripcion: _skapString(json['descripcion']),
      peso: _skapDouble(json['peso']),
      puntajeEsperado: _skapDouble(json['puntaje_esperado']),
      puntajeObtenido: _skapDouble(json['puntaje_obtenido']),
      observacion: _skapString(json['observacion']),
      evidencia: _skapString(json['evidencia']),
    );
  }
}

class SkapPlanAction {
  const SkapPlanAction({
    this.id,
    this.planId,
    this.categoria,
    this.categoriaLabel,
    this.accion,
    this.responsableEmpleadoId,
    this.responsable,
    this.fechaCompromiso,
    this.estado,
    this.comentarios,
  });

  final int? id;
  final int? planId;
  final String? categoria;
  final String? categoriaLabel;
  final String? accion;
  final int? responsableEmpleadoId;
  final SkapEmpleadoRef? responsable;
  final String? fechaCompromiso;
  final String? estado;
  final String? comentarios;

  bool get isCompleted => (estado ?? '').trim().toLowerCase() == 'completado';

  factory SkapPlanAction.fromJson(Map<String, dynamic> json) {
    final responsableRaw = _skapMap(json['responsable']);
    return SkapPlanAction(
      id: _skapInt(json['id']),
      planId: _skapInt(json['plan_id']),
      categoria: _skapString(json['categoria']),
      categoriaLabel: _skapString(json['categoria_label']),
      accion: _skapString(json['accion']),
      responsableEmpleadoId: _skapInt(json['responsable_empleado_id']),
      responsable: responsableRaw.isEmpty
          ? null
          : SkapEmpleadoRef.fromJson(responsableRaw),
      fechaCompromiso: _skapString(json['fecha_compromiso']),
      estado: _skapString(json['estado']),
      comentarios: _skapString(json['comentarios']),
    );
  }
}

class SkapPromedios {
  const SkapPromedios({
    this.skills,
    this.knowledge,
    this.attitude,
    this.performance,
    this.general,
  });

  final double? skills;
  final double? knowledge;
  final double? attitude;
  final double? performance;
  final double? general;

  factory SkapPromedios.fromJson(Map<String, dynamic> json) {
    return SkapPromedios(
      skills: _skapDouble(json['skills']),
      knowledge: _skapDouble(json['knowledge']),
      attitude: _skapDouble(json['attitude']),
      performance: _skapDouble(json['performance']),
      general: _skapDouble(json['general']),
    );
  }
}

class SkapPlan {
  const SkapPlan({
    this.id,
    this.evaluacionId,
    this.empresaId,
    this.empleadoId,
    this.sectorId,
    this.puestoId,
    this.anio,
    this.promedioGeneral,
    this.nivel,
    this.observaciones,
    this.createdAt,
    this.updatedAt,
    this.evaluacion,
    this.empleado,
    this.sector,
    this.puesto,
    this.evaluador,
    this.accionesTotal,
    this.accionesCompletadas,
    this.accionesVencidas,
    this.avancePct,
    this.acciones = const <SkapPlanAction>[],
  });

  final int? id;
  final int? evaluacionId;
  final int? empresaId;
  final int? empleadoId;
  final int? sectorId;
  final int? puestoId;
  final int? anio;
  final double? promedioGeneral;
  final String? nivel;
  final String? observaciones;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? evaluacion;
  final SkapEmpleadoRef? empleado;
  final SkapSimpleRef? sector;
  final SkapSimpleRef? puesto;
  final SkapSimpleRef? evaluador;
  final int? accionesTotal;
  final int? accionesCompletadas;
  final int? accionesVencidas;
  final double? avancePct;
  final List<SkapPlanAction> acciones;

  factory SkapPlan.fromJson(Map<String, dynamic> json) {
    final empleadoRaw = _skapMap(json['empleado']);
    final sectorRaw = _skapMap(json['sector']);
    final puestoRaw = _skapMap(json['puesto']);
    final evaluadorRaw = _skapMap(json['evaluador']);
    final rawAcciones = _skapMapList(json['acciones']);
    return SkapPlan(
      id: _skapInt(json['id']),
      evaluacionId: _skapInt(json['evaluacion_id']),
      empresaId: _skapInt(json['empresa_id']),
      empleadoId: _skapInt(json['empleado_id']),
      sectorId: _skapInt(json['sector_id']),
      puestoId: _skapInt(json['puesto_id']),
      anio: _skapInt(json['anio']),
      promedioGeneral: _skapDouble(json['promedio_general']),
      nivel: _skapString(json['nivel']),
      observaciones: _skapString(json['observaciones']),
      createdAt: _skapString(json['created_at']),
      updatedAt: _skapString(json['updated_at']),
      evaluacion: json['evaluacion'] is Map
          ? Map<String, dynamic>.from(json['evaluacion'] as Map)
          : null,
      empleado: empleadoRaw.isEmpty
          ? null
          : SkapEmpleadoRef.fromJson(empleadoRaw),
      sector: sectorRaw.isEmpty ? null : SkapSimpleRef.fromJson(sectorRaw),
      puesto: puestoRaw.isEmpty ? null : SkapSimpleRef.fromJson(puestoRaw),
      evaluador: evaluadorRaw.isEmpty
          ? null
          : SkapSimpleRef.fromJson(evaluadorRaw),
      accionesTotal: _skapInt(json['acciones_total']),
      accionesCompletadas: _skapInt(json['acciones_completadas']),
      accionesVencidas: _skapInt(json['acciones_vencidas']),
      avancePct: _skapDouble(json['avance_pct']),
      acciones: rawAcciones
          .map(SkapPlanAction.fromJson)
          .toList(growable: false),
    );
  }
}

class SkapEvaluacion {
  const SkapEvaluacion({
    this.id,
    this.empresaId,
    this.anio,
    this.fechaEvaluacion,
    this.horaEvaluacion,
    this.empleado,
    this.sector,
    this.puesto,
    this.evaluador,
    this.promedios,
    this.nivel,
    this.badge,
    this.observacionesGenerales,
    this.pdpGeneradoAt,
    this.createdAt,
    this.updatedAt,
    this.categoriaCards = const <SkapCategoriaCard>[],
    this.detalles = const <SkapDetalleRespuesta>[],
    this.plan,
  });

  final int? id;
  final int? empresaId;
  final int? anio;
  final String? fechaEvaluacion;
  final String? horaEvaluacion;
  final SkapEmpleadoRef? empleado;
  final SkapSimpleRef? sector;
  final SkapSimpleRef? puesto;
  final SkapSimpleRef? evaluador;
  final SkapPromedios? promedios;
  final String? nivel;
  final String? badge;
  final String? observacionesGenerales;
  final String? pdpGeneradoAt;
  final String? createdAt;
  final String? updatedAt;
  final List<SkapCategoriaCard> categoriaCards;
  final List<SkapDetalleRespuesta> detalles;
  final SkapPlan? plan;

  factory SkapEvaluacion.fromJson(Map<String, dynamic> json) {
    final empleadoRaw = _skapMap(json['empleado']);
    final sectorRaw = _skapMap(json['sector']);
    final puestoRaw = _skapMap(json['puesto']);
    final evaluadorRaw = _skapMap(json['evaluador']);
    final rawCategoriaCards = _skapMapList(json['categoria_cards']);
    final rawDetalles = _skapMapList(json['detalles']);
    final planRaw = _skapMap(json['plan']);
    return SkapEvaluacion(
      id: _skapInt(json['id']),
      empresaId: _skapInt(json['empresa_id']),
      anio: _skapInt(json['anio']),
      fechaEvaluacion: _skapString(json['fecha_evaluacion']),
      horaEvaluacion: _skapString(json['hora_evaluacion']),
      empleado: empleadoRaw.isEmpty
          ? null
          : SkapEmpleadoRef.fromJson(empleadoRaw),
      sector: sectorRaw.isEmpty ? null : SkapSimpleRef.fromJson(sectorRaw),
      puesto: puestoRaw.isEmpty ? null : SkapSimpleRef.fromJson(puestoRaw),
      evaluador: evaluadorRaw.isEmpty
          ? null
          : SkapSimpleRef.fromJson(evaluadorRaw),
      promedios: _skapMap(json['promedios']).isEmpty
          ? null
          : SkapPromedios.fromJson(_skapMap(json['promedios'])),
      nivel: _skapString(json['nivel']),
      badge: _skapString(json['badge']),
      observacionesGenerales: _skapString(json['observaciones_generales']),
      pdpGeneradoAt: _skapString(json['pdp_generado_at']),
      createdAt: _skapString(json['created_at']),
      updatedAt: _skapString(json['updated_at']),
      categoriaCards: rawCategoriaCards
          .map(SkapCategoriaCard.fromJson)
          .toList(growable: false),
      detalles: rawDetalles
          .map(SkapDetalleRespuesta.fromJson)
          .toList(growable: false),
      plan: planRaw.isEmpty ? null : SkapPlan.fromJson(planRaw),
    );
  }
}

class SkapMiDesarrolloResponse {
  const SkapMiDesarrolloResponse({
    required this.empleado,
    required this.anioEvaluado,
    this.evaluacion,
    this.categoriaCards = const <SkapCategoriaCard>[],
    this.historial = const <SkapEvaluacion>[],
    this.plan,
    this.ranking,
    this.badge,
  });

  final SkapEmpleadoRef empleado;
  final int anioEvaluado;
  final SkapEvaluacion? evaluacion;
  final List<SkapCategoriaCard> categoriaCards;
  final List<SkapEvaluacion> historial;
  final SkapPlan? plan;
  final SkapRankingResponse? ranking;
  final String? badge;

  factory SkapMiDesarrolloResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('data') ? _skapMap(json['data']) : json;
    final empleadoRaw = _skapMap(data['empleado']);
    final rawCategoriaCards = _skapMapList(data['categoria_cards']);
    final rawHistorial = _skapMapList(data['historial']);
    final evaluacionRaw = _skapMap(data['evaluacion']);
    final planRaw = _skapMap(data['plan']);
    final rankingRaw = _skapMap(data['ranking']);
    final anioEvaluado = _skapInt(data['anio_evaluado']) ?? DateTime.now().year;
    return SkapMiDesarrolloResponse(
      empleado: SkapEmpleadoRef.fromJson(empleadoRaw),
      anioEvaluado: anioEvaluado,
      evaluacion: evaluacionRaw.isEmpty
          ? null
          : SkapEvaluacion.fromJson(evaluacionRaw),
      categoriaCards: rawCategoriaCards
          .map(SkapCategoriaCard.fromJson)
          .toList(growable: false),
      historial: rawHistorial
          .map(SkapEvaluacion.fromJson)
          .toList(growable: false),
      plan: planRaw.isEmpty ? null : SkapPlan.fromJson(planRaw),
      ranking: rankingRaw.isEmpty
          ? null
          : SkapRankingResponse.fromJson({
              'data': <String, dynamic>{'anio': anioEvaluado, ...rankingRaw},
            }),
      badge: _skapString(data['badge']),
    );
  }
}

class SkapRankingResponse {
  const SkapRankingResponse({
    required this.anio,
    this.posicion,
    required this.total,
    this.puntaje,
    this.nivel,
    this.badge,
  });

  final int anio;
  final int? posicion;
  final int total;
  final double? puntaje;
  final String? nivel;
  final String? badge;

  factory SkapRankingResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('data') ? _skapMap(json['data']) : json;
    return SkapRankingResponse(
      anio: _skapInt(data['anio']) ?? DateTime.now().year,
      posicion: _skapInt(data['posicion']),
      total: _skapInt(data['total']) ?? 0,
      puntaje: _skapDouble(data['puntaje']),
      nivel: _skapString(data['nivel']),
      badge: _skapString(data['badge']),
    );
  }
}

class SkapPlanesResponse {
  const SkapPlanesResponse({
    this.anioSeleccionado,
    required this.total,
    required this.items,
    this.current,
  });

  final int? anioSeleccionado;
  final int total;
  final List<SkapPlan> items;
  final SkapPlan? current;

  factory SkapPlanesResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('data') ? _skapMap(json['data']) : json;
    final rawItems = _skapMapList(data['items']);
    final currentRaw = _skapMap(data['current']);
    return SkapPlanesResponse(
      anioSeleccionado: _skapInt(data['anio_seleccionado']),
      total: _skapInt(data['total']) ?? rawItems.length,
      items: rawItems.map(SkapPlan.fromJson).toList(growable: false),
      current: currentRaw.isEmpty ? null : SkapPlan.fromJson(currentRaw),
    );
  }
}

class SkapPreguntasResponse {
  const SkapPreguntasResponse({
    required this.sectorId,
    required this.items,
    required this.total,
  });

  final int? sectorId;
  final List<SkapPregunta> items;
  final int total;

  factory SkapPreguntasResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('data') ? _skapMap(json['data']) : json;
    final rawItems = _skapMapList(data['items']);
    return SkapPreguntasResponse(
      sectorId: _skapInt(data['sector_id']),
      items: rawItems.map(SkapPregunta.fromJson).toList(growable: false),
      total: _skapInt(data['total']) ?? rawItems.length,
    );
  }
}

class SkapEvaluacionResponse {
  const SkapEvaluacionResponse({
    required this.evaluacion,
    this.plan,
    this.message,
  });

  final SkapEvaluacion evaluacion;
  final SkapPlan? plan;
  final String? message;

  factory SkapEvaluacionResponse.fromJson(Map<String, dynamic> json) {
    final data = json.containsKey('data') ? _skapMap(json['data']) : json;
    final evaluacionRaw = _skapMap(data['evaluacion']);
    final planRaw = _skapMap(data['plan']);
    return SkapEvaluacionResponse(
      evaluacion: SkapEvaluacion.fromJson(evaluacionRaw),
      plan: planRaw.isEmpty ? null : SkapPlan.fromJson(planRaw),
      message: _skapString(json['message']) ?? _skapString(data['message']),
    );
  }
}
