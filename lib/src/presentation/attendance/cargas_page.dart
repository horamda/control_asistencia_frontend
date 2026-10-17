import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'package:ficharqr/src/presentation/theme/app_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/mobile_api_client.dart';

class CargasPage extends StatefulWidget {
  const CargasPage({
    super.key,
    required this.apiClient,
    required this.token,
    this.imagePicker,
  });
  final MobileApiClient apiClient;
  final String token;
  final ImagePicker? imagePicker;
  @override
  State<CargasPage> createState() => _CargasPageState();
}

class _CargasPageState extends State<CargasPage> {
  final _form = GlobalKey<FormState>();
  final _consolidado = TextEditingController();
  final _observaciones = TextEditingController();
  final _fotos = <Uint8List>[];
  Map<String, dynamic>? _config;
  List<Map<String, dynamic>> _rows = [];
  int? _camion;
  bool? _valida;
  String _tipo = 'inicial';
  String _envioId = const Uuid().v4();
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _picking = false;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _consolidado.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(dynamic value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> _load({String? operationError}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = operationError;
    });
    final refreshErrors = <String>[];
    try {
      final config = await widget.apiClient.getCargas(
        token: widget.token,
        path: '/config',
      );
      if (!mounted) return;
      setState(() {
        _config = config;
        if (!_maps(config['camiones']).any((t) => t['id'] == _camion)) {
          _camion = null;
        }
      });
    } catch (e) {
      refreshErrors.add(
        'No se pudo actualizar la configuración: ${_message(e)}',
      );
    }
    if (!mounted) return;
    try {
      final history = await widget.apiClient.getCargas(
        token: widget.token,
        path: '?page=$_page',
      );
      if (!mounted) return;
      setState(() {
        _rows = _maps(history['items']);
        _total = history['total'] as int;
      });
    } catch (e) {
      refreshErrors.add('No se pudo actualizar el historial: ${_message(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          final messages = [
            if (operationError != null) operationError,
            ...refreshErrors,
          ];
          _error = messages.isEmpty ? null : messages.join('\n');
        });
      }
    }
  }

  Future<void> _handleOperationError(Object error) async {
    if (!mounted) return;
    final message = _message(error);
    if (error is ApiException &&
        const [403, 404, 409].contains(error.statusCode)) {
      _page = 1;
      await _load(operationError: message);
    } else {
      setState(() => _error = message);
    }
  }

  String _message(Object e) => e is ApiException
      ? e.message
      : 'No se pudo completar la operación. Intente nuevamente.';
  void _changed() {
    _envioId = const Uuid().v4();
  }

  int get _maxFotos => _limit('max_fotos', 5);
  int get _maxFotoBytes => _limit('max_foto_bytes', 5 * 1024 * 1024);

  int _limit(String key, int fallback) {
    final value = _config?[key];
    return value is int && value >= 0 ? value : fallback;
  }

  String get _photoLimits =>
      'Hasta $_maxFotos imágenes JPG, PNG o WEBP de $_photoSizeLimit cada una.';

  String get _photoSizeLimit {
    if (_maxFotoBytes < 1024) return '$_maxFotoBytes bytes';
    if (_maxFotoBytes < 1024 * 1024) {
      return '${(_maxFotoBytes / 1024).toStringAsFixed(2)} KB';
    }
    return '${(_maxFotoBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  bool get _canAddPhotos => _fotos.length < _maxFotos && _maxFotoBytes > 0;

  bool get _photosWithinLimits =>
      _fotos.length <= _maxFotos &&
      _fotos.every((foto) => foto.length <= _maxFotoBytes);

  Future<void> _pick(bool camera) async {
    if (!_canAddPhotos || _picking || _sending || _loading) return;
    setState(() => _picking = true);
    try {
      final picker = widget.imagePicker ?? ImagePicker();
      final List<XFile> selected;
      if (camera) {
        final file = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1800,
          imageQuality: 85,
        );
        selected = file == null ? [] : [file];
      } else {
        selected = await picker.pickMultiImage(
          maxWidth: 1800,
          imageQuality: 85,
        );
      }
      if (selected.isEmpty) return;
      if (selected.length + _fotos.length > _maxFotos) throw Exception('limit');
      final bytes = <Uint8List>[];
      for (final file in selected) {
        if (await file.length() > _maxFotoBytes) throw Exception('size');
        final data = await file.readAsBytes();
        if (data.length > _maxFotoBytes) throw Exception('size');
        bytes.add(data);
      }
      if (mounted) {
        setState(() {
          _fotos.addAll(bytes);
          _error = null;
          _changed();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudieron agregar las fotos. $_photoLimits Revise también el permiso de cámara/galería.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _loading || _picking || _config?['habilitado'] != true) {
      return;
    }
    if (!_photosWithinLimits) {
      setState(
        () => _error =
            'Las fotos seleccionadas superan los límites actuales. $_photoLimits Quite las fotos que excedan estos límites.',
      );
      return;
    }
    if (!_form.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar validación', textAlign: TextAlign.center),
        content: Text(
          '${_truckLabel(_maps(_config?['camiones']).firstWhere((t) => t['id'] == _camion))}\n'
          '${_tipo == 'inicial' ? 'Carga inicial' : 'Recarga'} · Consolidado ${_consolidado.text.trim()}\n'
          '¿Valida la carga? ${_valida! ? 'Sí' : 'No'}\n\nLa fecha y hora se registrarán al recibir el envío. La respuesta quedará en el historial.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Revisar', textAlign: TextAlign.center),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await widget.apiClient.createCarga(
        token: widget.token,
        fields: {
          'camion_id': '$_camion',
          'tipo': _tipo,
          'consolidado': _consolidado.text.trim(),
          'valida': _valida.toString(),
          'observaciones': _observaciones.text.trim(),
          'envio_id': _envioId,
          'origen': kIsWeb ? 'web' : 'app',
        },
        fotos: List.of(_fotos),
      );
      if (!mounted) return;
      final row = Map<String, dynamic>.from(result['registro'] as Map);
      setState(() {
        _consolidado.clear();
        _observaciones.clear();
        _fotos.clear();
        _valida = null;
        _tipo = 'recarga';
        _page = 1;
        _changed();
      });
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            result['repetido'] == true
                ? 'Registro #${row['id']} ya recibido'
                : 'Registro #${row['id']} guardado',
            textAlign: TextAlign.center,
          ),
          content: Text(
            '${result['repetido'] == true ? 'El envío ya estaba registrado. No se creó un duplicado.\n' : ''}'
            '${_date(row['registrado_at'])}\n'
            '${row['en_horario'] == 1 ? 'En término' : 'Fuera de horario'}\n'
            'Respuesta: ${row['valida'] == 1 ? 'Sí valida' : 'No valida'}',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aceptar', textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    } catch (e) {
      // Conservar UUID y fotos para reintentar sin duplicar una respuesta perdida.
      await _handleOperationError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _date(dynamic raw) {
    final value = DateTime.tryParse('$raw');
    if (value == null) return '$raw';
    final ar = value.toUtc().subtract(const Duration(hours: 3));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(ar.day)}/${two(ar.month)}/${ar.year} ${two(ar.hour)}:${two(ar.minute)} (AR)';
  }

  Future<void> _detail(Map<String, dynamic> item) async {
    try {
      final row = await widget.apiClient.getCargas(
        token: widget.token,
        path: '/${item['id']}',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text('Validación #${row['id']}', textAlign: TextAlign.center),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _badge(
                        row['valida'] == 1 ? 'S\u00ed valida' : 'No valida',
                        Icons.fact_check_rounded,
                        negative: row['valida'] != 1,
                      ),
                      _badge(
                        row['en_horario'] == 1
                            ? 'En t\u00e9rmino'
                            : 'Fuera de horario',
                        Icons.schedule_rounded,
                        negative: row['en_horario'] != 1,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _date(row['registrado_at']),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  _section(
                    'Veh\u00edculo y carga',
                    Icons.local_shipping_rounded,
                  ),
                  Text(
                    'Cami\u00f3n ${row['camion_numero']} \u00b7 ${row['camion_patente']}\n'
                    'Consolidado: ${row['consolidado']}\n'
                    'Tipo: ${row['tipo'] == 'inicial' ? 'Carga inicial' : 'Recarga'}\n'
                    '${row['sucursal_camion_nombre'] == null ? '' : 'Sucursal del cami\u00f3n: ${row['sucursal_camion_nombre']}'}',
                    textAlign: TextAlign.center,
                  ),
                  _section('Registrado por', Icons.person_rounded),
                  Text(
                    '${row['empleado_nombre']} \u00b7 Legajo ${row['legajo']}\n'
                    'Sucursal: ${row['sucursal_empleado_nombre']}'
                    '${row['puesto_nombre'] == null ? '' : '\nPuesto: ${row['puesto_nombre']}'}',
                    textAlign: TextAlign.center,
                  ),
                  if (row['horario_nombre'] != null) ...[
                    _section('Horario de carga', Icons.schedule_rounded),
                    Text(
                      'Horario: ${row['horario_nombre']}',
                      textAlign: TextAlign.center,
                    ),
                    if (row['desde_minuto'] is int &&
                        row['hasta_minuto'] is int)
                      Text(
                        '${_clock(row['desde_minuto'])} inclusive a ${_clock(row['hasta_minuto'])} exclusivo',
                        textAlign: TextAlign.center,
                      ),
                  ],
                  _section('Observaciones', Icons.notes_rounded),
                  Text(
                    (row['observaciones'] ?? '').toString().trim().isEmpty
                        ? 'Sin observaciones'
                        : row['observaciones'].toString(),
                    textAlign: TextAlign.center,
                  ),
                  _section('Fotos adjuntas', Icons.photo_library_rounded),
                  if (_maps(row['fotos']).isEmpty)
                    const Text(
                      'Sin fotos adjuntas.',
                      textAlign: TextAlign.center,
                    ),
                  for (final foto in _maps(row['fotos']))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _CargaPhoto(
                        apiClient: widget.apiClient,
                        token: widget.token,
                        id: foto['id'] as int,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar', textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    } catch (e) {
      await _handleOperationError(e);
    }
  }

  String _truckLabel(Map<String, dynamic> truck) {
    final description = (truck['descripcion'] ?? '').toString().trim();
    return '${truck['numero']} · ${truck['patente']}'
        '${description.isEmpty ? '' : ' · $description'}';
  }

  Widget _section(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );

  Widget _truckSummary(Map<String, dynamic> truck) {
    final colors = Theme.of(context).colorScheme;
    final description = (truck['descripcion'] ?? '').toString().trim();
    final branch = (truck['sucursal_nombre'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Camión ${truck['numero']}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description.isEmpty ? 'Sin descripción registrada' : description,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Patente: ${truck['patente']}${branch.isEmpty ? '' : ' · Sucursal: $branch'}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _panel(List<Widget> children) => Container(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _formSections({
    required List<Widget> vehicle,
    required List<Widget> result,
    required List<Widget> photos,
  }) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final left = _panel(vehicle);
        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _panel(result),
            const SizedBox(height: 16),
            _panel(photos),
          ],
        );
        if (constraints.maxWidth < 760 ||
            MediaQuery.textScalerOf(context).scale(16) > 22) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: left),
            const SizedBox(width: 20),
            Expanded(child: right),
          ],
        );
      },
    ),
  );

  Widget _badge(String label, IconData icon, {bool negative = false}) {
    final colors = Theme.of(context).colorScheme;
    final foreground = negative
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: negative ? colors.errorContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.of(context).foreground(foreground),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.of(context).foreground(foreground),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> row) {
    final colors = Theme.of(context).colorScheme;
    final valid = row['valida'] == 1;
    final onTime = row['en_horario'] == 1;
    return AppCard(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _loading ? null : () => _detail(row),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_rounded, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Cami\u00f3n ${row['camion_numero']} \u00b7 ${row['consolidado']}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${row['camion_patente'] ?? ''} \u00b7 ${row['tipo'] == 'inicial' ? 'Carga inicial' : 'Recarga'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _badge(
                    valid ? 'S\u00ed valida' : 'No valida',
                    valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    negative: !valid,
                  ),
                  _badge(
                    onTime ? 'En t\u00e9rmino' : 'Fuera de horario',
                    Icons.schedule_rounded,
                    negative: !onTime,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _date(row['registrado_at']),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Registro #${row['id']}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    'Ver detalle',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _history() => RefreshIndicator(
    onRefresh: _loading || _sending || _picking ? () async {} : _load,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final margin = constraints.maxWidth < 600 ? 12.0 : 24.0;
        final width = (constraints.maxWidth - margin * 2).clamp(0.0, 1080.0);
        final columns =
            width >= 760 && MediaQuery.textScalerOf(context).scale(16) <= 22
            ? 2
            : 1;
        return ListView(
          key: const PageStorageKey('carga-history'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: (constraints.maxWidth - width) / 2,
            vertical: 24,
          ),
          children: [
            Text(
              'Tus validaciones',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$_total registros \u00b7 P\u00e1gina $_page',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Consult\u00e1 la respuesta, el horario y las fotos de cada carga.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_rows.isEmpty && !_loading)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Todav\u00eda no hay validaciones.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Los registros enviados aparecer\u00e1n aqu\u00ed para que puedas consultarlos.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                for (final row in _rows)
                  SizedBox(
                    width: columns == 2 ? (width - 16) / 2 : width,
                    child: _historyCard(row),
                  ),
              ],
            ),
            if (_total > 30 || _page > 1) ...[
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _page > 1 && !_loading
                        ? () {
                            _page--;
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Anterior', textAlign: TextAlign.center),
                  ),
                  OutlinedButton.icon(
                    onPressed: _page * 30 < _total && !_loading
                        ? () {
                            _page++;
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('Siguiente', textAlign: TextAlign.center),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    ),
  );

  String _clock(dynamic value) {
    final n = value as int;
    return '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final trucks = _maps(_config?['camiones']);
    final selected = trucks.where((t) => t['id'] == _camion).firstOrNull;
    final schedules = _maps(
      _config?['horarios'],
    ).where((h) => h['tipo'] == _tipo).toList();
    final scoped = selected == null
        ? <Map<String, dynamic>>[]
        : schedules
              .where((h) => h['sucursal_id'] == selected['sucursal_id'])
              .toList();
    final effectiveSchedules = scoped.isNotEmpty
        ? scoped
        : schedules.where((h) => h['sucursal_id'] == null).toList();
    final busy = _sending || _picking;
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surfaceContainerLowest,
        appBar: AppBar(
          title: const Text('Validación de carga', textAlign: TextAlign.center),
          actions: [
            IconButton(
              onPressed: busy || _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Nueva validación'),
              Tab(text: 'Mi historial'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_error != null)
              MaterialBanner(
                content: Text(_error!, textAlign: TextAlign.center),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _error = null),
                    child: const Text('Cerrar', textAlign: TextAlign.center),
                  ),
                ],
              ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    key: const PageStorageKey("carga-form"),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.all(compact ? 12 : 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: _config == null
                            ? const Text(
                                'Actualice para consultar los vehículos y horarios.',
                                textAlign: TextAlign.center,
                              )
                            : _config!['habilitado'] != true
                            ? const Text(
                                'Su puesto no está habilitado para registrar cargas. Puede consultar su historial.',
                                textAlign: TextAlign.center,
                              )
                            : AbsorbPointer(
                                absorbing: busy || _loading,
                                child: Container(
                                  padding: EdgeInsets.all(compact ? 16 : 28),
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: colors.outlineVariant,
                                    ),
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      inputDecorationTheme:
                                          InputDecorationTheme(
                                            filled: true,
                                            fillColor:
                                                colors.surfaceContainerLowest,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 18,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: colors.outlineVariant,
                                              ),
                                            ),
                                          ),
                                    ),
                                    child: Form(
                                      key: _form,
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Registrar carga',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Una persona registra la carga del camión. El legajo, la sucursal y la hora se guardan automáticamente.',
                                            textAlign: TextAlign.center,
                                          ),
                                          _formSections(
                                            vehicle: [
                                              _section(
                                                'Vehículo y carga',
                                                Icons.local_shipping_rounded,
                                              ),
                                              DropdownButtonFormField<int>(
                                                key: ValueKey(_camion),
                                                initialValue: _camion,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText:
                                                      'Camión / vehículo',
                                                  prefixIcon: Icon(
                                                    Icons
                                                        .local_shipping_outlined,
                                                  ),
                                                  hintText:
                                                      'Seleccione un camión',
                                                ),
                                                items: trucks
                                                    .map(
                                                      (t) => DropdownMenuItem(
                                                        value: t['id'] as int,
                                                        child: Text(
                                                          _truckLabel(t),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                validator: (v) => v == null
                                                    ? 'Seleccione un vehículo.'
                                                    : null,
                                                onChanged: (v) => setState(() {
                                                  _camion = v;
                                                  _tipo =
                                                      trucks.firstWhere(
                                                            (t) => t['id'] == v,
                                                          )['tiene_inicial'] ==
                                                          1
                                                      ? 'recarga'
                                                      : 'inicial';
                                                  _changed();
                                                }),
                                              ),
                                              if (selected != null)
                                                _truckSummary(selected),
                                              if (trucks.isEmpty)
                                                const Text(
                                                  'No hay vehículos activos. Contacte al administrador.',
                                                  textAlign: TextAlign.center,
                                                ),
                                              const SizedBox(height: 12),
                                              DropdownButtonFormField<String>(
                                                key: ValueKey(_tipo),
                                                initialValue: _tipo,
                                                isExpanded: true,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Tipo de carga',
                                                    ),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'inicial',
                                                    child: Text(
                                                      'Carga inicial',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'recarga',
                                                    child: Text(
                                                      'Recarga',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                                onChanged: (v) => setState(() {
                                                  _tipo = v!;
                                                  _changed();
                                                }),
                                              ),
                                              ...effectiveSchedules.map(
                                                (h) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8,
                                                      ),
                                                  child: Text(
                                                    '${h['nombre']}: desde ${_clock(h['desde_minuto'])} inclusive hasta ${_clock(h['hasta_minuto'])} exclusivo.',
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              TextFormField(
                                                controller: _consolidado,
                                                maxLength: 64,
                                                decoration: const InputDecoration(
                                                  labelText:
                                                      'Número de consolidado',
                                                ),
                                                validator: (v) =>
                                                    v == null ||
                                                        v.trim().isEmpty
                                                    ? 'Ingrese el consolidado.'
                                                    : null,
                                                onChanged: (_) => _changed(),
                                              ),
                                            ],
                                            result: [
                                              _section(
                                                'Resultado de la validación',
                                                Icons.fact_check_rounded,
                                              ),
                                              DropdownButtonFormField<bool>(
                                                key: ValueKey(_valida),
                                                initialValue: _valida,
                                                isExpanded: true,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          '¿Valida la carga?',
                                                    ),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: true,
                                                    child: Text(
                                                      'Sí',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: false,
                                                    child: Text(
                                                      'No',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                                validator: (v) => v == null
                                                    ? 'Seleccione Sí o No.'
                                                    : null,
                                                onChanged: (v) => setState(() {
                                                  _valida = v;
                                                  _changed();
                                                }),
                                              ),
                                              const SizedBox(height: 12),
                                              TextFormField(
                                                controller: _observaciones,
                                                maxLength: 2000,
                                                minLines: 2,
                                                maxLines: 5,
                                                decoration: InputDecoration(
                                                  labelText: _valida == false
                                                      ? 'Observaciones (obligatorias)'
                                                      : 'Observaciones (opcionales)',
                                                ),
                                                validator: (v) =>
                                                    _valida == false &&
                                                        (v?.trim().isEmpty ??
                                                            true)
                                                    ? 'Explique por qué no valida la carga.'
                                                    : null,
                                                onChanged: (_) => _changed(),
                                              ),
                                            ],
                                            photos: [
                                              _section(
                                                'Evidencia fotográfica',
                                                Icons.photo_library_rounded,
                                              ),
                                              Text(
                                                'Fotos opcionales (${_fotos.length}/$_maxFotos)',
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(
                                                _photoLimits,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                alignment: WrapAlignment.center,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: _canAddPhotos
                                                        ? () => _pick(true)
                                                        : null,
                                                    icon: const Icon(
                                                      Icons.camera_alt_rounded,
                                                    ),
                                                    label: const Text(
                                                      'Cámara',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  OutlinedButton.icon(
                                                    onPressed: _canAddPhotos
                                                        ? () => _pick(false)
                                                        : null,
                                                    icon: const Icon(
                                                      Icons
                                                          .photo_library_outlined,
                                                    ),
                                                    label: const Text(
                                                      'Galería',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Wrap(
                                                spacing: 8,
                                                alignment: WrapAlignment.center,
                                                children: [
                                                  for (
                                                    var i = 0;
                                                    i < _fotos.length;
                                                    i++
                                                  )
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Image.memory(
                                                          _fotos[i],
                                                          width: 110,
                                                          height: 90,
                                                          fit: BoxFit.cover,
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              setState(() {
                                                                _fotos.removeAt(
                                                                  i,
                                                                );
                                                                _changed();
                                                              }),
                                                          child: const Text(
                                                            'Quitar',
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(52),
                                            ),
                                            onPressed: busy || trucks.isEmpty
                                                ? null
                                                : _loading
                                                ? null
                                                : _send,
                                            icon: const Icon(
                                              Icons.check_circle_rounded,
                                            ),
                                            label: Text(
                                              _sending
                                                  ? 'Enviando…'
                                                  : 'Registrar validación',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Requiere conexión. Los envíos fuera del horario configurado quedan registrados como fuera de término.',
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  _history(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CargaPhoto extends StatefulWidget {
  const _CargaPhoto({
    required this.apiClient,
    required this.token,
    required this.id,
  });
  final MobileApiClient apiClient;
  final String token;
  final int id;
  @override
  State<_CargaPhoto> createState() => _CargaPhotoState();
}

class _CargaPhotoState extends State<_CargaPhoto> {
  late final Future<Uint8List> _bytes = widget.apiClient.getCargaFoto(
    token: widget.token,
    id: widget.id,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'No se pudo cargar esta foto. Vuelva a abrir el detalle para reintentar.',
          textAlign: TextAlign.center,
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      return InteractiveViewer(child: Image.memory(snapshot.data!));
    },
  );
}
