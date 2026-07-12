import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import '../../core/network/skap_api_models.dart';
import '../../core/utils/date_formatter.dart';

class SkapPage extends StatefulWidget {
  const SkapPage({super.key, required this.apiClient, required this.token});

  final MobileApiClient apiClient;
  final String token;

  @override
  State<SkapPage> createState() => _SkapPageState();
}

class _SkapPageState extends State<SkapPage> {
  bool _loading = true;
  String? _overviewError;
  String? _questionsError;

  late int _anio;

  SkapMiDesarrolloResponse? _miDesarrollo;
  SkapRankingResponse? _ranking;
  SkapPlanesResponse? _planes;
  SkapPreguntasResponse? _preguntas;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _anio = DateTime.now().year;
    unawaited(_loadAll());
  }

  Future<_LoadResult<T>> _loadSafely<T>(
    Future<T> future, {
    required String fallback,
  }) async {
    try {
      return _LoadResult<T>(data: await future);
    } on ApiException catch (e) {
      return _LoadResult<T>(error: e.message);
    } catch (_) {
      return _LoadResult<T>(error: fallback);
    }
  }

  String? _mergeErrors(List<String?> errors) {
    final cleaned = errors
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return null;
    if (cleaned.length == 1) return cleaned.first;
    return cleaned.join('\n');
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _overviewError = null;
      _questionsError = null;
    });

    final miFuture = _loadSafely<SkapMiDesarrolloResponse>(
      widget.apiClient.getSkapMiDesarrollo(token: widget.token, anio: _anio),
      fallback: 'No se pudo cargar mi desarrollo SKAP.',
    );
    final planesFuture = _loadSafely<SkapPlanesResponse>(
      widget.apiClient.getSkapPlanes(token: widget.token, anio: _anio),
      fallback: 'No se pudieron cargar los planes SKAP.',
    );

    final miResult = await miFuture;
    final planesResult = await planesFuture;

    if (!mounted || generation != _loadGeneration) return;

    setState(() {
      _miDesarrollo = miResult.data;
      _ranking = miResult.data?.ranking;
      _planes = planesResult.data;
      _overviewError = _mergeErrors([miResult.error, planesResult.error]);
    });

    final sectorId =
        _miDesarrollo?.evaluacion?.sector?.id ??
        _miDesarrollo?.plan?.sector?.id;
    final empleadoId = _miDesarrollo?.empleado.id;
    final questionsResult = await _loadSafely<SkapPreguntasResponse>(
      widget.apiClient.getSkapPreguntas(
        token: widget.token,
        sectorId: sectorId,
        empleadoId: empleadoId,
        activo: true,
      ),
      fallback: 'No se pudieron cargar las preguntas SKAP.',
    );

    if (!mounted || generation != _loadGeneration) return;

    setState(() {
      _preguntas = questionsResult.data;
      _questionsError = questionsResult.error;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  void _changeYear(int delta) {
    final nextYear = _anio + delta;
    if (nextYear > DateTime.now().year) return;
    setState(() => _anio = nextYear);
    unawaited(_loadAll());
  }

  Future<void> _openEvaluationDetail(SkapEvaluacion evaluacion) async {
    final id = evaluacion.id;
    if (id == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SkapEvaluationDetailSheet(
        apiClient: widget.apiClient,
        token: widget.token,
        evaluationId: id,
        initialEvaluation: evaluacion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SKAP - Mi desarrollo'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Historial'),
              Tab(text: 'Plan'),
              Tab(text: 'Preguntas'),
            ],
          ),
        ),
        body: Column(
          children: [
            _YearSelector(
              anio: _anio,
              onPrev: () => _changeYear(-1),
              onNext: _anio < DateTime.now().year ? () => _changeYear(1) : null,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildResumenTab(),
                        _buildHistorialTab(),
                        _buildPlanTab(),
                        _buildPreguntasTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenTab() {
    final desarrollo = _miDesarrollo;
    final currentPlan = _currentPlan;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_overviewError != null) ...[
            _ErrorCard(message: _overviewError!, onRetry: _refresh),
            const SizedBox(height: 12),
          ],
          if (desarrollo == null)
            const _EmptyCard(
              icon: Icons.psychology_outlined,
              title: 'Sin informacion de SKAP',
              subtitle: 'Todavia no hay datos para mostrar en este anio.',
            )
          else ...[
            _HeroCard(
              desarrollo: desarrollo,
              ranking: _ranking,
              plan: currentPlan,
              anio: _anio,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Evaluacion actual',
              icon: Icons.assessment_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoRow(
                    label: 'Empleado',
                    value: desarrollo.empleado.displayName,
                  ),
                  _InfoRow(
                    label: 'Sector',
                    value:
                        desarrollo.evaluacion?.sector?.displayName ??
                        currentPlan?.sector?.displayName ??
                        '-',
                  ),
                  _InfoRow(
                    label: 'Puesto',
                    value:
                        desarrollo.evaluacion?.puesto?.displayName ??
                        currentPlan?.puesto?.displayName ??
                        '-',
                  ),
                  _InfoRow(
                    label: 'Evaluador',
                    value:
                        desarrollo.evaluacion?.evaluador?.displayName ??
                        currentPlan?.evaluador?.displayName ??
                        '-',
                  ),
                  _InfoRow(
                    label: 'Fecha',
                    value: _formatDate(
                      desarrollo.evaluacion?.fechaEvaluacion ??
                          desarrollo.evaluacion?.createdAt,
                    ),
                  ),
                  _InfoRow(
                    label: 'Nivel',
                    value:
                        desarrollo.evaluacion?.nivel ??
                        desarrollo.plan?.nivel ??
                        desarrollo.badge ??
                        '-',
                  ),
                  _InfoRow(
                    label: 'Badge',
                    value:
                        desarrollo.badge ?? desarrollo.evaluacion?.badge ?? '-',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Promedios',
              icon: Icons.multiline_chart_outlined,
              child: _PromediosWrap(
                promedios: desarrollo.evaluacion?.promedios,
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Categorias',
              icon: Icons.category_outlined,
              child: desarrollo.categoriaCards.isEmpty
                  ? const _EmptyInline(text: 'No hay categorias para mostrar.')
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final card in desarrollo.categoriaCards)
                          _CategoriaCard(card: card),
                      ],
                    ),
            ),
            if (desarrollo.evaluacion != null) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Detalle de respuestas',
                icon: Icons.fact_check_outlined,
                child: desarrollo.evaluacion!.detalles.isEmpty
                    ? const _EmptyInline(
                        text: 'Aun no hay respuestas detalladas.',
                      )
                    : Column(
                        children: [
                          for (final detalle in desarrollo.evaluacion!.detalles)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DetalleTile(detalle: detalle),
                            ),
                        ],
                      ),
              ),
            ],
            if (currentPlan != null) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Plan actual',
                icon: Icons.route_outlined,
                child: _PlanSummaryCard(plan: currentPlan),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHistorialTab() {
    final historial = _miDesarrollo?.historial ?? const <SkapEvaluacion>[];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_overviewError != null && _miDesarrollo == null) ...[
            _ErrorCard(message: _overviewError!, onRetry: _refresh),
            const SizedBox(height: 12),
          ],
          _ListHeader(
            title: 'Historial de evaluaciones',
            subtitle: 'Anio $_anio',
            trailing: historial.isEmpty
                ? null
                : Text(
                    '${historial.length} items',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
          ),
          const SizedBox(height: 12),
          if (historial.isEmpty)
            const _EmptyCard(
              icon: Icons.history_outlined,
              title: 'Sin historial',
              subtitle: 'Las evaluaciones anteriores van a aparecer aca.',
            )
          else
            ...historial.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryTile(
                  item: item,
                  onTap: () => _openEvaluationDetail(item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanTab() {
    final planes = _planes;
    final currentPlan = _currentPlan;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_overviewError != null && planes == null) ...[
            _ErrorCard(message: _overviewError!, onRetry: _refresh),
            const SizedBox(height: 12),
          ],
          _ListHeader(
            title: 'Plan de desarrollo',
            subtitle: currentPlan == null
                ? 'Sin plan seleccionado'
                : 'Avance y acciones comprometidas',
          ),
          const SizedBox(height: 12),
          if (currentPlan == null)
            const _EmptyCard(
              icon: Icons.route_outlined,
              title: 'Sin plan activo',
              subtitle: 'No hay plan cargado para el anio seleccionado.',
            )
          else ...[
            _SectionCard(
              title: 'Resumen del plan',
              icon: Icons.flag_outlined,
              child: _PlanSummaryCard(plan: currentPlan),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Acciones',
              icon: Icons.checklist_outlined,
              child: currentPlan.acciones.isEmpty
                  ? const _EmptyInline(
                      text: 'No hay acciones cargadas en este plan.',
                    )
                  : Column(
                      children: [
                        for (final action in currentPlan.acciones)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PlanActionTile(action: action),
                          ),
                      ],
                    ),
            ),
          ],
          if (planes != null && planes.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Planes del anio',
              icon: Icons.library_books_outlined,
              child: Column(
                children: [
                  for (final plan in planes.items.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PlanListTile(plan: plan),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreguntasTab() {
    final preguntas = _preguntas?.items ?? const <SkapPregunta>[];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_questionsError != null) ...[
            _ErrorCard(message: _questionsError!, onRetry: _refresh),
            const SizedBox(height: 12),
          ],
          _ListHeader(
            title: 'Preguntas activas',
            subtitle: preguntas.isEmpty
                ? 'Sin preguntas cargadas'
                : 'Total: ${_preguntas?.total ?? preguntas.length}',
          ),
          const SizedBox(height: 12),
          if (preguntas.isEmpty)
            const _EmptyCard(
              icon: Icons.quiz_outlined,
              title: 'Sin preguntas',
              subtitle: 'No hay preguntas activas para mostrar.',
            )
          else
            ...preguntas.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuestionCard(item: item),
              ),
            ),
        ],
      ),
    );
  }

  SkapPlan? get _currentPlan {
    final desarrolloPlan = _miDesarrollo?.plan;
    if (desarrolloPlan != null) return desarrolloPlan;
    final currentPlan = _planes?.current;
    if (currentPlan != null) return currentPlan;
    final items = _planes?.items;
    if (items != null && items.isNotEmpty) return items.first;
    return null;
  }

  String _formatDate(String? value) {
    return DateFormatter.formatApiDateForDisplay(value);
  }
}

class SkapEvaluationDetailSheet extends StatefulWidget {
  const SkapEvaluationDetailSheet({
    super.key,
    required this.apiClient,
    required this.token,
    required this.evaluationId,
    required this.initialEvaluation,
  });

  final MobileApiClient apiClient;
  final String token;
  final int evaluationId;
  final SkapEvaluacion initialEvaluation;

  @override
  State<SkapEvaluationDetailSheet> createState() =>
      _SkapEvaluationDetailSheetState();
}

class _SkapEvaluationDetailSheetState extends State<SkapEvaluationDetailSheet> {
  SkapEvaluacion? _item;
  SkapPlan? _plan;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _item = widget.initialEvaluation;
    _plan = widget.initialEvaluation.plan;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.evaluationId <= 0) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo identificar la evaluacion.';
        _loading = false;
      });
      return;
    }

    try {
      final response = await widget.apiClient.getSkapEvaluacion(
        token: widget.token,
        evaluacionId: widget.evaluationId,
      );
      if (!mounted) return;
      setState(() {
        _item = response.evaluacion;
        _plan = response.plan ?? response.evaluacion.plan;
        _error = response.message;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el detalle de la evaluacion.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item ?? widget.initialEvaluation;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final statusLabel = item.badge ?? item.nivel ?? 'SKAP';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.97,
        builder: (context, scrollController) {
          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.psychology_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Evaluacion #${item.id ?? widget.evaluationId}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _StatusChip(label: statusLabel),
                                          if (item.promedios?.general != null)
                                            _StatusChip(
                                              label:
                                                  'General ${item.promedios!.general!.toStringAsFixed(1)}',
                                            ),
                                          if (_plan != null &&
                                              _plan!.avancePct != null)
                                            _StatusChip(
                                              label:
                                                  'Avance ${_plan!.avancePct!.toStringAsFixed(0)}%',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _ErrorCard(message: _error!, onRetry: _load),
                            ],
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Datos generales',
                              icon: Icons.info_outline,
                              child: Column(
                                children: [
                                  _InfoRow(
                                    label: 'Empleado',
                                    value: item.empleado?.displayName ?? '-',
                                  ),
                                  _InfoRow(
                                    label: 'Sector',
                                    value: item.sector?.displayName ?? '-',
                                  ),
                                  _InfoRow(
                                    label: 'Puesto',
                                    value: item.puesto?.displayName ?? '-',
                                  ),
                                  _InfoRow(
                                    label: 'Evaluador',
                                    value: item.evaluador?.displayName ?? '-',
                                  ),
                                  _InfoRow(
                                    label: 'Fecha',
                                    value:
                                        DateFormatter.formatApiDateForDisplay(
                                          item.fechaEvaluacion ??
                                              item.createdAt,
                                        ),
                                  ),
                                  _InfoRow(
                                    label: 'Hora',
                                    value: item.horaEvaluacion ?? '-',
                                  ),
                                  _InfoRow(
                                    label: 'Badge',
                                    value: item.badge ?? '-',
                                  ),
                                  _InfoRow(
                                    label: 'Nivel',
                                    value: item.nivel ?? '-',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: 'Promedios',
                              icon: Icons.query_stats_outlined,
                              child: _PromediosWrap(promedios: item.promedios),
                            ),
                            if (item.observacionesGenerales
                                    ?.trim()
                                    .isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 12),
                              _SectionCard(
                                title: 'Observaciones',
                                icon: Icons.description_outlined,
                                child: Text(
                                  item.observacionesGenerales!.trim(),
                                ),
                              ),
                            ],
                            if (item.categoriaCards.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _SectionCard(
                                title: 'Categorias',
                                icon: Icons.category_outlined,
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final card in item.categoriaCards)
                                      _CategoriaCard(card: card),
                                  ],
                                ),
                              ),
                            ],
                            if (item.detalles.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _SectionCard(
                                title: 'Respuestas',
                                icon: Icons.fact_check_outlined,
                                child: Column(
                                  children: [
                                    for (final detalle in item.detalles)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: _DetalleTile(detalle: detalle),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            if (_plan != null) ...[
                              const SizedBox(height: 12),
                              _SectionCard(
                                title: 'Plan asociado',
                                icon: Icons.route_outlined,
                                child: _PlanSummaryCard(plan: _plan!),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.desarrollo,
    required this.ranking,
    required this.plan,
    required this.anio,
  });

  final SkapMiDesarrolloResponse desarrollo;
  final SkapRankingResponse? ranking;
  final SkapPlan? plan;
  final int anio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final promedio =
        desarrollo.evaluacion?.promedios?.general ??
        plan?.promedioGeneral ??
        ranking?.puntaje;
    final title = desarrollo.badge ?? desarrollo.evaluacion?.badge ?? 'SKAP';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            desarrollo.empleado.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Anio $anio - ${title.trim().isEmpty ? 'Sin badge' : title}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStatChip(label: 'Ranking', value: ranking?.posicion),
              _MiniStatChip(label: 'Total', value: ranking?.total),
              _MiniStatChip(
                label: 'Promedio',
                value: promedio?.toStringAsFixed(1),
              ),
              _MiniStatChip(
                label: 'Plan',
                value: plan?.avancePct == null
                    ? null
                    : '${plan!.avancePct!.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _YearSelector extends StatelessWidget {
  const _YearSelector({required this.anio, required this.onPrev, this.onNext});

  final int anio;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            tooltip: 'Anio anterior',
          ),
          const SizedBox(width: 8),
          Text(
            '$anio',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Anio siguiente',
            color: onNext != null ? null : cs.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 36, color: cs.primary),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value == null ? '--' : value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayValue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PromediosWrap extends StatelessWidget {
  const _PromediosWrap({required this.promedios});

  final SkapPromedios? promedios;

  @override
  Widget build(BuildContext context) {
    final items = <_PromedioChip>[
      _PromedioChip(label: 'Skills', value: promedios?.skills),
      _PromedioChip(label: 'Knowledge', value: promedios?.knowledge),
      _PromedioChip(label: 'Attitude', value: promedios?.attitude),
      _PromedioChip(label: 'Performance', value: promedios?.performance),
      _PromedioChip(label: 'General', value: promedios?.general),
    ];
    final hasAny = items.any((item) => item.value != null);
    if (!hasAny) {
      return const _EmptyInline(text: 'No hay promedios disponibles.');
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final item in items) _PromedioChipTile(item: item)],
    );
  }
}

class _PromedioChip {
  const _PromedioChip({required this.label, required this.value});

  final String label;
  final double? value;
}

class _PromedioChipTile extends StatelessWidget {
  const _PromedioChipTile({required this.item});

  final _PromedioChip item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final value = item.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value == null ? '--' : value.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  const _CategoriaCard({required this.card});

  final SkapCategoriaCard card;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.displayLabel,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            card.categoria ?? '-',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (card.promedio != null)
                _StatusChip(label: 'Prom ${card.promedio!.toStringAsFixed(1)}'),
              if (card.esperado != null)
                _StatusChip(
                  label: 'Esper ${card.esperado!.toStringAsFixed(1)}',
                ),
              if ((card.nivel ?? '').isNotEmpty)
                _StatusChip(label: card.nivel!),
              if (card.respuestas != null)
                _StatusChip(label: '${card.respuestas} resp'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetalleTile extends StatelessWidget {
  const _DetalleTile({required this.detalle});

  final SkapDetalleRespuesta detalle;

  @override
  Widget build(BuildContext context) {
    final obtenido = detalle.puntajeObtenido;
    final esperado = detalle.puntajeEsperado;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detalle.descripcion ?? 'Sin descripcion',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((detalle.categoriaLabel ?? detalle.categoria ?? '')
                        .trim()
                        .isNotEmpty ==
                    true)
                  _StatusChip(
                    label:
                        detalle.categoriaLabel ??
                        detalle.categoria ??
                        'Categoria',
                  ),
                if (esperado != null)
                  _StatusChip(label: 'Esperado ${esperado.toStringAsFixed(1)}'),
                if (obtenido != null)
                  _StatusChip(label: 'Obtenido ${obtenido.toStringAsFixed(1)}'),
              ],
            ),
            if (detalle.observacion?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(detalle.observacion!.trim()),
            ],
            if (detalle.evidencia?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Evidencia: ${detalle.evidencia!.trim()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.plan});

  final SkapPlan plan;

  @override
  Widget build(BuildContext context) {
    final avance = plan.avancePct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: 'Empleado', value: plan.empleado?.displayName ?? '-'),
        _InfoRow(label: 'Sector', value: plan.sector?.displayName ?? '-'),
        _InfoRow(label: 'Puesto', value: plan.puesto?.displayName ?? '-'),
        _InfoRow(label: 'Evaluador', value: plan.evaluador?.displayName ?? '-'),
        _InfoRow(label: 'Nivel', value: plan.nivel ?? '-'),
        _InfoRow(label: 'Periodo', value: plan.anio?.toString() ?? '-'),
        if (plan.observaciones?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(plan.observaciones!.trim()),
        ],
        if (avance != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: (avance / 100).clamp(0, 1)),
          const SizedBox(height: 6),
          Text('${avance.toStringAsFixed(0)}% completado'),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (plan.accionesTotal != null)
              _StatusChip(label: 'Acciones ${plan.accionesTotal}'),
            if (plan.accionesCompletadas != null)
              _StatusChip(label: 'Hechas ${plan.accionesCompletadas}'),
            if (plan.accionesVencidas != null)
              _StatusChip(label: 'Vencidas ${plan.accionesVencidas}'),
          ],
        ),
      ],
    );
  }
}

class _PlanActionTile extends StatelessWidget {
  const _PlanActionTile({required this.action});

  final SkapPlanAction action;

  @override
  Widget build(BuildContext context) {
    final isCompleted = action.isCompleted;
    final statusColor = isCompleted ? Colors.green : Colors.orange;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          isCompleted ? Icons.check_circle_outline : Icons.pending_outlined,
          color: statusColor,
        ),
        title: Text(action.accion ?? 'Accion'),
        subtitle: Text(
          [
            if ((action.categoriaLabel ?? action.categoria ?? '')
                .trim()
                .isNotEmpty)
              action.categoriaLabel ?? action.categoria!,
            if (action.responsable?.displayName != null)
              action.responsable!.displayName,
            if (action.fechaCompromiso?.trim().isNotEmpty == true)
              'Compromiso: ${DateFormatter.formatApiDateForDisplay(action.fechaCompromiso)}',
            if (action.comentarios?.trim().isNotEmpty == true)
              action.comentarios!.trim(),
          ].join('\n'),
        ),
        trailing: Text(
          action.estado ?? '-',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _PlanListTile extends StatelessWidget {
  const _PlanListTile({required this.plan});

  final SkapPlan plan;

  @override
  Widget build(BuildContext context) {
    final avance = plan.avancePct;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.folder_copy_outlined),
        title: Text(plan.empleado?.displayName ?? 'Plan SKAP'),
        subtitle: Text(
          [
            if (plan.nivel != null) 'Nivel: ${plan.nivel}',
            if (avance != null) 'Avance: ${avance.toStringAsFixed(0)}%',
            if (plan.createdAt != null)
              'Creado: ${DateFormatter.formatApiDateForDisplay(plan.createdAt)}',
          ].join(' - '),
        ),
        trailing: Text(
          plan.anio?.toString() ?? '-',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.onTap});

  final SkapEvaluacion item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final general = item.promedios?.general;
    final initials = _firstChar(item.badge ?? item.nivel ?? 'SK');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(child: Text(initials)),
        title: Text(item.badge ?? item.nivel ?? 'Evaluacion SKAP'),
        subtitle: Text(
          [
            if (item.fechaEvaluacion != null)
              DateFormatter.formatApiDateForDisplay(item.fechaEvaluacion),
            if (general != null) 'General ${general.toStringAsFixed(1)}',
            if (item.sector?.displayName != null) item.sector!.displayName,
            if (item.puesto?.displayName != null) item.puesto!.displayName,
          ].where((value) => value.trim().isNotEmpty).join(' - '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

String _firstChar(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return 'S';
  return cleaned.substring(0, 1).toUpperCase();
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.item});

  final SkapPregunta item;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      if (item.categoriaLabel?.trim().isNotEmpty == true) item.categoriaLabel!,
      if (item.sectorNombre?.trim().isNotEmpty == true) item.sectorNombre!,
      if (item.peso != null) 'Peso ${item.peso!.toStringAsFixed(1)}',
      if (item.puntajeEsperado != null)
        'Esperado ${item.puntajeEsperado!.toStringAsFixed(1)}',
      if (item.requiereObservacion == true) 'Observacion',
      if (item.requiereEvidencia == true) 'Evidencia',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.descripcion ?? 'Pregunta SKAP',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final tag in tags) _StatusChip(label: tag)],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadResult<T> {
  const _LoadResult({this.data, this.error});

  final T? data;
  final String? error;
}
