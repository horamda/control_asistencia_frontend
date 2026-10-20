import '../widgets/app_submission_bar.dart';
import '../theme/app_visual.dart';
import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/app_page_layout.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/reintegros/reintegros_helpers.dart';

String _error(Object e) => e is ApiException
    ? e.message
    : e is FormatException
    ? e.message
    : 'No se pudo completar la operación. Volvé a intentar.';
String _date(DateTime date) => date.toIso8601String().substring(0, 10);
String _money(dynamic amount) => 'ARS ${amount ?? '0.00'}';
String _state(dynamic state) => reintegroStates[state] ?? '$state';

class ReintegrosPage extends StatefulWidget {
  const ReintegrosPage({super.key, required this.api, required this.token});
  final MobileApiClient api;
  final String token;
  @override
  State<ReintegrosPage> createState() => _ReintegrosPageState();
}

class _ReintegrosPageState extends State<ReintegrosPage> {
  Map<String, dynamic>? config, history;
  List<Map<String, dynamic>> reminders = [];
  String? error;
  bool loading = true, opening = false;
  int page = 1, generation = 0;
  String state = '', period = '';
  DateTime? from, to;
  final periodController = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    periodController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final configuration = await widget.api.getReintegros(token: widget.token);
      final listing = await widget.api.getReintegros(
        token: widget.token,
        path: '/solicitudes',
        query: {
          'page': '$page',
          if (state.isNotEmpty) 'estado': state,
          if (period.isNotEmpty) 'periodo': period,
          if (from != null) 'desde': _date(from!),
          if (to != null) 'hasta': _date(to!),
        },
      );
      if (!mounted || request != generation) return;
      setState(() {
        config = configuration;
        history = listing;
        reminders = reintegroMaps(config!['recordatorios']);
      });
    } catch (e) {
      if (mounted && request == generation) setState(() => error = _error(e));
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> open(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _ReintegroDetail(api: widget.api, token: widget.token, id: id),
      ),
    );
    if (mounted) await load();
  }

  Future<void> create(String month) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final existing = await widget.api.getReintegros(
        token: widget.token,
        path: '/solicitudes',
        query: {'periodo': month},
      );
      if (!mounted) return;
      final rows = reintegroMaps(existing['items']);
      if (rows.isNotEmpty) {
        await open(rows.first['id'] as int);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ReintegroEditor(
              api: widget.api,
              token: widget.token,
              config: config!,
              period: month,
            ),
          ),
        );
        if (mounted) await load();
      }
    } catch (e) {
      if (mounted) setState(() => error = _error(e));
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> selectPeriod() async {
    final monthly = config?['mensual'] as Map? ?? {};
    final periods = (monthly['periodos_habilitados'] as List? ?? [])
        .map((value) => '$value')
        .toList();
    if (periods.isEmpty || loading || opening) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              'Elegí el mes de la rendición',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Podés cargar gastos del mes en curso. Hasta el día 15 inclusive también podés completar y enviar la rendición del mes anterior. Por eso, durante esos días aparecen ambos meses.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            for (final period in periods)
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded),
                title: Text('Abrir $period', textAlign: TextAlign.center),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, period),
              ),
          ],
        ),
      ),
    );
    if (mounted && selected != null) await create(selected);
  }

  Future<void> selectDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? from : to) ?? DateTime.now(),
      firstDate: start ? DateTime(2000) : from ?? DateTime(2000),
      lastDate: start ? to ?? DateTime(2100) : DateTime(2100),
    );
    if (picked == null || !mounted) return;
    if (start) {
      from = picked;
    } else {
      to = picked;
    }
    page = 1;
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final monthly = config?['mensual'] as Map? ?? {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viáticos y reintegros', textAlign: TextAlign.center),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _Body(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (loading) const LinearProgressIndicator(),
              if (error != null) _ErrorBox(message: error!, retry: load),
              if (config != null) ...[
                _Section(
                  title: 'Tus gastos, mes a mes',
                  children: [
                    if (monthly['habilitado'] == true &&
                        (monthly['periodos_habilitados'] as List? ?? [])
                            .isNotEmpty)
                      FilledButton.icon(
                        onPressed: loading || opening ? null : selectPeriod,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          opening ? 'Abriendo\u2026' : 'Cargar gastos',
                        ),
                      ),
                    const Text(
                      'Carg\u00e1 comprobantes, guard\u00e1 un borrador y envi\u00e1 el mes para su revisi\u00f3n.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 8),
                    if (monthly['habilitado'] == true) ...[
                      for (final reopened in reintegroMaps(
                        monthly['reaperturas'],
                      ))
                        TextButton(
                          onPressed: () => open(reopened['id'] as int),
                          child: Text(
                            'Retomar ${reopened['periodo']} · hasta ${reopened['reabierto_hasta']}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Plazos y condiciones'),
                        leading: const Icon(Icons.info_outline_rounded),
                        children: [
                          const Text(
                            'Podés cargar gastos del mes en curso y, hasta el día 15 inclusive, completar y enviar la rendición del mes anterior. Por eso pueden aparecer dos meses disponibles.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Desde el día 16, el mes anterior queda cerrado para cargar o editar, salvo reapertura de Administración. El historial se conserva. Si ya existe una rendición para el mes elegido, se abrirá la misma.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        '${monthly['motivo'] ?? 'Tu sector no está habilitado para cargar rendiciones. Podés consultar el historial y solicitar acceso a Administración.'}',
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
                for (final reminder in reminders)
                  _Section(
                    title: 'Recordatorio · ${reminder['periodo'] ?? ''}',
                    children: [
                      Text(
                        '${reminder['mensaje'] ?? 'Revisá la rendición del mes anterior.'}',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () async {
                                try {
                                  await widget.api.reintegroAction(
                                    token: widget.token,
                                    path:
                                        '/recordatorios/${reminder['id']}/leido',
                                    data: {},
                                  );
                                  if (mounted) {
                                    setState(() => reminders.remove(reminder));
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() => error = _error(e));
                                  }
                                }
                              },
                        child: const Text(
                          'Marcar como leído',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
              ],
              if (config != null)
                _Section(
                  title: 'Mis rendiciones',
                  children: [
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        state.isNotEmpty ||
                                period.isNotEmpty ||
                                from != null ||
                                to != null
                            ? 'Filtros aplicados'
                            : 'Filtrar historial',
                      ),
                      leading: const Icon(Icons.filter_list_rounded),
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: state,
                          isExpanded: true,
                          itemHeight: null,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Todos', textAlign: TextAlign.center),
                            ),
                            for (final entry in reintegroStates.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                          onChanged: loading
                              ? null
                              : (value) {
                                  state = value!;
                                  page = 1;
                                  load();
                                },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: periodController,
                          decoration: const InputDecoration(
                            labelText: 'Período (AAAA-MM)',
                            hintText: '2026-10',
                          ),
                          onSubmitted: (_) => applyPeriod(),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton(
                              onPressed: loading ? null : applyPeriod,
                              child: const Text(
                                'Filtrar mes',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: loading
                                  ? null
                                  : () => selectDate(true),
                              child: Text(
                                from == null
                                    ? 'Creada desde'
                                    : 'Desde ${_date(from!)}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: loading
                                  ? null
                                  : () => selectDate(false),
                              child: Text(
                                to == null
                                    ? 'Creada hasta'
                                    : 'Hasta ${_date(to!)}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : () {
                                      periodController.clear();
                                      period = '';
                                      from = to = null;
                                      page = 1;
                                      load();
                                    },
                              child: const Text(
                                'Limpiar fechas',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              if (history != null && error == null) ...[
                _Section(
                  title: 'Totales del filtro',
                  children: [
                    _Amounts(
                      requested: history!['total_solicitado'],
                      approved: history!['total_aprobado'],
                    ),
                  ],
                ),
                if (reintegroMaps(history!['items']).isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No hay rendiciones para estos filtros.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final item in reintegroMaps(history!['items']))
                  _Section(
                    title: '${item['periodo'] ?? 'Registro anterior'}',
                    children: [
                      Text(
                        _state(item['estado']),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Amounts(
                        requested: item['total_solicitado'],
                        approved: item['total_aprobado'],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Creada: ${item['creado_at'] ?? 'Sin fecha'}',
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Kil\u00f3metros: ${item['kilometros'] ?? 'No informados'}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => open(item['id'] as int),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Ver rendici\u00f3n'),
                      ),
                    ],
                  ),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: !loading && page > 1
                          ? () {
                              page--;
                              load();
                            }
                          : null,
                      child: const Text(
                        'Anterior',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text('Página $page', textAlign: TextAlign.center),
                    TextButton(
                      onPressed:
                          !loading &&
                              page * (history!['per_page'] as int? ?? 30) <
                                  (history!['total'] as int? ?? 0)
                          ? () {
                              page++;
                              load();
                            }
                          : null,
                      child: const Text(
                        'Siguiente',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void applyPeriod() {
    final value = periodController.text.trim();
    if (value.isNotEmpty &&
        !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
      setState(() => error = 'Indicá el período como AAAA-MM.');
      return;
    }
    period = value;
    page = 1;
    load();
  }
}

class _ReintegroDetail extends StatefulWidget {
  const _ReintegroDetail({
    required this.api,
    required this.token,
    required this.id,
  });
  final MobileApiClient api;
  final String token;
  final int id;
  @override
  State<_ReintegroDetail> createState() => _ReintegroDetailState();
}

class _ReintegroDetailState extends State<_ReintegroDetail> {
  Map<String, dynamic>? detail, config;
  String? error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        widget.api.getReintegros(
          token: widget.token,
          path: '/solicitudes/${widget.id}',
        ),
        widget.api.getReintegros(token: widget.token),
      ]);
      if (mounted) {
        setState(() {
          detail = result[0];
          config = result[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel() async {
    if (!await _confirm(
      context,
      'Cancelar rendición',
      'Se conservará el historial y no podrás crear otra rendición para este mes.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final updated = await widget.api.reintegroAction(
        token: widget.token,
        path: '/solicitudes/${widget.id}/acciones',
        data: {'accion': 'cancelar', 'revision': detail!['revision']},
      );
      if (mounted) {
        setState(() {
          detail = updated;
          error = null;
        });
      }
    } catch (e) {
      await load();
      if (mounted) {
        setState(
          () => error =
              '${_error(e)} Se consultó el estado vigente; revisalo antes de volver a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final monthly = config?['mensual'] as Map? ?? {};
    final today = '${monthly['fecha_actual'] ?? ''}';
    final deadline = [
      d?['fecha_cierre'],
      d?['reabierto_hasta'],
    ].whereType<String>().toList()..sort();
    final canCancel =
        monthly['habilitado'] == true &&
        ['borrador', 'devuelta', 'pendiente'].contains(d?['estado']) &&
        (d?['periodo'] == null ||
            (today.isNotEmpty &&
                deadline.isNotEmpty &&
                today.compareTo(deadline.last) <= 0));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Rendición ${d?['periodo'] ?? '#${widget.id}'}',
          textAlign: TextAlign.center,
        ),
        actions: [
          IconButton(
            onPressed: busy ? null : load,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _Body(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              _ErrorBox(message: error!, retry: busy ? null : load),
            if (d != null) ...[
              _Section(
                title: _state(d['estado']),
                children: [
                  _Amounts(
                    requested: d['total_solicitado'],
                    approved: d['total_aprobado'],
                  ),
                  Text(
                    'Kilómetros: ${d['kilometros'] ?? 'No informados'}',
                    textAlign: TextAlign.center,
                  ),
                  if (d['fecha_cierre'] != null)
                    Text(
                      'Cierre: ${d['fecha_cierre']}',
                      textAlign: TextAlign.center,
                    ),
                  if (d['reabierto_hasta'] != null)
                    Text(
                      'Reabierta hasta: ${d['reabierto_hasta']}',
                      textAlign: TextAlign.center,
                    ),
                  if (d['motivo'] != null)
                    Text('Motivo: ${d['motivo']}', textAlign: TextAlign.center),
                  if (d['observaciones'] != null)
                    Text('${d['observaciones']}', textAlign: TextAlign.center),
                  if (d['fecha_pago'] != null)
                    Text(
                      'Pago: ${d['fecha_pago']} · ${d['referencia_pago'] ?? ''}',
                      textAlign: TextAlign.center,
                    ),
                  if (['borrador', 'devuelta'].contains(d['estado']) &&
                      d['puede_editar_empleado'] != true)
                    const Text(
                      'Edición no habilitada. Consultá el plazo y la habilitación de tu sector con Administración.',
                      textAlign: TextAlign.center,
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (d['puede_editar_empleado'] == true &&
                          monthly['habilitado'] == true)
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => ReintegroEditor(
                                        api: widget.api,
                                        token: widget.token,
                                        config: config!,
                                        period: d['periodo'] as String?,
                                        initial: d,
                                      ),
                                    ),
                                  );
                                  if (mounted) await load();
                                },
                          child: const Text(
                            'Editar rendición',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (canCancel)
                        OutlinedButton(
                          onPressed: busy ? null : cancel,
                          child: const Text(
                            'Cancelar rendición',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              for (final warning in reintegroMaps(d['advertencias']))
                _Section(
                  title: 'Revisá este comprobante',
                  children: [
                    Text('${warning['mensaje']}', textAlign: TextAlign.center),
                  ],
                ),
              if (d['foto_odometro_id'] != null)
                _Section(
                  title: 'Odómetro',
                  children: [
                    _PrivatePhoto(
                      api: widget.api,
                      token: widget.token,
                      id: d['foto_odometro_id'] as int,
                      odometer: true,
                    ),
                  ],
                ),
              for (final expense in reintegroMaps(d['gastos']))
                _Section(
                  title: '${expense['concepto'] ?? 'Gasto sin descripción'}',
                  children: [
                    Text(
                      '${expense['fecha'] ?? 'Sin fecha'} · ${expense['categoria_nombre'] ?? 'Sin concepto'}',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      expense['importe'] == null
                          ? 'Importe sin completar'
                          : _money(expense['importe']),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Comprobante: ${expense['numero_comprobante'] ?? '—'} · ${expense['emisor'] ?? '—'}',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Decisión: ${expense['decision'] ?? 'pendiente'}',
                      textAlign: TextAlign.center,
                    ),
                    if (expense['motivo'] != null)
                      Text('${expense['motivo']}', textAlign: TextAlign.center),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final photo in reintegroMaps(expense['fotos']))
                          _PrivatePhoto(
                            api: widget.api,
                            token: widget.token,
                            id: photo['id'] as int,
                          ),
                      ],
                    ),
                  ],
                ),
              _Section(
                title: 'Historial',
                children: [
                  for (final event in reintegroMaps(d['historial']))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${_actionLabel('${event['accion']}')} · ${event['fecha'] ?? event['creado_at'] ?? ''}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _actionLabel(String action) =>
    const {
      'crear_admin': 'Creado por administración',
      'editar_admin': 'Editado por administración',
      'reabrir': 'Plazo reabierto',
      'crear': 'Creada',
      'editar': 'Editada',
      'enviar': 'Enviada',
      'borrador': 'Borrador guardado',
      'aprobar': 'Aprobada',
      'rechazar': 'Rechazada',
      'devolver': 'Devuelta',
      'pagar': 'Pago registrado',
      'cancelar': 'Cancelada',
    }[action] ??
    action;

class _Expense {
  _Expense([Map<String, dynamic> data = const {}])
    : date = data['fecha'] as String?,
      category = data['categoria_id'] as int?,
      categoryName = data['categoria_nombre'] as String?,
      description = TextEditingController(
        text: data['concepto'] as String? ?? '',
      ),
      amount = TextEditingController(text: data['importe'] as String? ?? ''),
      number = TextEditingController(
        text: data['numero_comprobante'] as String? ?? '',
      ),
      issuer = TextEditingController(text: data['emisor'] as String? ?? ''),
      existing = reintegroMaps(
        data['fotos'],
      ).map((p) => p['id'] as int).toList();
  String? date;
  int? category;
  String? categoryName;
  final TextEditingController description, amount, number, issuer;
  final List<int> existing;
  final photos = <Uint8List>[];
  void dispose() {
    for (final controller in [description, amount, number, issuer]) {
      controller.dispose();
    }
  }

  Map<String, dynamic> json() => {
    'fecha': date,
    'categoria_id': category,
    'concepto': description.text.trim(),
    'importe': reintegroAmount(amount.text),
    'numero_comprobante': number.text.trim(),
    'emisor': issuer.text.trim(),
    'fotos_existentes': existing.toList(),
  };
}

class ReintegroEditor extends StatefulWidget {
  const ReintegroEditor({
    super.key,
    required this.api,
    required this.token,
    required this.config,
    required this.period,
    this.initial,
    this.picker,
  });
  final MobileApiClient api;
  final String token;
  final Map<String, dynamic> config;
  final String? period;
  final Map<String, dynamic>? initial;
  final ImagePicker? picker;
  @override
  State<ReintegroEditor> createState() => _ReintegroEditorState();
}

class _ReintegroEditorState extends State<ReintegroEditor>
    with WidgetsBindingObserver {
  late Map<String, dynamic> catalog;
  bool refreshing = false;
  final expenses = <_Expense>[];
  late final TextEditingController km, notes;
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  Uint8List? odometer;
  bool removeOdometer = false,
      busy = false,
      dirty = false,
      leaving = false,
      blocked = false;
  int? conflictId;
  String? error, signature;
  String uuid = const Uuid().v4();
  int get maxExpenses => (catalog['limites'] as Map?)?['gastos'] as int? ?? 50;
  List<Map<String, dynamic>> get concepts {
    final items = reintegroMaps(catalog['conceptos'] ?? catalog['categorias'])
        .where(
          (c) => c['activo'] == null || c['activo'] == 1 || c['activo'] == true,
        )
        .toList();
    items.sort(
      (a, b) => '${a['nombre']}'.toLowerCase().compareTo(
        '${b['nombre']}'.toLowerCase(),
      ),
    );
    return items;
  }

  @override
  void initState() {
    super.initState();
    catalog = widget.config;
    WidgetsBinding.instance.addObserver(this);
    expenses.addAll(reintegroMaps(widget.initial?['gastos']).map(_Expense.new));
    km = TextEditingController(text: '${widget.initial?['kilometros'] ?? ''}');
    notes = TextEditingController(
      text: widget.initial?['observaciones'] as String? ?? '',
    );
    refreshCatalog();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy && !refreshing) {
      refreshCatalog();
    }
  }

  Future<bool> refreshCatalog() async {
    if (refreshing) return false;
    setState(() => refreshing = true);
    try {
      final updated = await widget.api.getReintegros(token: widget.token);
      if (!mounted) return false;
      setState(() => catalog = updated);
      return true;
    } catch (e) {
      if (mounted) {
        setState(
          () => error = '${_error(e)} Tus datos siguen en el formulario.',
        );
        revealError();
      }
      return false;
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Future<void> selectConcept(_Expense expense) async {
    if (!await refreshCatalog() || !mounted) return;
    var search = '';
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final matches = concepts
              .where(
                (c) => '${c['nombre']}'.toLowerCase().contains(
                  search.trim().toLowerCase(),
                ),
              )
              .toList();
          // Use a bounded dialog and one scroll view. AlertDialog's intrinsic
          // measurement cannot safely measure a nested lazy viewport on web.
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: SizedBox(
              width: 440,
              height: 520,
              child: ListView(
                primary: false,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Elegir concepto',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Buscar concepto',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => update(() => search = value),
                  ),
                  const SizedBox(height: 16),
                  // Keep dismiss actions reachable even with a long catalog.
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, -1),
                        child: const Text(
                          'Dejar sin concepto',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (matches.isEmpty)
                    Text(
                      concepts.isEmpty
                          ? 'No hay conceptos disponibles. Contactá a Administración.'
                          : 'No hay coincidencias.',
                      textAlign: TextAlign.center,
                    ),
                  for (final c in matches)
                    ListTile(
                      title: Text(
                        '${c['nombre']}',
                        textAlign: TextAlign.center,
                      ),
                      selected: expense.category == c['id'],
                      trailing: expense.category == c['id']
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(context, c['id'] as int),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      expense.category = selected == -1 ? null : selected;
      expense.categoryName = selected == -1
          ? null
          : '${concepts.firstWhere((c) => c['id'] == selected)['nombre']}';
      dirty = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    km.dispose();
    notes.dispose();
    for (final e in expenses) {
      e.dispose();
    }
    super.dispose();
  }

  void changed() {
    setState(() => dirty = true);
  }

  void revealError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  Future<void> pick(_Expense? expense, ImageSource source) async {
    setState(() => busy = true);
    try {
      final picker = widget.picker ?? ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('La foto supera 5 MB.');
      }
      final photo = await compute(
        compressReintegroPhoto,
        await file.readAsBytes(),
      );
      if (!mounted) return;
      setState(() {
        if (expense == null) {
          odometer = photo;
          removeOdometer = false;
        } else {
          expense.photos.add(photo);
        }
        dirty = true;
      });
    } catch (e) {
      if (mounted) setState(() => error = _error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseDate(_Expense expense) async {
    final today = DateTime.parse(
      '${(catalog['mensual'] as Map)['fecha_actual']}',
    );
    final first = widget.period == null
        ? DateTime(2000)
        : DateTime.parse('${widget.period}-01');
    final lastOfMonth = widget.period == null
        ? today
        : DateTime(first.year, first.month + 1, 0);
    final last = lastOfMonth.isBefore(today) ? lastOfMonth : today;
    final initial = DateTime.tryParse(expense.date ?? '') ?? last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : initial.isAfter(last)
          ? last
          : initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) {
      setState(() {
        expense.date = _date(picked);
        dirty = true;
      });
    }
  }

  Future<void> save(bool send) async {
    if (busy || blocked || refreshing) return;
    if (!await refreshCatalog() || !mounted) return;
    if ((catalog['mensual'] as Map?)?['habilitado'] != true) {
      setState(
        () => error =
            'Tu sector no está habilitado para guardar. Tus datos siguen en el formulario.',
      );
      revealError();
      return;
    }
    if (!form.currentState!.validate()) {
      setState(
        () => error = 'Revisá los importes de los gastos antes de guardar.',
      );
      revealError();
      return;
    }
    Map<String, dynamic> data;
    final photos = <String, List<Uint8List>>{};
    try {
      final kilometers = km.text.trim().isEmpty
          ? null
          : int.tryParse(km.text.trim());
      if (km.text.trim().isNotEmpty &&
          (kilometers == null || kilometers < 0 || kilometers > 1000000)) {
        throw const FormatException(
          'Kilómetros: ingresá un entero entre 0 y 1.000.000 o dejá vacío.',
        );
      }
      for (var i = 0; i < expenses.length; i++) {
        final e = expenses[i];
        if (e.category != null && !concepts.any((c) => c['id'] == e.category)) {
          throw FormatException(
            'El concepto del gasto ${i + 1} ya no está disponible. Elegí otro o dejalo sin concepto para guardar un borrador.',
          );
        }
        final amount = reintegroAmount(e.amount.text);
        if (send &&
            (e.date == null ||
                e.description.text.trim().isEmpty ||
                amount == null ||
                (widget.period != null &&
                    !concepts.any((c) => c['id'] == e.category)) ||
                e.existing.length + e.photos.length == 0)) {
          throw FormatException(
            'Completá el gasto ${i + 1}: fecha, concepto, descripción, importe y al menos una foto.',
          );
        }
        photos['fotos_$i'] = e.photos.toList();
      }
      if (odometer != null) photos['odometro'] = [odometer!];
      if (photos.values.expand((p) => p).fold<int>(0, (n, p) => n + p.length) >
          20 * 1024 * 1024) {
        throw const FormatException(
          'Las fotos superan 20 MB. Quitá algunas o elegí imágenes más pequeñas.',
        );
      }
      data = {
        'accion': send ? 'enviar' : 'borrador',
        if (widget.period != null) 'periodo': widget.period,
        if (widget.initial != null) 'revision': widget.initial!['revision'],
        'kilometros': kilometers,
        'observaciones': notes.text.trim(),
        'quitar_odometro': removeOdometer ? '1' : '0',
        'gastos': expenses.map((e) => e.json()).toList(),
      };
      final nextSignature =
          '${jsonEncode(data)}${photos.entries.map((e) => '${e.key}:${e.value.map(sha256.convert).join(',')}').join('|')}';
      if (signature != null && signature != nextSignature) {
        uuid = const Uuid().v4();
      }
      signature = nextSignature;
      data['envio_id'] = uuid;
    } catch (e) {
      setState(() => error = _error(e));
      revealError();
      return;
    }
    if (send &&
        !await _confirm(
          context,
          'Enviar rendición',
          'Al enviar quedará pendiente de aprobación y no podrás editarla hasta que sea devuelta. ¿Continuar?',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await widget.api.saveReintegro(
        token: widget.token,
        id: widget.initial?['id'] as int?,
        data: data,
        photos: photos,
      );
      final result = widget.initial == null
          ? Map<String, dynamic>.from(response['solicitud'] as Map)
          : response;
      if (!mounted) return;
      setState(() {
        dirty = false;
        leaving = true;
      });
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _ReintegroDetail(
            api: widget.api,
            token: widget.token,
            id: result['id'] as int,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = _error(e);
        blocked =
            widget.initial != null || e is ApiException && e.statusCode == 409;
      });
      if (blocked) await reconcile();
      if (e is ApiException && (e.statusCode == 400 || e.statusCode == 403)) {
        await refreshCatalog();
      }
      revealError();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reconcile() async {
    try {
      if (widget.initial != null) {
        final remote = await widget.api.getReintegros(
          token: widget.token,
          path: '/solicitudes/${widget.initial!['id']}',
        );
        if (!mounted) return;
        setState(() {
          blocked =
              remote['revision'] != widget.initial!['revision'] ||
              remote['puede_editar_empleado'] != true;
          conflictId = remote['id'] as int;
        });
      } else {
        final response = await widget.api.getReintegros(
          token: widget.token,
          path: '/solicitudes',
          query: {'periodo': widget.period!},
        );
        final rows = reintegroMaps(response['items']);
        if (mounted) {
          setState(() {
            conflictId = rows.isEmpty ? null : rows.first['id'] as int;
          });
        }
      }
      if (mounted && blocked) {
        setState(
          () => error =
              '${error ?? ''}\nSe necesita revisar la versión del servidor. Tus cambios permanecen en esta pantalla.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              '${error ?? ''}\nNo se pudo verificar el resultado. Consultá el servidor antes de volver a guardar.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var cents = 0;
    for (final e in expenses) {
      try {
        final value = reintegroAmount(e.amount.text);
        if (value != null) cents += int.parse(value.replaceAll('.', ''));
      } catch (_) {
        /* Invalid input is reported on save. */
      }
    }
    return PopScope(
      canPop: leaving || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || busy) return;
        if (await _confirm(
          context,
          'Salir sin guardar',
          'Los cambios de esta pantalla se perderán. Podés volver y guardarlos como borrador.',
        )) {
          if (mounted) {
            setState(() => leaving = true);
            await WidgetsBinding.instance.endOfFrame;
            if (context.mounted) Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Rendición ${widget.period ?? 'histórica'}',
            textAlign: TextAlign.center,
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar conceptos',
              onPressed: busy || refreshing ? null : refreshCatalog,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        bottomNavigationBar: AppSubmissionBar(
          summary:
              'Total orientativo: ARS ${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}',
          actions: [
            OutlinedButton(
              onPressed: busy || blocked || refreshing
                  ? null
                  : () => save(false),
              child: const Text(
                'Guardar borrador',
                textAlign: TextAlign.center,
              ),
            ),
            FilledButton(
              onPressed: busy || blocked || refreshing
                  ? null
                  : () => save(true),
              child: const Text(
                'Enviar rendición',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        body: _Body(
          child: Form(
            key: form,
            onChanged: changed,
            child: ListView(
              controller: scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: 3,
                  child: busy || refreshing
                      ? const LinearProgressIndicator()
                      : null,
                ),
                if (error != null)
                  _ErrorBox(
                    message: error!,
                    retry: blocked && !busy
                        ? () async {
                            setState(() => busy = true);
                            await reconcile();
                            if (mounted) setState(() => busy = false);
                          }
                        : null,
                  ),
                if (blocked && conflictId != null)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _ReintegroDetail(
                                api: widget.api,
                                token: widget.token,
                                id: conflictId!,
                              ),
                            ),
                          ),
                    child: const Text(
                      'Consultar versión del servidor',
                      textAlign: TextAlign.center,
                    ),
                  ),
                AbsorbPointer(
                  absorbing: busy || blocked || refreshing,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Gastos del mes',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Agregá cada gasto con su importe y comprobante para solicitar el reintegro.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (expenses.isEmpty)
                        const _Section(
                          title: 'Todavía no agregaste gastos',
                          children: [
                            Text(
                              'Usá «Agregar gasto» para empezar. También podés presentar solo tus recorridos.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      for (var i = 0; i < expenses.length; i++)
                        expenseCard(expenses[i], i),
                      OutlinedButton.icon(
                        onPressed: expenses.length >= maxExpenses
                            ? null
                            : () => setState(() {
                                expenses.add(_Expense());
                                dirty = true;
                              }),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          'Agregar gasto (${expenses.length}/$maxExpenses)',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Recorridos del mes',
                        children: [
                          const Text(
                            'Kilómetros opcionales: dejá vacío si no corresponde. Cero significa que no hubo recorridos.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: km,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Kilómetros (opcional)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (odometer != null)
                            Image.memory(odometer!, height: 130),
                          if (odometer == null &&
                              !removeOdometer &&
                              widget.initial?['foto_odometro_id'] != null)
                            _PrivatePhoto(
                              api: widget.api,
                              token: widget.token,
                              id: widget.initial!['foto_odometro_id'] as int,
                              odometer: true,
                            ),
                          photoButtons(null),
                          if (odometer != null ||
                              !removeOdometer &&
                                  widget.initial?['foto_odometro_id'] != null)
                            TextButton(
                              onPressed: () => setState(() {
                                odometer = null;
                                removeOdometer = true;
                                dirty = true;
                              }),
                              child: const Text(
                                'Quitar foto de odómetro',
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Resumen',
                        children: [
                          Text(
                            'Total orientativo: ARS ${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            'El servidor confirma el total. Los kilómetros no suman dinero. Podés presentar una rendición sin gastos.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: notes,
                            maxLength: 2000,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Observaciones (opcional)',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget photoButtons(_Expense? expense) => AppAdaptiveActions(
    minWidth: 180,
    children: [
      for (final source in [ImageSource.camera, ImageSource.gallery])
        OutlinedButton.icon(
          onPressed:
              expense != null &&
                  expense.existing.length + expense.photos.length >= 3
              ? null
              : () => pick(expense, source),
          icon: Icon(
            source == ImageSource.camera
                ? Icons.camera_alt_rounded
                : Icons.photo_library_rounded,
          ),
          label: Text(
            '${source == ImageSource.camera ? 'Cámara' : 'Galería'}${expense == null ? ' · odómetro' : ''}',
            textAlign: TextAlign.center,
          ),
        ),
    ],
  );
  Widget expenseCard(_Expense e, int index) => _Section(
    key: ObjectKey(e),
    title: 'Gasto ${index + 1}',
    children: [
      AppAdaptiveActions(
        minWidth: 260,
        children: [
          OutlinedButton(
            onPressed: () => chooseDate(e),
            child: Text(
              e.date ?? 'Seleccionar fecha',
              textAlign: TextAlign.start,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => selectConcept(e),
            icon: const Icon(Icons.search_rounded),
            label: Text(
              'Concepto: ${concepts.where((c) => c['id'] == e.category).firstOrNull?['nombre'] ?? e.categoryName ?? 'Seleccionar'}',
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
      if (e.category != null && !concepts.any((c) => c['id'] == e.category))
        Text(
          'El concepto seleccionado ya no está disponible. Elegí otro o dejalo sin concepto para guardar un borrador.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.start,
        ),
      if (concepts.isEmpty)
        const Text(
          'No hay conceptos disponibles. Contactá a Administración.',
          textAlign: TextAlign.start,
        ),
      const SizedBox(height: 16),
      TextFormField(
        controller: e.description,
        maxLength: 500,
        minLines: 1,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Descripción del gasto'),
      ),
      TextFormField(
        controller: e.amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Importe en ARS',
          hintText: '1250,50',
        ),
        validator: (value) {
          try {
            reintegroAmount(value ?? '');
            return null;
          } catch (e) {
            return _error(e);
          }
        },
      ),
      const SizedBox(height: 16),
      ExpansionTile(
        key: ValueKey('receipt-details-$index'),
        tilePadding: EdgeInsets.zero,
        title: const Text('Datos del comprobante'),
        subtitle: const Text('Opcionales: n\u00famero y emisor'),
        initiallyExpanded: e.number.text.isNotEmpty || e.issuer.text.isNotEmpty,
        children: [
          TextFormField(
            controller: e.number,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Número de comprobante (opcional)',
            ),
          ),
          TextFormField(
            controller: e.issuer,
            maxLength: 180,
            decoration: const InputDecoration(labelText: 'Emisor (opcional)'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Comprobantes: hasta 3 fotos. Al enviar se necesita al menos una.',
        textAlign: TextAlign.start,
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final id in e.existing)
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PrivatePhoto(api: widget.api, token: widget.token, id: id),
                  TextButton(
                    onPressed: () => setState(() {
                      e.existing.remove(id);
                      dirty = true;
                    }),
                    child: const Text(
                      'Quitar foto',
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ),
          for (final photo in e.photos)
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.memory(photo, height: 110),
                  TextButton(
                    onPressed: () => setState(() {
                      e.photos.remove(photo);
                      dirty = true;
                    }),
                    child: const Text(
                      'Quitar foto',
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      photoButtons(e),
      TextButton.icon(
        onPressed: () async {
          if (await _confirm(
            context,
            'Quitar gasto',
            'Se quitará este gasto y sus comprobantes de la rendición al guardar.',
          )) {
            if (mounted) {
              setState(() {
                expenses.remove(e);
                e.dispose();
                dirty = true;
              });
            }
          }
        },
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Quitar gasto', textAlign: TextAlign.start),
      ),
    ],
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

class _Amounts extends StatelessWidget {
  const _Amounts({required this.requested, required this.approved});
  final dynamic requested;
  final dynamic approved;
  @override
  Widget build(BuildContext context) => AppAdaptiveActions(
    minWidth: 220,
    children: [
      for (final entry in {
        'Solicitado': requested,
        'Aprobado': approved,
      }.entries)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(entry.key, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                _money(entry.value),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
    ],
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: child,
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppVisual.sectionTitle,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Reintentar')),
      ],
    ),
  );
}

class _PrivatePhoto extends StatefulWidget {
  const _PrivatePhoto({
    required this.api,
    required this.token,
    required this.id,
    this.odometer = false,
  });
  final MobileApiClient api;
  final String token;
  final int id;
  final bool odometer;
  @override
  State<_PrivatePhoto> createState() => _PrivatePhotoState();
}

class _PrivatePhotoState extends State<_PrivatePhoto> {
  late Future<Uint8List> bytes;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    bytes = widget.api.getReintegroPhoto(
      token: widget.token,
      id: widget.id,
      odometer: widget.odometer,
    );
  }

  @override
  void didUpdateWidget(covariant _PrivatePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.token != widget.token ||
        oldWidget.odometer != widget.odometer) {
      load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: bytes,
    builder: (context, result) {
      if (result.hasError) {
        return SizedBox(
          width: 140,
          child: TextButton(
            onPressed: () => setState(load),
            child: const Text('Reintentar foto', textAlign: TextAlign.center),
          ),
        );
      }
      if (!result.hasData) {
        return const SizedBox(
          width: 100,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Semantics(
        button: true,
        label: 'Ampliar comprobante',
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.memory(
                        result.data!,
                        errorBuilder: (_, __, ___) => const Text(
                          'Imagen no disponible',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar', textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
          child: Image.memory(
            result.data!,
            width: 140,
            height: 110,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('Imagen no disponible', textAlign: TextAlign.center),
          ),
        ),
      );
    },
  );
}
