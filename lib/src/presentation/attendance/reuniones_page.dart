import '../theme/app_visual.dart';
import 'reuniones_monthly_page.dart';
import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/network/reuniones_models.dart';
import '../../core/reuniones/reunion_reminders.dart';
import '../../core/reuniones/push_service.dart';
import '../../core/reuniones/reunion_navigation.dart';
import 'qr_scan_page.dart';
import '../theme/app_palette.dart';
import 'widgets/reuniones_dashboard.dart';

Future<bool> registerReunionQr(
  BuildContext context,
  MobileApiClient api,
  String token,
  String qr,
) async {
  try {
    final result = await api.registrarReunion(token: token, qr: qr);
    if (!context.mounted) return true;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result['ya_registrado'] == true
              ? 'Ya estabas registrado'
              : 'Asistencia registrada',
        ),
        content: Text(
          [
            result['reunion'],
            reunionStateLabel(result['estado'] as String?),
            reunionDateTime(result['registrado_at']),
            result['sucursal_nombre'],
            result['lugar'],
          ].whereType<String>().where((s) => s.isNotEmpty).join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    return true;
  } catch (error) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se pudo registrar'),
          content: Text(
            error is ApiException
                ? error.message
                : 'No se pudo confirmar el registro. Comprobá tu conexión y volvé a escanear el QR vigente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
    return false;
  }
}

class ReunionesPage extends StatefulWidget {
  const ReunionesPage({
    super.key,
    required this.api,
    required this.token,
    required this.onClockQr,
    required this.onChanged,
  });
  final MobileApiClient api;
  final String token;
  final Future<void> Function(String) onClockQr;
  final Future<void> Function() onChanged;
  @override
  State<ReunionesPage> createState() => _ReunionesPageState();
}

class _ReunionesPageState extends State<ReunionesPage>
    with WidgetsBindingObserver {
  int _tab = 0, _page = 1, _request = 0;
  int? _reunionId;
  DateTimeRange? _range;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _definitions = [];
  String? _error;
  bool _loading = true, _scanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReunionNavigation.refresh.addListener(_refreshFromPush);
    _load();
    _loadDefinitions();
  }

  @override
  void dispose() {
    ReunionNavigation.refresh.removeListener(_refreshFromPush);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_scanning) _load();
  }

  void _refreshFromPush() {
    if (mounted && !_scanning) unawaited(_load());
  }

  Future<void> _loadDefinitions() async {
    try {
      final data = await widget.api.getReuniones(token: widget.token);
      if (mounted) setState(() => _definitions = reunionMaps(data['items']));
    } catch (_) {
      /* The selected tab exposes errors and a retry. */
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, String>{
        if (_tab == 0) 'semanas': '4',
        if (_tab == 2) ...{
          'page': '$_page',
          'per': '20',
          if (_reunionId != null) 'reunion_id': '$_reunionId',
        },
        if (_tab >= 2 && _range != null) ...{
          'desde': _date(_range!.start),
          'hasta': _date(_range!.end),
        },
      };
      final data = await widget.api.getReuniones(
        token: widget.token,
        path: ['/proximas', '', '/historial', '/estadisticas'][_tab],
        query: query,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      if (_tab == 1) _definitions = reunionMaps(data['items']);
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = e is ApiException
            ? e.message
            : 'No se pudieron cargar las reuniones.';
      });
    }
  }

  String _date(DateTime date) => date.toIso8601String().substring(0, 10);
  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final qr = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => const QrScanPage(
            title: 'Escanear QR',
            instruction: 'Apuntá al QR de la reunión o del punto de fichada.',
          ),
        ),
      );
      if (!mounted || qr == null) return;
      if (isReunionQr(qr)) {
        await registerReunionQr(context, widget.api, widget.token, qr);
        await widget.onChanged();
        if (mounted) await _load();
      } else {
        await widget.onClockQr(qr);
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _range,
    );
    if (!mounted || range == null) return;
    if (_tab == 3 && range.end.difference(range.start).inDays >= 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El rango máximo es de 366 días.',
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }
    setState(() {
      _range = range;
      _page = 1;
    });
    await _load();
  }

  Future<void> _enableReminders() async {
    try {
      final allowed = PushService.instance.active
          ? await PushService.instance.enable()
          : await ReunionReminders.instance.requestPermission();
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allowed
                ? 'Notificaciones activadas.'
                : 'Las notificaciones no están habilitadas. Podés permitirlas desde los ajustes del dispositivo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron activar los recordatorios. Intentá nuevamente.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis reuniones', textAlign: TextAlign.center),
      actions: [
        if (ReunionReminders.instance.supported ||
            PushService.instance.supported)
          IconButton(
            onPressed: _enableReminders,
            tooltip: 'Activar recordatorios',
            icon: const Icon(Icons.notifications_active_outlined),
          ),
      ],
    ),
    floatingActionButton:
        !reunionMaps(_data?['items']).any((e) => e['puede_registrar'] == true)
        ? null
        : MediaQuery.sizeOf(context).height < 500 ||
              MediaQuery.textScalerOf(context).scale(14) > 20
        ? FloatingActionButton(
            onPressed: _scanning ? null : _scan,
            tooltip: 'Escanear QR',
            child: _scanning
                ? const CircularProgressIndicator()
                : const Icon(Icons.qr_code_scanner),
          )
        : FloatingActionButton.extended(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(),
                  )
                : const Icon(Icons.qr_code_scanner),
            label: Text(
              _scanning ? 'Registrando…' : 'Escanear QR',
              textAlign: TextAlign.center,
            ),
          ),
    body: ReunionesViewport(
      child: RefreshIndicator(
        onRefresh: () async {
          await _load();
          await widget.onChanged();
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            100 + MediaQuery.textScalerOf(context).scale(24),
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final (i, label) in [
                    'Próximas',
                    'Mis reuniones',
                    'Historial',
                    'Estadísticas',
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label, textAlign: TextAlign.center),
                        selected: _tab == i,
                        onSelected: (_) {
                          setState(() {
                            _tab = i;
                            _page = 1;
                            _data = null;
                            if (i == 3 &&
                                _range != null &&
                                _range!.end.difference(_range!.start).inDays >=
                                    366) {
                              _range = null;
                            }
                          });
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('Calendario y resumen mensual'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReunionesMonthlyPage(
                    api: widget.api,
                    token: widget.token,
                    onOpen: _detail,
                  ),
                ),
              ),
            ),
            if (_tab >= 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _range == null
                            ? 'Filtrar fechas'
                            : '${reunionDateTime(_date(_range!.start))} – ${reunionDateTime(_date(_range!.end))}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_range != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _range = null;
                            _page = 1;
                          });
                          _load();
                        },
                        child: const Text(
                          'Quitar fechas',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_tab == 2)
                      DropdownButton<int>(
                        isExpanded: true,
                        value: _reunionId ?? 0,
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text(
                              'Todas las reuniones',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          for (final item in _definitions)
                            DropdownMenuItem(
                              value: (item['id'] as num).toInt(),
                              child: Text(
                                item['nombre'].toString(),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          setState(() {
                            _reunionId = id == 0 ? null : id;
                            _page = 1;
                          });
                          _load();
                        },
                      ),
                  ],
                ),
              ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null) ...[
              Text(_error!, textAlign: TextAlign.center),
              TextButton(
                onPressed: _load,
                child: const Text('Reintentar', textAlign: TextAlign.center),
              ),
            ] else if (_data != null)
              ..._content(),
          ],
        ),
      ),
    ),
  );
  List<Widget> _content() {
    if (_tab == 3) {
      return [
        Text(
          'Período: ${reunionDateTime(_data!['periodo']?['desde'])} – ${reunionDateTime(_data!['periodo']?['hasta'])}',
          textAlign: TextAlign.center,
        ),
        ReunionStats(data: Map<String, dynamic>.from(_data!['totales'] ?? {})),
        ReunionesResponsiveGrid(
          children: [
            for (final item in reunionMaps(_data!['por_reunion']))
              ReunionStats(data: item, title: item['nombre']?.toString()),
          ],
        ),
      ];
    }
    final items = reunionMaps(_data!['items']);
    return [
      if (_tab == 0)
        ReunionesAgendaOverview(
          items: items.map(ReunionOccurrence.new).toList(),
          onScan:
              _scanning ||
                  !reunionMaps(
                    _data?['items'],
                  ).any((e) => e['puede_registrar'] == true)
              ? null
              : _scan,
          onDetail: _detail,
        ),
      if (_tab == 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              (ReunionReminders.instance.supported ||
                  PushService.instance.supported)
              ? OutlinedButton.icon(
                  onPressed: _enableReminders,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text(
                    'Activar notificaciones',
                    textAlign: TextAlign.center,
                  ),
                )
              : const Text(
                  'Los recordatorios con la app cerrada están disponibles en Android y iOS.',
                  textAlign: TextAlign.center,
                ),
        ),
      if (_tab == 0 && _data!['resumen'] is Map)
        ReunionWeekSummary(data: Map<String, dynamic>.from(_data!['resumen'])),
      if (_tab == 0 && PushService.instance.supported)
        ValueListenableBuilder<String>(
          valueListenable: PushService.instance.status,
          builder: (_, status, _) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(status, textAlign: TextAlign.center),
          ),
        ),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No hay reuniones para mostrar.',
            textAlign: TextAlign.center,
          ),
        ),
      ReunionesResponsiveGrid(
        children: [
          for (final item in items)
            if (_tab == 0)
              ReunionOccurrenceCard(
                item: ReunionOccurrence(item),
                onScan:
                    _scanning ||
                        !reunionMaps(
                          _data?['items'],
                        ).any((e) => e['puede_registrar'] == true)
                    ? null
                    : _scan,
                onDetail: () => _detail(item['reunion_id'] as int),
              )
            else if (_tab == 1)
              AppCard(
                child: ListTile(
                  title: Text(
                    item['nombre']?.toString() ?? 'Reunión',
                    textAlign: TextAlign.center,
                  ),
                  subtitle: Text(
                    [
                      item['descripcion_frecuencia'],
                      item['sucursal_nombre'],
                      item['lugar'],
                      'Próxima: ${reunionDateTime(item['proxima_fecha'])}',
                      if (item['mis_estadisticas'] is Map)
                        'Asistencia histórica: ${item['mis_estadisticas']['asistencia_pct'] == null ? 'Sin datos' : '${item['mis_estadisticas']['asistencia_pct']}%'}',
                    ].whereType<String>().join('\n'),
                    textAlign: TextAlign.center,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _detail(item['id'] as int),
                ),
              )
            else
              ReunionHistoryCard(item: item),
        ],
      ),
      if (_tab == 2)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            TextButton(
              onPressed: _page > 1
                  ? () {
                      _page--;
                      _load();
                    }
                  : null,
              child: const Text('Anterior', textAlign: TextAlign.center),
            ),
            Text('Página $_page', textAlign: TextAlign.center),
            TextButton(
              onPressed:
                  _page * ((_data!['per_page'] as num?)?.toInt() ?? 20) <
                      ((_data!['total'] as num?)?.toInt() ?? 0)
                  ? () {
                      _page++;
                      _load();
                    }
                  : null,
              child: const Text('Siguiente', textAlign: TextAlign.center),
            ),
          ],
        ),
    ];
  }

  Future<void> _detail(int id) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ReunionDetailPage(api: widget.api, token: widget.token, id: id),
    ),
  );
}

Color reunionColor(String state) => ReunionStatusBadge.color(state);

class ReunionOccurrenceCard extends StatelessWidget {
  const ReunionOccurrenceCard({
    super.key,
    required this.item,
    this.onScan,
    this.onDetail,
  });
  final ReunionOccurrence item;
  final VoidCallback? onScan, onDetail;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppVisual.cardRadius),
      side: BorderSide(
        color: AppColors.of(context).border(
          item.estado == 'abierta'
              ? AppPalette.blue.withValues(alpha: .5)
              : AppPalette.border,
        ),
      ),
    ),
    child: DefaultTextStyle.merge(
      style: AppVisual.body,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width:
                      54 *
                      (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                        1,
                        1.5,
                      ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.of(
                      context,
                    ).surface(AppPalette.blue.withValues(alpha: .07)),
                    borderRadius: BorderRadius.circular(AppVisual.cardRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        item.fecha.substring(8),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.of(
                                context,
                              ).foreground(AppPalette.navy),
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        const [
                          'ENE',
                          'FEB',
                          'MAR',
                          'ABR',
                          'MAY',
                          'JUN',
                          'JUL',
                          'AGO',
                          'SEP',
                          'OCT',
                          'NOV',
                          'DIC',
                        ][int.parse(item.fecha.substring(5, 7)) - 1],
                        style: TextStyle(
                          color: AppColors.of(
                            context,
                          ).foreground(AppPalette.muted),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: onDetail,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            item.nombre,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.of(
                                    context,
                                  ).foreground(AppPalette.navy),
                                  decoration: item.cancelada
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      ReunionStatusBadge(state: item.estado),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${reunionDateTime(item.data['inicio'])} · ${item.data['fin']?.toString().substring(11, 16) ?? ''} (hora Argentina)',
              textAlign: TextAlign.start,
            ),
            if (item.location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: AppColors.of(context).foreground(AppPalette.muted),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.location,
                        style: TextStyle(
                          color: AppColors.of(
                            context,
                          ).foreground(AppPalette.muted),
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              ),
            if (item.estado == 'pendiente')
              Text(
                'Se habilita: ${reunionDateTime(item.data['ventana_desde'])}',
                textAlign: TextAlign.start,
              ),
            if (item.estado == 'ausente' && item.data['definitivo'] != true)
              const Text(
                'Estado provisorio hasta el cierre del servidor.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.start,
              ),
            for (final key in [
              'motivo_cambio',
              'motivo_cancelacion',
              'observaciones',
            ])
              if (item.data[key] != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.of(
                      context,
                    ).surface(AppPalette.warning.withValues(alpha: .07)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.data[key].toString(),
                    style: TextStyle(
                      color: AppColors.of(
                        context,
                      ).foreground(AppPalette.warning),
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
            if (item.data['fecha_original'] != null)
              Text(
                'Fecha original: ${reunionDateTime(item.data['fecha_original'])}',
                textAlign: TextAlign.start,
              ),
            for (final overlap in reunionMaps(item.data['superpuesta_con']))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Se superpone con ${overlap['nombre']} · ${reunionDateTime(overlap['inicio'])}',
                  textAlign: TextAlign.start,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (item.data['registrado_at'] != null)
              Text(
                'Registro: ${reunionDateTime(item.data['registrado_at'])}',
                textAlign: TextAlign.start,
              ),
            if (item.data['puede_registrar'] == true && !item.cancelada)
              FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear QR', textAlign: TextAlign.start),
              ),
          ],
        ),
      ),
    ),
  );
}

class ReunionHistoryCard extends StatelessWidget {
  const ReunionHistoryCard({super.key, required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            item['nombre']?.toString() ?? 'Reunión',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          Text(
            '${reunionDateTime(item['fecha'])} · ${item['inicio'] ?? ''} – ${item['fin'] ?? ''}',
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ReunionStatusBadge(state: item['estado']?.toString() ?? ''),
          ),
          for (final key in ['sucursal_nombre', 'lugar', 'observaciones'])
            if (item[key] != null)
              Text(item[key].toString(), textAlign: TextAlign.center),
          if (item['fecha_original'] != null)
            Text(
              'Fecha original: ${reunionDateTime(item['fecha_original'])}',
              textAlign: TextAlign.center,
            ),
          if (item['registrado_at'] != null)
            Text(
              'Registro: ${reunionDateTime(item['registrado_at'])}',
              textAlign: TextAlign.center,
            ),
          if (item['metodo'] != null)
            Text(
              'Método: ${const {'qr_fijo': 'QR fijo', 'qr_dinamico': 'QR dinámico', 'manual': 'RR. HH.', 'sistema': 'Sistema'}[item['metodo']] ?? item['metodo']}',
              textAlign: TextAlign.center,
            ),
        ],
      ),
    ),
  );
}

class ReunionStats extends StatelessWidget {
  const ReunionStats({super.key, required this.data, this.title});
  final Map<String, dynamic> data;
  final String? title;
  num? _percent(String key) =>
      data[key] is num ? data[key] as num : num.tryParse('${data[key] ?? ''}');
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.symmetric(vertical: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: AppColors.of(context).border(AppPalette.border)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title ?? 'Tu participación',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.of(context).foreground(AppPalette.navy),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 480;
              final width = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    width: width,
                    child: ReunionPercentPanel(
                      label: 'Asistencia',
                      value: _percent('asistencia_pct'),
                      color: AppPalette.blue,
                      caption: 'Sobre convocatorias no justificadas',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: ReunionPercentPanel(
                      label: 'Puntualidad',
                      value: _percent('puntualidad_pct'),
                      color: AppPalette.success,
                      caption: 'A tiempo sobre reuniones asistidas',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final entry in const {
                'convocatorias': 'Convocatorias',
                'presentes': 'Presentes',
                'tarde': 'Tarde',
                'ausentes': 'Ausentes',
                'justificados': 'Justificados',
                'asistidas': 'Asistidas',
                'horas_asistidas': 'Horas asistidas',
                'minutos_asistidos': 'Minutos asistidos',
              }.entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surface(AppPalette.background),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${entry.value}: ${data[entry.key] ?? 0}',
                    style: TextStyle(
                      color: AppColors.of(context).foreground(AppPalette.muted),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ReunionDetailPage extends StatefulWidget {
  const ReunionDetailPage({
    super.key,
    required this.api,
    required this.token,
    required this.id,
  });
  final MobileApiClient api;
  final String token;
  final int id;
  @override
  State<ReunionDetailPage> createState() => _ReunionDetailPageState();
}

class _ReunionDetailPageState extends State<ReunionDetailPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getReuniones(
        token: widget.token,
        path: '/${widget.id}',
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'No se pudo cargar la reunión.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle de reunión', textAlign: TextAlign.center),
    ),
    body: ReunionesViewport(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _load,
                      child: const Text(
                        'Reintentar',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else if (_data case final d?) ...[
                    Text(
                      d['nombre']?.toString() ?? 'Reunión',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (d['activa'] == false)
                      const Text(
                        'Reunión desactivada · consulta del historial',
                        textAlign: TextAlign.center,
                      ),
                    for (final key in [
                      'descripcion',
                      'descripcion_frecuencia',
                      'sucursal_nombre',
                      'lugar',
                    ])
                      if (d[key] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            d[key].toString(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    Text(
                      'QR: ${d['qr_modo'] ?? '—'}',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Registro desde ${d['tolerancia_antes_min'] ?? 0} min antes · tarde después de ${d['tarde_despues_min'] ?? 0} min',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      d['cierre_despues_min'] == null
                          ? 'El registro cierra al finalizar la reunión.'
                          : 'El registro cierra ${d['cierre_despues_min']} min después del inicio.',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Días no laborables: ${const {'posponer': 'Se pospone', 'omitir': 'No se realiza', 'mantener': 'Se mantiene'}[d['feriado_accion']] ?? 'Según calendario'}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text('Próximas fechas', textAlign: TextAlign.center),
                    Text(
                      (d.containsKey('proximas_ocurrencias')
                              ? reunionMaps(
                                  d['proximas_ocurrencias'],
                                ).map((e) => e['inicio'] ?? e['fecha']).toList()
                              : (d['proximas_fechas'] as List? ?? []))
                          .map(reunionDateTime)
                          .join(' · '),
                      textAlign: TextAlign.center,
                    ),
                    if (d['mis_estadisticas'] is Map)
                      ReunionStats(
                        data: Map<String, dynamic>.from(d['mis_estadisticas']),
                        title: 'Últimos 90 días',
                      )
                    else
                      const Text(
                        'Sin estadísticas para el período.',
                        textAlign: TextAlign.center,
                      ),
                    const Text(
                      'Últimas asistencias',
                      textAlign: TextAlign.center,
                    ),
                    ReunionesResponsiveGrid(
                      children: [
                        for (final item in reunionMaps(d['historial']))
                          ReunionHistoryCard(item: item),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}
