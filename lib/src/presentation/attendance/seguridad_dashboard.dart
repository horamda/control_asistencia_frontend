import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'package:ficharqr/src/presentation/theme/app_palette.dart';
import 'package:flutter/material.dart';
import '../../core/network/mobile_api_client.dart';
import '../theme/app_theme.dart';
import '../theme/card_typography.dart';

const seguridadTipos = {
  'seguro': 'Comportamiento seguro',
  'inseguro': 'Comportamiento inseguro',
  'accidente': 'Accidente',
  'incidente': 'Incidente sin lesión',
};

const _typeColors = {
  'seguro': Color(0xFF177563),
  'inseguro': Color(0xFF9C610D),
  'accidente': Color(0xFFB23E49),
  'incidente': Color(0xFF356B9B),
};
const _typeIcons = {
  'seguro': Icons.verified_user_rounded,
  'inseguro': Icons.warning_amber_rounded,
  'accidente': Icons.health_and_safety_rounded,
  'incidente': Icons.info_outline_rounded,
};

String seguridadFecha(DateTime date) => date.toIso8601String().substring(0, 10);

class _SecurityOverview extends StatelessWidget {
  const _SecurityOverview({required this.total, required this.period});
  final int? total;
  final String period;

  @override
  Widget build(BuildContext context) => AppCard(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(
        Icons.shield_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        'Resumen personal',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '$period${total == null ? '' : '\nEventos aprobados: $total'}',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

/// Session-local state. A generation prevents older requests replacing a new filter.
class SeguridadDashboardController extends ChangeNotifier {
  SeguridadDashboardController({required this.api, required this.token}) {
    refresh();
  }

  final MobileApiClient api;
  final String token;
  int? year;
  int? month;
  Map<String, dynamic>? data;
  Map<String, dynamic>? fallbackIndicators;
  Object? indicatorsError;
  Object? error;
  bool loading = false;
  bool _disposed = false;
  int _generation = 0;

  bool _missing(Object? e) =>
      e is ApiException && (e.statusCode == 404 || e.statusCode == 405);
  String get errorMessage {
    if (fallbackIndicators != null) {
      return 'No se pudo cargar el historial. Los días sin accidentes están disponibles.';
    }
    if (_missing(error)) {
      if (_missing(indicatorsError)) {
        return 'El servidor todavía no tiene habilitados los días sin accidentes. Solicitá la actualización a administración.';
      }
      return 'No se pudieron consultar los días sin accidentes. Volvé a intentar.';
    }
    return error is ApiException
        ? (error as ApiException).message
        : 'No se pudo cargar el resumen.';
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    loading = true;
    data = null;
    fallbackIndicators = null;
    indicatorsError = null;
    error = null;
    notifyListeners();
    final query = Uri(
      queryParameters: {
        if (year != null) 'anio': '$year',
        if (month != null) 'mes': '$month',
      },
    ).query;
    try {
      final result = await api.getSeguridad(
        token: token,
        path: '/resumen${query.isEmpty ? '' : '?$query'}',
      );
      if (_disposed || generation != _generation) return;
      if (result['anio'] is! int ||
          result['indicadores'] is! Map ||
          result['por_tipo'] is! Map) {
        throw const FormatException('Respuesta de resumen incompleta.');
      }
      year ??= result['anio'] as int;
      data = result;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e;
      if (e is! ApiException || (e.statusCode != 401 && e.statusCode != 403)) {
        try {
          final indicators = await api.getSeguridad(
            token: token,
            path: '/indicadores',
          );
          if (_disposed || generation != _generation) return;
          if (indicators['alcances'] is! Map ||
              indicators['hasta'] is! String) {
            throw const FormatException('Respuesta de indicadores incompleta.');
          }
          fallbackIndicators = indicators;
        } catch (failure) {
          if (_disposed || generation != _generation) return;
          indicatorsError = failure;
        }
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void select(int selectedYear, int? selectedMonth) {
    year = selectedYear;
    month = selectedMonth;
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class SeguridadDashboard extends StatelessWidget {
  const SeguridadDashboard({
    super.key,
    required this.controller,
    required this.today,
    required this.showHistory,
    required this.showIndicators,
    required this.onHistory,
  });

  final SeguridadDashboardController controller;
  final DateTime today;
  final bool showHistory;
  final bool showIndicators;
  final void Function(String type, DateTime from, DateTime to) onHistory;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final data = controller.data;
      final indicators =
          data?['indicadores'] as Map? ?? controller.fallbackIndicators;
      final year = controller.year ?? today.year;
      final month = controller.month;
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _SecurityOverview(
              total: showHistory ? (data?['total'] as int?) : null,
              period: month == null
                  ? 'Todo el año $year'
                  : '${_months[month - 1]} $year',
            ),
            if (showIndicators && indicators != null)
              SeguridadIndicators(
                key: ValueKey(data?['actualizado_at'] ?? indicators['hasta']),
                api: controller.api,
                token: controller.token,
                today: DateTime.parse(indicators['hasta'] as String),
                initial: Map<String, dynamic>.from(indicators),
              ),
            const SizedBox(height: 24),
            Text(
              'Período del historial',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(16) > 20
                      ? 260
                      : 120,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    itemHeight: null,
                    key: ValueKey('summary-year-$year'),
                    initialValue: year,
                    decoration: const InputDecoration(
                      labelText: 'Año',
                      contentPadding: EdgeInsets.all(12),
                    ),
                    items: [
                      for (var y = today.year; y >= 2000; y--)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) {
                      if (v != null) controller.select(v, month);
                    },
                  ),
                ),
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(16) > 20
                      ? 260
                      : 156,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    itemHeight: null,
                    initialValue: month ?? 0,
                    decoration: const InputDecoration(
                      labelText: 'Mes',
                      contentPadding: EdgeInsets.all(12),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('Todo el año'),
                      ),
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(value: m, child: Text(_months[m - 1])),
                    ],
                    onChanged: (v) =>
                        controller.select(year, v == 0 ? null : v),
                  ),
                ),
                IconButton(
                  onPressed: controller.refresh,
                  tooltip: 'Actualizar resumen',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.loading)
              const Center(child: CircularProgressIndicator()),
            if (controller.error != null) ...[
              Text(controller.errorMessage),
              TextButton(
                onPressed: controller.refresh,
                child: const Text('Reintentar'),
              ),
            ],
            if (data != null) ...[
              if (showHistory) ...[
                Text(
                  'Mis observaciones',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Eventos en los que estás involucrado. Los envíos pendientes no se suman.',
                ),
                const SizedBox(height: 12),
                ResponsiveCards(
                  children: seguridadTipos.entries
                      .map(
                        (entry) => AppCard(
                          key: ValueKey('security-type-${entry.key}'),
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: AppColors.of(context).border(
                                _typeColors[entry.key]!.withValues(alpha: .25),
                              ),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => onHistory(
                              entry.key,
                              DateTime(year, month ?? 1),
                              DateTime(year, month == null ? 13 : month + 1, 0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Icon(
                                    _typeIcons[entry.key],
                                    color: AppColors.of(context)
                                        .optionalForeground(
                                          _typeColors[entry.key],
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    entry.value,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(data['por_tipo'] as Map)[entry.key]}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(
                                          color: AppColors.of(context)
                                              .optionalForeground(
                                                _typeColors[entry.key],
                                              ),
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Ver historial',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 28),
                Text(
                  'Evolución mensual · $year',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'El año completo, mes a mes. El filtro de mes solo cambia las tarjetas.',
                ),
                ...seguridadTipos.entries.map(
                  (entry) => AppCard(
                    color: Theme.of(context).colorScheme.surface,
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Icon(
                        _typeIcons[entry.key],
                        color: AppColors.of(
                          context,
                        ).optionalForeground(_typeColors[entry.key]),
                      ),
                      initiallyExpanded: entry.key == 'seguro',
                      title: Text(entry.value, textAlign: TextAlign.center),
                      children: [
                        SeguridadMonthlySeries(
                          color: _typeColors[entry.key],
                          values: List<int?>.from(
                            (data['series_mensuales'] as Map)[entry.key]
                                as List,
                          ),
                          year: year,
                          cutoff: DateTime.parse(data['fecha_corte'] as String),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Comparativo anual',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Historial aprobado completo hasta la fecha de corte, independiente del período de las tarjetas.',
                ),
                ...seguridadTipos.entries.map(
                  (entry) => AppCard(
                    color: Theme.of(context).colorScheme.surface,
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Icon(
                        _typeIcons[entry.key],
                        color: AppColors.of(
                          context,
                        ).optionalForeground(_typeColors[entry.key]),
                      ),
                      title: Text(entry.value, textAlign: TextAlign.center),
                      children: [
                        for (final series
                            in (data['comparativo_anual'] as Map)[entry.key]
                                as List)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${series['anio']}',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              SeguridadMonthlySeries(
                                color: _typeColors[entry.key],
                                maximum: _comparisonMaximum(data, entry.key),
                                values: List<int?>.from(
                                  series['valores'] as List,
                                ),
                                year: series['anio'] as int,
                                cutoff: DateTime.parse(
                                  data['fecha_corte'] as String,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Corte: ${data['fecha_corte']} · Actualizado: ${data['actualizado_at']}',
              ),
            ],
          ],
        ),
      );
    },
  );
}

const _months = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

int _comparisonMaximum(Map<String, dynamic> data, String type) =>
    ((data['comparativo_anual'] as Map)[type] as List)
        .expand((series) => (series['valores'] as List).whereType<int>())
        .fold<int>(1, (a, b) => a > b ? a : b);

/// Bars retain nullable values and expose exact counts to assistive technology.
class SeguridadMonthlySeries extends StatelessWidget {
  const SeguridadMonthlySeries({
    super.key,
    required this.values,
    required this.year,
    required this.cutoff,
    this.maximum,
    this.color,
  });
  final List<int?> values;
  final int year;
  final DateTime cutoff;
  final int? maximum;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final limit =
        maximum ??
        values.whereType<int>().fold<int>(1, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = box.maxWidth >= 12 * 52 * scale
              ? 12
              : box.maxWidth >= 6 * 52 * scale
              ? 6
              : box.maxWidth >= 3 * 52 * scale
              ? 3
              : 2;
          final width = box.maxWidth / columns;
          final barHeight = columns == 12 ? 140.0 : 76.0;
          final barColor = color ?? Theme.of(context).colorScheme.primary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reportes · escala 0–$limit',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 20,
                children: [
                  for (var i = 0; i < 12; i++)
                    SizedBox(
                      width: width,
                      child: Tooltip(
                        triggerMode: TooltipTriggerMode.tap,
                        message:
                            '${_months[i]} $year: ${values[i] == null ? 'mes futuro' : '${values[i]} reportes'}${year == cutoff.year && i + 1 == cutoff.month ? ' · mes parcial' : ''}',
                        child: Semantics(
                          label:
                              '${_months[i]} $year: ${values[i] == null ? 'mes futuro' : '${values[i]} reportes'}',
                          child: Column(
                            children: [
                              Text(
                                values[i]?.toString() ?? '—',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: barHeight,
                                width: 28,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.bottomCenter,
                                child: values[i] == null
                                    ? const Center(
                                        child: Text(
                                          '—',
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    : Container(
                                        height: barHeight * values[i]! / limit,
                                        decoration: BoxDecoration(
                                          color: AppColors.of(
                                            context,
                                          ).surface(barColor),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_months[i]}${year == cutoff.year && i + 1 == cutoff.month ? '*' : ''}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '0: sin reportes · —: mes futuro · * Mes parcial',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class SeguridadIndicators extends StatefulWidget {
  const SeguridadIndicators({
    super.key,
    required this.api,
    required this.token,
    required this.today,
    required this.initial,
  });
  final MobileApiClient api;
  final String token;
  final DateTime today;
  final Map<String, dynamic> initial;

  @override
  State<SeguridadIndicators> createState() => _SeguridadIndicatorsState();
}

class _SeguridadIndicatorsState extends State<SeguridadIndicators> {
  late Map<String, dynamic> data = widget.initial;
  late DateTime cutoff = DateTime.parse(widget.initial['hasta'] as String);
  bool loading = false;
  Object? error;
  int generation = 0;

  Future<void> load(DateTime date) async {
    final request = ++generation;
    setState(() {
      cutoff = date;
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.getSeguridad(
        token: widget.token,
        path: '/indicadores?hasta=${seguridadFecha(date)}',
      );
      if (mounted && request == generation) {
        setState(() {
          data = result;
          cutoff = DateTime.parse(result['hasta'] as String);
        });
      }
    } catch (e) {
      if (mounted && request == generation) setState(() => error = e);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      Text(
        'Días sin accidentes',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: [
          OutlinedButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: cutoff,
                firstDate: DateTime(2000),
                lastDate: widget.today,
              );
              if (date != null && mounted) await load(date);
            },
            child: Text(
              'Corte: ${seguridadFecha(cutoff)}',
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar indicadores',
            onPressed: () => load(cutoff),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (loading)
        const Center(child: CircularProgressIndicator())
      else if (error != null) ...[
        Text(
          error is ApiException
              ? (error as ApiException).message
              : 'No se pudieron cargar los indicadores.',
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () => load(cutoff),
          child: const Text('Reintentar', textAlign: TextAlign.center),
        ),
      ] else
        ResponsiveCards(
          maxColumns: 3,
          children: [
            for (final scope in const {
              'empresa': 'Empresa',
              'sucursal': 'Mi sucursal',
              'propio': 'Mi registro',
            }.entries)
              _indicator(
                context,
                scope.value,
                Map<String, dynamic>.from(
                  (data['alcances'] as Map)[scope.key] as Map,
                ),
              ),
          ],
        ),
      const ExpansionTile(
        title: Text('Cómo se calcula', textAlign: TextAlign.center),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Días calendario desde el último accidente pendiente o aprobado hasta la fecha de corte. Se usa la fecha del accidente, no la de carga. Los rechazados y anulados no cuentan. Sin accidentes, se usa el inicio confiable del registro; sin ambos, no hay datos suficientes. El récord requiere un inicio confiable. Una consulta pasada utiliza el estado actual de los reportes. Los totales, gráficos y rankings siguen contando solo eventos aprobados.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _indicator(
    BuildContext context,
    String title,
    Map<String, dynamic> value,
  ) {
    const reasons = {
      'sin_inicio_configurado':
          'No hay accidentes registrados ni una fecha de inicio confiable para calcular los días. Administración puede configurar el inicio del registro.',
      'sin_sucursal': 'No tenés una sucursal asignada.',
      'corte_anterior_al_inicio':
          'La fecha de corte es anterior al inicio del registro.',
    };
    return AppCard(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (value['disponible'] != true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.of(
                      context,
                    ).foreground(const Color(0xFF627383)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reasons[value['motivo']] ?? 'Indicador no disponible.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else ...[
              Text(
                '${value['dias_sin_accidentes'] ?? '—'} días sin accidentes',
                style: CardTypography.indicator(context).copyWith(
                  color: AppColors.of(
                    context,
                  ).foreground(const Color(0xFF177563)),
                ),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 28),
              Text(
                value['record_dias_sin_accidentes'] == null
                    ? 'Récord: no disponible'
                    : 'Récord: ${value['record_dias_sin_accidentes']} días',
                textAlign: TextAlign.center,
              ),
              if (value['record_dias_sin_accidentes'] == null)
                const Text(
                  'El récord requiere un inicio confiable anterior a la fecha de corte.',
                  textAlign: TextAlign.center,
                ),
              Text(
                'Último accidente: ${value['ultimo_accidente'] ?? 'Sin accidentes registrados'}',
                textAlign: TextAlign.center,
              ),
              Text('Hasta: ${data['hasta']}', textAlign: TextAlign.center),
              if (value['ultimo_accidente'] == null)
                const Text(
                  'Sin accidentes pendientes o aprobados, la racha comienza en el inicio confiable del registro.',
                  textAlign: TextAlign.center,
                ),
              Text(
                'Accidentes registrados: ${value['accidentes_registrados'] ?? '—'}',
                textAlign: TextAlign.center,
              ),
              Text(
                'Inicio del registro: ${value['inicio'] ?? 'Sin configurar'}',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
