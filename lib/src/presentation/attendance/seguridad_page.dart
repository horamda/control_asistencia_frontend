import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/mobile_api_client.dart';
import 'seguridad_dashboard.dart';
import 'seguridad_external_dialog.dart';

class SeguridadPage extends StatelessWidget {
  const SeguridadPage({
    super.key,
    required this.apiClient,
    required this.token,
    this.imagePicker,
  });
  final MobileApiClient apiClient;
  final String token;
  final ImagePicker? imagePicker;
  @override
  Widget build(BuildContext context) => _SeguridadSession(
    key: ValueKey(token),
    apiClient: apiClient,
    token: token,
    imagePicker: imagePicker,
  );
}

class _SeguridadSession extends StatefulWidget {
  const _SeguridadSession({
    super.key,
    required this.apiClient,
    required this.token,
    this.imagePicker,
  });
  final MobileApiClient apiClient;
  final String token;
  final ImagePicker? imagePicker;
  @override
  State<_SeguridadSession> createState() => _SeguridadPageState();
}

class _SeguridadPageState extends State<_SeguridadSession> {
  static const types = {
    'seguro': 'Comportamiento seguro',
    'inseguro': 'Comportamiento inseguro',
    'incidente': 'Incidente sin lesión',
    'accidente': 'Accidente',
  };
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _place = TextEditingController();
  final _details = {
    for (final field in ['clasificacion', 'atencion', 'lesion', 'parte_cuerpo'])
      field: TextEditingController(),
  };
  final _people = <int>{};
  final _externals = <Map<String, dynamic>>[];
  final _photos = <Uint8List>[];
  Map<String, dynamic>? _config;
  String _type = 'seguro';
  int? _category;
  String? _warned;
  DateTime? _date;
  TimeOfDay? _time;
  String _key = const Uuid().v4();
  bool _busy = false;
  bool _loading = true;
  String? _error;
  int _refresh = 0;
  late SeguridadDashboardController _dashboard;
  Map<String, dynamic> get _capabilities =>
      Map<String, dynamic>.from(_config?['dashboard'] as Map? ?? {});
  bool get _hasDashboard =>
      _capabilities['historial_propio'] == true ||
      _capabilities['indicadores'] == true;

  List<Map<String, dynamic>> maps(dynamic value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  String message(Object e) => e is ApiException
      ? e.message
      : 'No se pudo completar la operación. Volvé a intentar.';
  void changed() {
    _key = const Uuid().v4();
  }

  @override
  void initState() {
    super.initState();
    _dashboard = SeguridadDashboardController(
      api: widget.apiClient,
      token: widget.token,
    );
    _load();
  }

  @override
  void dispose() {
    _dashboard.dispose();
    _description.dispose();
    _place.dispose();
    for (final controller in _details.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await widget.apiClient.getSeguridad(token: widget.token);
      if (!mounted) return;
      setState(() {
        _config = config;
        _date ??= DateTime.parse(config['fecha_actual'] as String);
      });
    } catch (e) {
      if (mounted) setState(() => _error = message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPeople() async {
    final selected = {..._people};
    var query = '';
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final people = maps(_config?['empleados'])
              .where(
                (p) => '${p['legajo']} ${p['apellido']} ${p['nombre']}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: const Text('Personas de tu sucursal'),
            content: SizedBox(
              width: 450,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre o legajo',
                    ),
                    onChanged: (v) => update(() => query = v),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (_, i) {
                        final p = people[i];
                        final id = p['id'] as int;
                        return CheckboxListTile(
                          value: selected.contains(id),
                          title: Text(
                            '${p['legajo']} — ${p['apellido']} ${p['nombre']}',
                          ),
                          onChanged: (v) => update(() {
                            if (v == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Seleccionar'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _people
          ..clear()
          ..addAll(result);
        changed();
      });
    }
  }

  Future<void> _pick(bool camera) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picker = widget.imagePicker ?? ImagePicker();
      final List<XFile> files;
      if (camera) {
        final file = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1800,
        );
        files = file == null ? [] : [file];
      } else {
        files = await picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
      }
      if (_photos.length + files.length > 5) {
        throw StateError('Máximo 5 fotos.');
      }
      final bytes = <Uint8List>[];
      for (final file in files) {
        if (await file.length() > 5 * 1024 * 1024) {
          throw StateError('Cada foto puede pesar hasta 5 MB.');
        }
        bytes.add(await file.readAsBytes());
      }
      if (mounted) {
        setState(() {
          _photos.addAll(bytes);
          changed();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is StateError ? e.message : message(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _externalLabel(Map<String, dynamic> person) {
    final record = person['id'] == null
        ? person
        : maps(
            _config?['externos'],
          ).firstWhere((p) => p['id'] == person['id'], orElse: () => person);
    final company = '${record['empresa'] ?? ''}';
    return '${record['nombre'] ?? 'Persona externa'}${company.isEmpty ? '' : ' — $company'}';
  }

  Future<void> _addExternal() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SeguridadExternalDialog(
        api: widget.apiClient,
        token: widget.token,
        onConfig: (config) {
          if (mounted) setState(() => _config = config);
        },
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (_externals.any((p) => jsonEncode(p) == jsonEncode(result))) {
        _error = 'Esa persona externa ya está seleccionada.';
      } else {
        _externals.add(result);
        changed();
      }
    });
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_people.isEmpty && _externals.isEmpty) {
      setState(() => _error = 'Seleccioná al menos una persona.');
      return;
    }
    if (_people.length + _externals.length > 100) {
      setState(() => _error = 'Podés incluir hasta 100 personas por reporte.');
      return;
    }
    final incident = _type == 'accidente' || _type == 'incidente';
    if (incident && _time == null) {
      setState(() => _error = 'Indicá la hora del evento.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.apiClient.createSeguridad(
        token: widget.token,
        fields: {
          'envio_id': _key,
          'tipo': _type,
          'fecha_evento': _date!.toIso8601String().substring(0, 10),
          'involucrados': jsonEncode(_people.toList()..sort()),
          if (_externals.isNotEmpty) 'externos': jsonEncode(_externals),
          'descripcion': _description.text.trim(),
          if (_category != null) 'categoria_id': '$_category',
          if (_type == 'inseguro') 'advertido': _warned ?? '',
          if (incident) 'lugar': _place.text.trim(),
          if (incident)
            for (final entry in _details.entries)
              if (entry.value.text.trim().isNotEmpty)
                entry.key: entry.value.text.trim(),
          if (incident && _time != null)
            'hora_evento':
                '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
        },
        fotos: List.of(_photos),
      );
      if (!mounted) return;
      setState(() {
        _people.clear();
        _externals.clear();
        _photos.clear();
        _description.clear();
        _place.clear();
        for (final controller in _details.values) {
          controller.clear();
        }
        _warned = null;
        _time = null;
        _refresh++;
        changed();
      });
      var confirmation = 'Reporte enviado, pendiente de aprobación.';
      if (result['repetido'] == true) {
        confirmation =
            'Este reporte ya fue recibido. Consultá su estado en Mis reportes.';
        try {
          final detail = await widget.apiClient.getSeguridad(
            token: widget.token,
            path: '/eventos/${result['id']}',
          );
          confirmation =
              'Reporte ya recibido. Estado actual: ${detail['estado']}.';
        } catch (_) {
          // A detail failure must not suggest resending a successful report.
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(confirmation)));
      try {
        final config = await widget.apiClient.getSeguridad(token: widget.token);
        if (mounted) setState(() => _config = config);
      } catch (_) {
        // The report is already saved; a catalog refresh must not report a failed submission.
      }
    } catch (e) {
      if (mounted) setState(() => _error = message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _report() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_config == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Sin conexión'),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final incident = _type == 'accidente' || _type == 'incidente';
    final categories = maps(_config?['catalogos'])
        .where(
          (c) =>
              c['clase'] == 'categoria' &&
              c['tipo'] == _type &&
              c['activo'] == 1,
        )
        .toList();
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF176C77),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nuevo reporte',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contanos qué ocurrió. Podés incluir empleados de tu sucursal y personas externas. El reporte será revisado antes de publicarse.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          AbsorbPointer(
            absorbing: _busy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '1. Tipo de observación',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de reporte',
                  ),
                  items: types.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _type = v!;
                    _category = null;
                    changed();
                  }),
                ),
                const SizedBox(height: 20),
                Text(
                  '2. Personas involucradas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _selectPeople,
                  child: Text('Seleccionar personas (${_people.length})'),
                ),
                ...maps(_config?['empleados'])
                    .where((p) => _people.contains(p['id']))
                    .map(
                      (p) => Text(
                        '${p['legajo']} — ${p['apellido']} ${p['nombre']}',
                      ),
                    ),
                OutlinedButton(
                  onPressed: _addExternal,
                  child: const Text('Agregar persona externa'),
                ),
                ..._externals.map(
                  (p) => ListTile(
                    title: Text(_externalLabel(p)),
                    subtitle: const Text('Persona externa'),
                    trailing: IconButton(
                      tooltip: 'Quitar persona externa',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _externals.remove(p);
                        changed();
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '3. Datos del evento',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date!,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.parse(
                        _config!['fecha_actual'] as String,
                      ),
                    );
                    if (d != null && mounted) {
                      setState(() {
                        _date = d;
                        changed();
                      });
                    }
                  },
                  child: Text(
                    'Fecha: ${_date!.toIso8601String().substring(0, 10)}',
                  ),
                ),
                if (!incident)
                  DropdownButtonFormField<int>(
                    key: ValueKey(_type),
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'] as int,
                            child: Text(c['nombre'] as String),
                          ),
                        )
                        .toList(),
                    validator: (v) =>
                        v == null ? 'Seleccioná una categoría.' : null,
                    onChanged: (v) => setState(() {
                      _category = v;
                      changed();
                    }),
                  ),
                if (!incident && categories.isEmpty)
                  const Text(
                    'No hay categorías activas. Solicitá su configuración a administración.',
                  ),
                if (_type == 'inseguro')
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey("warned-$_refresh"),
                    initialValue: _warned,
                    decoration: const InputDecoration(
                      labelText: '¿Se advirtió a la persona?',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'si', child: Text('Sí')),
                      DropdownMenuItem(value: 'no', child: Text('No')),
                    ],
                    validator: (v) =>
                        v == null ? 'Seleccioná una respuesta.' : null,
                    onChanged: (v) {
                      _warned = v;
                      changed();
                    },
                  ),
                if (incident) ...[
                  OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime:
                            _time ?? const TimeOfDay(hour: 12, minute: 0),
                      );
                      if (t != null && mounted) {
                        setState(() {
                          _time = t;
                          changed();
                        });
                      }
                    },
                    child: Text(
                      _time == null
                          ? 'Seleccionar hora'
                          : 'Hora: ${_time!.format(context)}',
                    ),
                  ),
                  TextFormField(
                    controller: _place,
                    decoration: const InputDecoration(
                      labelText: 'Lugar del evento',
                    ),
                    maxLength: 180,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Indicá el lugar.' : null,
                    onChanged: (_) => changed(),
                  ),
                  const Text(
                    'Seguridad e Higiene completará la clasificación técnica y el seguimiento.',
                  ),
                  ExpansionTile(
                    title: const Text('Información adicional (opcional)'),
                    children: [
                      for (final entry in const {
                        'clasificacion': 'Clasificación',
                        'atencion': 'Atención recibida',
                        'lesion': 'Lesión',
                        'parte_cuerpo': 'Parte del cuerpo',
                      }.entries)
                        TextFormField(
                          controller: _details[entry.key],
                          maxLength: 180,
                          decoration: InputDecoration(labelText: entry.value),
                          onChanged: (_) => changed(),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  '4. Descripción y fotos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Describí lo observado',
                  ),
                  maxLength: 8000,
                  minLines: 3,
                  maxLines: 6,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Completá la descripción.'
                      : null,
                  onChanged: (_) => changed(),
                ),
                const Text('Fotos opcionales: hasta 5, de 5 MB cada una.'),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pick(true),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Cámara'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pick(false),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ],
                ),
                Wrap(
                  children: [
                    for (var i = 0; i < _photos.length; i++)
                      SizedBox(
                        width: 110,
                        child: Column(
                          children: [
                            Image.memory(
                              _photos[i],
                              width: 100,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, e, st) =>
                                  const Icon(Icons.image_not_supported),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _photos.removeAt(i);
                                changed();
                              }),
                              child: const Text('Quitar'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: Text(_busy ? 'Procesando…' : 'Enviar reporte'),
          ),
        ],
      ),
    );
  }

  void _openHistory(String type, DateTime from, DateTime to) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(types[type]!)),
          body: _SeguridadList(
            api: widget.apiClient,
            token: widget.token,
            mode: 'propio',
            initialType: type,
            initialFrom: from,
            initialTo: to,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seguridad e Higiene')),
        body: _report(),
      );
    }
    return DefaultTabController(
      length: 5,
      initialIndex: _hasDashboard ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seguridad e Higiene'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Mi seguridad'),
              const Tab(text: 'Reportar'),
              const Tab(text: 'Mi historial'),
              const Tab(text: 'Mis reportes'),
              const Tab(text: 'Rankings'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: TabBarView(
              children: [
                SeguridadDashboard(
                  controller: _dashboard,
                  today: DateTime.parse(_config!['fecha_actual'] as String),
                  showHistory: _capabilities['historial_propio'] != false,
                  showIndicators: _capabilities['indicadores'] != false,
                  onHistory: _openHistory,
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _report(),
                  ),
                ),
                _SeguridadList(
                  key: ValueKey('propio-$_refresh'),
                  api: widget.apiClient,
                  token: widget.token,
                  mode: 'propio',
                ),
                _SeguridadList(
                  key: ValueKey('enviados-$_refresh'),
                  api: widget.apiClient,
                  token: widget.token,
                  mode: 'enviados',
                ),
                _SeguridadRanking(
                  api: widget.apiClient,
                  token: widget.token,
                  scopes: List<String>.from(
                    _capabilities['ranking_alcances'] as List? ?? ['empresa'],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeguridadList extends StatefulWidget {
  const _SeguridadList({
    super.key,
    required this.api,
    required this.token,
    required this.mode,
    this.initialType = '',
    this.initialFrom,
    this.initialTo,
  });
  final MobileApiClient api;
  final String token;
  final String mode;
  final String initialType;
  final DateTime? initialFrom;
  final DateTime? initialTo;
  @override
  State<_SeguridadList> createState() => _SeguridadListState();
}

class _SeguridadListState extends State<_SeguridadList> {
  int page = 1;
  late String type = widget.initialType;
  String status = '';
  late DateTime? from = widget.initialFrom;
  late DateTime? to = widget.initialTo;
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = widget.api.getSeguridad(
      token: widget.token,
      path:
          '/eventos?${Uri(queryParameters: {'vista': widget.mode, 'page': '$page', if (type.isNotEmpty) 'tipo': type, if (status.isNotEmpty) 'estado': status, if (from != null) 'desde': seguridadFecha(from!), if (to != null) 'hasta': seguridadFecha(to!)}).query}',
    );
  }

  Future<void> selectDate(bool start) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (start ? from ?? to : to ?? from) ?? DateTime.now(),
      firstDate: start ? DateTime(2000) : from ?? DateTime(2000),
      lastDate: start ? to ?? DateTime(2100, 12, 31) : DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (start) {
        from = date;
      } else {
        to = date;
      }
      page = 1;
      load();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Filtrar por tipo'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Todos')),
            ..._SeguridadPageState.types.entries.map(
              (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
            ),
          ],
          onChanged: (v) => setState(() {
            type = v!;
            page = 1;
            load();
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.mode == 'enviados')
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Todos los estados'),
                    ),
                    for (final state in [
                      'pendiente',
                      'aprobado',
                      'rechazado',
                      'anulado',
                    ])
                      DropdownMenuItem(value: state, child: Text(state)),
                  ],
                  onChanged: (value) => setState(() {
                    status = value!;
                    page = 1;
                    load();
                  }),
                ),
              ),
            OutlinedButton(
              onPressed: () => selectDate(true),
              child: Text(
                from == null ? 'Desde' : 'Desde: ${seguridadFecha(from!)}',
              ),
            ),
            OutlinedButton(
              onPressed: () => selectDate(false),
              child: Text(
                to == null ? 'Hasta' : 'Hasta: ${seguridadFecha(to!)}',
              ),
            ),
            if (from != null || to != null)
              TextButton(
                onPressed: () => setState(() {
                  from = null;
                  to = null;
                  page = 1;
                  load();
                }),
                child: const Text('Limpiar fechas'),
              ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _retry(snapshot.error!, () => setState(load));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            final rows = data['items'] as List;
            return RefreshIndicator(
              onRefresh: () async {
                setState(load);
                await future;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (rows.isEmpty)
                    const ListTile(
                      title: Text('Sin reportes para estos filtros.'),
                    ),
                  ...rows.map(
                    (r) => ListTile(
                      title: Text(_SeguridadPageState.types[r['tipo']] ?? ''),
                      subtitle: Text(
                        '${r['fecha_evento']} · ${r['estado']}\n${r['categoria_nombre']}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _SeguridadDetail(
                            api: widget.api,
                            token: widget.token,
                            id: r['id'] as int,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: page > 1
                            ? () => setState(() {
                                page--;
                                load();
                              })
                            : null,
                        child: const Text('Anterior'),
                      ),
                      Text('Página $page'),
                      TextButton(
                        onPressed:
                            page * (data['per_page'] as int? ?? 30) <
                                (data['total'] as int)
                            ? () => setState(() {
                                page++;
                                load();
                              })
                            : null,
                        child: const Text('Siguiente'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

Widget _retry(Object error, VoidCallback callback) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          error is ApiException
              ? error.message
              : 'No se pudo cargar la información.',
        ),
      ),
      TextButton(onPressed: callback, child: const Text('Reintentar')),
    ],
  ),
);

class _SeguridadDetail extends StatefulWidget {
  const _SeguridadDetail({
    required this.api,
    required this.token,
    required this.id,
  });
  final MobileApiClient api;
  final String token;
  final int id;
  @override
  State<_SeguridadDetail> createState() => _SeguridadDetailState();
}

class _SeguridadDetailState extends State<_SeguridadDetail> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = widget.api.getSeguridad(
      token: widget.token,
      path: '/eventos/${widget.id}',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Reporte #${widget.id}')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _retry(snapshot.error!, () => setState(load));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _SeguridadPageState.types[r['tipo']] ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${r['fecha_evento']} ${r['hora_evento'] ?? ''} · ${r['estado']}',
            ),
            Text('${r['categoria_nombre']}'),
            const SizedBox(height: 12),
            Text('${r['descripcion']}'),
            ...(r['involucrados'] as List).map(
              (p) => ListTile(
                title: Text('${p['legajo']} — ${p['nombre']}'),
                subtitle: Text('${p['sucursal_nombre'] ?? ''}'),
              ),
            ),
            ...(r['externos'] as List? ?? []).map(
              (p) => ListTile(
                title: Text('${p['nombre']}'),
                subtitle: Text(
                  'Persona externa${(p['empresa'] ?? '').isEmpty ? '' : ' — ${p['empresa']}'}',
                ),
              ),
            ),
            ...Map<String, dynamic>.from(r['detalles'] as Map).entries
                .where((e) => e.value != '')
                .map((e) => Text('${e.key}: ${e.value}')),
            ...(r['fotos'] as List).map(
              (p) => _SeguridadPhoto(
                api: widget.api,
                token: widget.token,
                id: p['id'] as int,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _SeguridadPhoto extends StatefulWidget {
  const _SeguridadPhoto({
    required this.api,
    required this.token,
    required this.id,
  });
  final MobileApiClient api;
  final String token;
  final int id;
  @override
  State<_SeguridadPhoto> createState() => _SeguridadPhotoState();
}

class _SeguridadPhotoState extends State<_SeguridadPhoto> {
  late final Future<Uint8List> future = widget.api.getSeguridadFoto(
    token: widget.token,
    id: widget.id,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: future,
    builder: (_, s) => s.hasData
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InteractiveViewer(child: Image.memory(s.data!)),
          )
        : Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              s.hasError ? 'No se pudo cargar la foto.' : 'Cargando foto…',
            ),
          ),
  );
}

class _SeguridadRanking extends StatefulWidget {
  const _SeguridadRanking({
    required this.api,
    required this.token,
    required this.scopes,
  });
  final List<String> scopes;
  final MobileApiClient api;
  final String token;
  @override
  State<_SeguridadRanking> createState() => _SeguridadRankingState();
}

class _SeguridadRankingState extends State<_SeguridadRanking> {
  int year = DateTime.now().year;
  int month = 0;
  String type = 'seguro';
  bool external = false;
  String scope = 'empresa';
  final search = TextEditingController();
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void load() {
    future = widget.api.getSeguridad(
      token: widget.token,
      path:
          '/ranking?anio=$year${month == 0 ? '' : '&mes=$month'}&alcance=$scope',
    );
  }

  @override
  Widget build(BuildContext context) => NestedScrollView(
    headerSliverBuilder: (context, innerBoxIsScrolled) => [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (widget.scopes.contains('sucursal'))
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'Alcance'),
                  items: const [
                    DropdownMenuItem(value: 'empresa', child: Text('Empresa')),
                    DropdownMenuItem(
                      value: 'sucursal',
                      child: Text('Mi sucursal'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    scope = value!;
                    external = false;
                    load();
                  }),
                ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: year,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Año'),
                      items: [
                        for (var y = DateTime.now().year; y >= 2000; y--)
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (v) => setState(() {
                        year = v!;
                        load();
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: month,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Mes'),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('Todo el año'),
                        ),
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(value: m, child: Text('$m')),
                      ],
                      onChanged: (v) => setState(() {
                        month = v!;
                        load();
                      }),
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: type,
                items: const [
                  DropdownMenuItem(
                    value: 'seguro',
                    child: Text('Comportamientos seguros'),
                  ),
                  DropdownMenuItem(
                    value: 'inseguro',
                    child: Text('Comportamientos inseguros'),
                  ),
                ],
                onChanged: (v) => setState(() => type = v!),
              ),
              TextField(
                controller: search,
                decoration: InputDecoration(
                  labelText: external
                      ? 'Buscar nombre o empresa'
                      : 'Buscar persona o legajo',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (scope == 'empresa')
                SwitchListTile(
                  title: const Text('Ranking de personas externas'),
                  value: external,
                  onChanged: (value) => setState(() => external = value),
                ),
              const Text(
                'Conteos de observaciones aprobadas, no una calificación integral de las personas. Seguros e inseguros se muestran por separado y no se compensan.',
              ),
            ],
          ),
        ),
      ),
    ],
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _retry(snapshot.error!, () => setState(load));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final own = (snapshot.data!['mi_posicion'] as Map?)?[type] as Map?;
        final groups =
            snapshot.data![external ? 'rankings_externos' : 'rankings']
                as Map? ??
            {};
        final rows = (groups[type] as List? ?? [])
            .where(
              (r) =>
                  '${r['nombre']} ${r[external ? 'empresa' : 'legajo'] ?? ''}'
                      .toLowerCase()
                      .contains(search.text.toLowerCase()),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            setState(load);
            await future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (!external && snapshot.data!.containsKey('mi_posicion'))
                ListTile(
                  tileColor: Theme.of(context).colorScheme.primaryContainer,
                  title: Text(
                    own == null
                        ? 'Sin observaciones propias en este período'
                        : 'Mi posición: #${own['posicion']}',
                  ),
                  subtitle: own == null
                      ? null
                      : Text('${own['cantidad']} observaciones'),
                ),
              if (rows.isEmpty)
                const ListTile(
                  title: Text('Sin registros para estos filtros.'),
                ),
              ...rows.map(
                (r) => ListTile(
                  selected:
                      !external &&
                      own != null &&
                      r['empleado_id'] == own['empleado_id'],
                  leading: Text('#${r['posicion']}'),
                  title: Text('${r['nombre']}'),
                  subtitle: Text(
                    external
                        ? '${r['empresa'] ?? 'Persona externa'}'
                        : 'Legajo ${r['legajo']}',
                  ),
                  trailing: Text('${r['cantidad']}'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
