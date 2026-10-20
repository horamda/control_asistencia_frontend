import 'package:flutter/material.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/reuniones/notifications_navigation.dart';
import '../../core/utils/date_formatter.dart';
import '../widgets/app_card.dart';

List<Map<String, dynamic>> vacationItems(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
String vacationDate(dynamic value) =>
    DateFormatter.formatApiDateForDisplay(value?.toString());
String vacationError(Object e) => e is ApiException
    ? e.message
    : 'No se pudo completar la operación. Volvé a intentar.';

class VacacionesPage extends StatefulWidget {
  const VacacionesPage({
    super.key,
    required this.apiClient,
    required this.token,
    this.initialId,
    this.team = false,
  });
  final MobileApiClient apiClient;
  final String token;
  final int? initialId;
  final bool team;
  @override
  State<VacacionesPage> createState() => _VacacionesPageState();
}

class _VacacionesPageState extends State<VacacionesPage> {
  int year = DateTime.now().year;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int tab = 0, request = 0;
  bool loading = true;
  String? error, teamError;
  Map<String, dynamic> data = {}, team = {};
  String teamView = 'Pendientes';
  String get monthKey =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    tab = widget.team ? 2 : 0;
    load();
    if (widget.initialId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => detail(widget.initialId!, team: widget.team),
      );
    }
  }

  Future<void> load() async {
    final generation = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.apiClient.getVacationWorkflow(
        token: widget.token,
        team: tab == 2,
        path: tab == 0
            ? '/semanas'
            : tab == 1
            ? '/solicitudes'
            : teamView == 'Calendario'
            ? '/calendario'
            : teamView == 'Saldos'
            ? '/saldos'
            : '',
        query: tab == 2 && teamView == 'Calendario'
            ? {'mes': monthKey}
            : {
                'anio': '$year',
                if (tab == 2 && teamView == 'Pendientes') 'estado': 'pendiente',
              },
      );
      if (!mounted || generation != request) return;
      setState(() {
        data = result;
        loading = false;
      });
    } catch (e) {
      if (mounted && generation == request) {
        setState(() {
          error = vacationError(e);
          loading = false;
        });
      }
    }
    try {
      final result = await widget.apiClient.getVacationWorkflow(
        token: widget.token,
        team: true,
        path: '',
        query: {'anio': '$year', 'estado': 'pendiente'},
      );
      if (mounted && generation == request) {
        setState(() {
          team = result;
          teamError = null;
        });
      }
    } catch (e) {
      if (mounted && generation == request) {
        setState(() => teamError = vacationError(e));
      }
    }
  }

  Future<void> detail(int id, {bool team = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VacationRequestPage(
          api: widget.apiClient,
          token: widget.token,
          id: id,
          team: team,
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> selectWeeks() async {
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) =>
            VacationWeekPicker(api: widget.apiClient, token: widget.token),
      ),
    );
    if (!mounted) return;
    if (id != null) {
      tab = 1;
      await detail(id);
    } else {
      await load();
    }
  }

  Widget card(Widget child) => AppCard(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
  Widget requestCard(Map<String, dynamic> item) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tab == 2)
          Text(
            '${(item['empleado'] as Map?)?['nombre'] ?? ''}',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.start,
          ),
        Text(
          'Solicitud #${item['id']} · ${item['estado'] ?? ''}',
          textAlign: TextAlign.start,
        ),
        for (final t in vacationItems(item['tandas']))
          Text(
            '${vacationDate(t['fecha_desde'])} — ${vacationDate(t['fecha_hasta'])} · ${t['dias']} días',
            textAlign: TextAlign.start,
          ),
        if (item['cancelacion_pedida'] == true)
          const Text(
            'Cancelación pendiente de aprobación',
            textAlign: TextAlign.start,
          ),
        TextButton(
          onPressed: () => detail((item['id'] as num).toInt(), team: tab == 2),
          child: const Text('Ver solicitud'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final hasTeam = team['alcance'] != null && team['alcance'] != 'sin_equipo';
    final saldo = data['saldo'] as Map? ?? {};
    final items = vacationItems(data['items']);
    return Scaffold(
      appBar: AppBar(title: const Text('Vacaciones')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in {
                        0: 'Mi saldo',
                        1: 'Mis solicitudes',
                        if (hasTeam || widget.team)
                          2: 'Mi equipo (${team['por_resolver'] ?? 0})',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: tab == entry.key,
                          onSelected: loading
                              ? null
                              : (_) {
                                  setState(() => tab = entry.key);
                                  load();
                                },
                        ),
                    ],
                  ),
                  if (teamError != null)
                    TextButton(
                      onPressed: load,
                      child: const Text(
                        'No se pudo consultar Mi equipo. Reintentar',
                      ),
                    ),
                  if (tab == 2)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        for (final view in [
                          'Pendientes',
                          'Todas',
                          'Calendario',
                          'Saldos',
                        ])
                          ChoiceChip(
                            label: Text(view),
                            selected: teamView == view,
                            onSelected: loading
                                ? null
                                : (_) {
                                    setState(() => teamView = view);
                                    load();
                                  },
                          ),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Anterior',
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  if (tab == 2 && teamView == 'Calendario') {
                                    month = DateTime(
                                      month.year,
                                      month.month - 1,
                                    );
                                  } else {
                                    year--;
                                  }
                                });
                                load();
                              },
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Flexible(
                        child: Text(
                          tab == 2 && teamView == 'Calendario'
                              ? monthKey
                              : '$year',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Siguiente',
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  if (tab == 2 && teamView == 'Calendario') {
                                    month = DateTime(
                                      month.year,
                                      month.month + 1,
                                    );
                                  } else {
                                    year++;
                                  }
                                });
                                load();
                              },
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else if (error != null)
                    card(
                      Column(
                        children: [
                          Text(error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: load,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  else if (tab == 0) ...[
                    card(
                      Column(
                        children: [
                          Text(
                            '${saldo['semanas_disponibles'] ?? '—'} semanas disponibles',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${saldo['dias_disponibles'] ?? '—'} días de saldo · ${saldo['dias_pendientes'] ?? '—'} pendientes',
                            textAlign: TextAlign.center,
                          ),
                          if ((saldo['dias_fuera_de_semanas'] as num? ?? 0) > 0)
                            Text(
                              '${saldo['dias_fuera_de_semanas']} días para coordinar con RR. HH.',
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: selectWeeks,
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('Pedir vacaciones'),
                          ),
                        ],
                      ),
                    ),
                    if (data['feriados_cargados'] == false)
                      card(
                        const Text(
                          'Las fechas pueden ajustarse si hay feriados. El calendario de este año todavía no está cargado.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    card(
                      Text(
                        '${data['reglas'] ?? 'Seleccioná semanas completas. El servidor determina las fechas y el saldo.'}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else if (items.isEmpty)
                    card(
                      const Text(
                        'No hay registros para este período.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (tab == 2 && teamView == 'Saldos')
                    ...items.map(
                      (e) => card(
                        Column(
                          children: [
                            Text(
                              '${(e['empleado'] as Map?)?['nombre'] ?? ''}',
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              e['error']?.toString() ??
                                  '${e['semanas_disponibles'] ?? '—'} semanas · ${e['dias_disponibles'] ?? '—'} días disponibles',
                              textAlign: TextAlign.center,
                            ),
                            if (e['error'] == null)
                              Text(
                                'Tomados: ${e['dias_tomados'] ?? '—'} · Pendientes: ${e['dias_pendientes'] ?? '—'}',
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    )
                  else if (tab == 2 && teamView == 'Calendario')
                    ...items.map(
                      (e) => card(
                        Column(
                          children: [
                            Text(
                              '${(e['empleado'] as Map?)?['nombre'] ?? ''}',
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '${vacationDate(e['fecha_desde'])} — ${vacationDate(e['fecha_hasta'])}',
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '${e['estado'] ?? ''}',
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: () => detail(
                                (e['solicitud_id'] as num).toInt(),
                                team: true,
                              ),
                              child: const Text('Ver solicitud'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...items.map(requestCard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VacationWeekPicker extends StatefulWidget {
  const VacationWeekPicker({super.key, required this.api, required this.token});
  final MobileApiClient api;
  final String token;
  @override
  State<VacationWeekPicker> createState() => _VacationWeekPickerState();
}

class _VacationWeekPickerState extends State<VacationWeekPicker> {
  final selected = <String>{};
  final observation = TextEditingController();
  final calendars = <Map<String, dynamic>>[];
  bool loading = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    observation.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final now = DateTime.now();
      final result = await Future.wait([
        for (final y in [now.year, if (now.month >= 10) now.year + 1])
          widget.api.getVacationWorkflow(
            token: widget.token,
            query: {'anio': '$y'},
          ),
      ]);
      if (!mounted) return;
      setState(() {
        calendars
          ..clear()
          ..addAll(result);
        final available = result
            .expand((c) => vacationItems(c['semanas']))
            .where((w) => w['estado'] == 'disponible')
            .map((w) => '${w['lunes']}')
            .toSet();
        selected.retainAll(available);
      });
    } catch (e) {
      if (mounted) setState(() => error = vacationError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (saving || selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Confirmar solicitud'),
        content: Text(
          'Vas a pedir ${selected.length} semanas. Las tandas y sus fechas definitivas se mostrarán al enviar la solicitud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.api.postVacationWorkflow(
        token: widget.token,
        path: '/semanas',
        body: {
          'semanas': selected.toList()..sort(),
          'observaciones': observation.text.trim(),
        },
      );
      NotificationsNavigation.refresh.value++;
      if (mounted) Navigator.pop(context, (result['id'] as num).toInt());
    } catch (e) {
      if (mounted) setState(() => error = vacationError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pedir vacaciones')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Elegí semanas completas. Podés combinar semanas seguidas o separadas.',
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                Text(error!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: saving ? null : load,
                  child: const Text('Actualizar disponibilidad'),
                ),
              ],
              if (loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                for (final c in calendars) ...[
                  Text(
                    '${c['anio']} · ${(c['saldo'] as Map?)?['semanas_disponibles'] ?? 0} semanas disponibles',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (c['feriados_cargados'] == false)
                    const Text(
                      'Las fechas pueden ajustarse si hay feriados.',
                      textAlign: TextAlign.center,
                    ),
                  for (final w in vacationItems(
                    c['semanas'],
                  ).where((w) => w['estado'] != 'pasada'))
                    Builder(
                      builder: (context) {
                        final monday = '${w['lunes']}';
                        final count = vacationItems(c['semanas'])
                            .where((v) => selected.contains('${v['lunes']}'))
                            .length;
                        final limit =
                            ((c['saldo'] as Map?)?['semanas_disponibles']
                                        as num? ??
                                    0)
                                .toInt();
                        final enabled =
                            !saving &&
                            w['estado'] == 'disponible' &&
                            (selected.contains(monday) || count < limit);
                        return CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selected.contains(monday),
                          onChanged: enabled
                              ? (v) => setState(() {
                                  if (v == true) {
                                    selected.add(monday);
                                  } else {
                                    selected.remove(monday);
                                  }
                                })
                              : null,
                          title: Text(
                            '${vacationDate(w['inicio'] ?? w['lunes'])} — ${vacationDate(w['fin'] ?? w['domingo'])}',
                          ),
                          subtitle: Text(
                            w['feriado_lunes'] != null
                                ? 'Inicio ajustado por ${w['feriado_lunes']}. Fechas mostradas para esta semana sola.'
                                : '${w['estado']}',
                          ),
                        );
                      },
                    ),
                ],
                TextField(
                  controller: observation,
                  enabled: !saving,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: selected.isEmpty || saving ? null : submit,
                  child: Text(
                    saving
                        ? 'Enviando…'
                        : 'Solicitar ${selected.length} semanas',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class VacationRequestPage extends StatefulWidget {
  const VacationRequestPage({
    super.key,
    required this.api,
    required this.token,
    required this.id,
    this.team = false,
  });
  final MobileApiClient api;
  final String token;
  final int id;
  final bool team;
  @override
  State<VacationRequestPage> createState() => _VacationRequestPageState();
}

class _VacationRequestPageState extends State<VacationRequestPage> {
  Map<String, dynamic>? data;
  bool loading = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.getVacationWorkflow(
        token: widget.token,
        team: widget.team,
        path: '/solicitudes/${widget.id}',
      );
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = vacationError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> act(String action, String title, {int? movement}) async {
    final requiredReason = action.endsWith('rechazar');
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: reason,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: requiredReason
                  ? 'Motivo obligatorio'
                  : 'Motivo (opcional)',
            ),
            validator: (v) => requiredReason && (v?.trim().isEmpty ?? true)
                ? 'Ingresá el motivo'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    // Wait for the dialog transition before disposing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    reason.dispose();
    if (!mounted || confirmed != true || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.postVacationWorkflow(
        token: widget.token,
        team: widget.team,
        path: '/solicitudes/${widget.id}/$action',
        body: {
          if (text.isNotEmpty) 'motivo': text,
          if (movement != null) 'movimiento_id': movement,
        },
      );
      NotificationsNavigation.refresh.value++;
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = vacationError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      appBar: AppBar(title: Text('Solicitud #${widget.id}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (loading) const Center(child: CircularProgressIndicator()),
                if (error != null) ...[
                  Text(error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: saving ? null : load,
                    child: const Text('Reintentar'),
                  ),
                ],
                if (!loading && d != null) ...[
                  Text(
                    '${(d['empleado'] as Map?)?['nombre'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${d['estado']} · ${d['dias']} días',
                    textAlign: TextAlign.center,
                  ),
                  if (d['observacion'] != null)
                    Text('${d['observacion']}', textAlign: TextAlign.center),
                  for (final t in vacationItems(d['tandas']))
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              '${vacationDate(t['fecha_desde'])} — ${vacationDate(t['fecha_hasta'])}',
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '${t['dias']} días · ${t['estado']}',
                              textAlign: TextAlign.center,
                            ),
                            if (t['inicio_corrido'] == true)
                              const Text(
                                'Inicio ajustado por día no laborable.',
                                textAlign: TextAlign.center,
                              ),
                            if (t['cancelacion_pedida'] == true)
                              const Text(
                                'Cancelación pendiente de aprobación',
                                textAlign: TextAlign.center,
                              ),
                            for (final key in [
                              'motivo_resolucion',
                              'resuelto_por',
                              'cancelacion_motivo',
                            ])
                              if (t[key] != null)
                                Text('${t[key]}', textAlign: TextAlign.center),
                            if (!widget.team &&
                                d['puede_cancelar'] == true &&
                                t['empezo'] != true &&
                                t['cancelacion_pedida'] != true &&
                                ['pendiente', 'aprobado'].contains(t['estado']))
                              TextButton(
                                onPressed: saving
                                    ? null
                                    : () => act(
                                        'cancelar',
                                        t['estado'] == 'aprobado'
                                            ? 'Pedir cancelación'
                                            : 'Cancelar tanda',
                                        movement: (t['movimiento_id'] as num)
                                            .toInt(),
                                      ),
                                child: Text(
                                  t['estado'] == 'aprobado'
                                      ? 'Pedir cancelación'
                                      : 'Cancelar tanda',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.team)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (d['puede_resolver'] == true) ...[
                          FilledButton(
                            onPressed: saving
                                ? null
                                : () => act('aprobar', 'Aprobar solicitud'),
                            child: const Text('Aprobar'),
                          ),
                          OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => act('rechazar', 'Rechazar solicitud'),
                            child: const Text('Rechazar'),
                          ),
                        ],
                        if (d['puede_resolver_cancelacion'] == true) ...[
                          FilledButton(
                            onPressed: saving
                                ? null
                                : () => act(
                                    'cancelacion/aprobar',
                                    'Aceptar cancelación',
                                  ),
                            child: const Text('Aceptar cancelación'),
                          ),
                          OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => act(
                                    'cancelacion/rechazar',
                                    'Mantener vacaciones',
                                  ),
                            child: const Text('Mantener vacaciones'),
                          ),
                        ],
                      ],
                    ),
                  if (saving) const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
