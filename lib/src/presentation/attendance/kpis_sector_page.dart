import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class KpisSectorPage extends StatefulWidget {
  const KpisSectorPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<KpisSectorPage> createState() => _KpisSectorPageState();
}

class _KpisSectorPageState extends State<KpisSectorPage> {
  bool _loading = true;
  String? _error;
  KpisSectorialResponse? _data;
  int _anio = DateTime.now().year;

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
      final data = await widget.apiClient.getKpisSector(
        token: widget.token,
        anio: _anio,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
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
        _error = 'Error inesperado al cargar los KPIs.';
        _loading = false;
      });
    }
  }

  void _cambiarAnio(int delta) {
    final nuevo = _anio + delta;
    if (nuevo > DateTime.now().year) return;
    setState(() => _anio = nuevo);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPIs del Sector'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: _load,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildAnioSelector()),
        if (_loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          SliverFillRemaining(child: _buildError())
        else if (_data != null)
          _buildContent(_data!),
      ],
    );
  }

  Widget _buildAnioSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _cambiarAnio(-1),
          ),
          Text(
            '$_anio',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                _anio < DateTime.now().year ? () => _cambiarAnio(1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(KpisSectorialResponse data) {
    if (data.kpis.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_outlined,
                    size: 56, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  data.sector.id == null
                      ? 'No tenés sector asignado.'
                      : 'Sin KPIs configurados para $_anio.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) return _buildSectorHeader(data);
          return _KpiCard(kpi: data.kpis[index - 1]);
        },
        childCount: 1 + data.kpis.length,
      ),
    );
  }

  Widget _buildSectorHeader(KpisSectorialResponse data) {
    final cs = Theme.of(context).colorScheme;
    if (data.sector.nombre == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Icon(Icons.group_work_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            data.sector.nombre!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final KpiSectorialItem kpi;

  static const _semaforoFg = {
    'verde': Color(0xFF1B5E20),
    'amarillo': Color(0xFFE65100),
    'rojo': Color(0xFFB71C1C),
    'gris': Color(0xFF616161),
  };

  static const _semaforoBg = {
    'verde': Color(0xFFE8F5E9),
    'amarillo': Color(0xFFFFF3E0),
    'rojo': Color(0xFFFFEBEE),
    'gris': Color(0xFFF5F5F5),
  };

  static const _semaforoIcons = {
    'verde': Icons.check_circle_outline,
    'amarillo': Icons.warning_amber_outlined,
    'rojo': Icons.cancel_outlined,
    'gris': Icons.radio_button_unchecked,
  };

  Color get _fg => _semaforoFg[kpi.semaforo] ?? const Color(0xFF616161);
  Color get _bg => _semaforoBg[kpi.semaforo] ?? const Color(0xFFF5F5F5);
  IconData get _icon =>
      _semaforoIcons[kpi.semaforo] ?? Icons.radio_button_unchecked;

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final unidad = kpi.unidad != null ? ' ${kpi.unidad}' : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (kpi.recomendacion != null) ...[
              const SizedBox(height: 4),
              Text(
                kpi.recomendacion!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _fg,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            kpi.isBetween
                ? _buildBetweenBar(context)
                : _buildProgressBar(context),
            const SizedBox(height: 8),
            kpi.isBetween
                ? _buildBetweenStats(context, unidad)
                : _buildLinealStats(context, unidad),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            kpi.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: _fg, size: 14),
              const SizedBox(width: 4),
              Text(
                kpi.semaforo[0].toUpperCase() + kpi.semaforo.substring(1),
                style: TextStyle(
                  color: _fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Barra lineal (gte / lte / eq) ────────────────────────────────────────

  Widget _buildProgressBar(BuildContext context) {
    final pct = (kpi.progresoPct / 100).clamp(0.0, 1.0);
    final expectedPct = (kpi.progresoEsperadoPct / 100).clamp(0.0, 1.0);
    final showExpected = kpi.tipoAcumulacion == 'suma' &&
        kpi.condicion != 'between' &&
        kpi.progresoEsperadoPct < 100;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              height: 8,
              width: w * pct,
              decoration: BoxDecoration(
                color: _fg.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            if (showExpected)
              Positioned(
                left: (w * expectedPct - 1).clamp(0, w - 2),
                top: 0,
                child: Container(width: 2, height: 8, color: Colors.grey[500]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLinealStats(BuildContext context, String unidad) {
    final cs = Theme.of(context).colorScheme;
    final simbolo = kpi.condicionSimbolo;
    final objetivo = kpi.objetivoAnual;
    final showRitmo = kpi.tipoAcumulacion == 'suma' &&
        kpi.progresoEsperadoPct > 0 &&
        kpi.progresoEsperadoPct < 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCell(
                label: 'Acumulado',
                value: '${_fmt(kpi.resultadoAcumulado)}$unidad',
                color: _fg,
              ),
            ),
            Expanded(
              child: _StatCell(
                label: 'Objetivo${simbolo != null ? ' ($simbolo)' : ''}',
                value: '${_fmt(objetivo)}$unidad',
                color: cs.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: _StatCell(
                label: 'Progreso',
                value: '${kpi.progresoPct.toStringAsFixed(1)}%',
                color: _fg,
              ),
            ),
          ],
        ),
        if (showRitmo) ...[
          const SizedBox(height: 6),
          Text(
            'Ritmo esperado: ${kpi.progresoEsperadoPct.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  // ── Barra de rango (between) ──────────────────────────────────────────────

  Widget _buildBetweenBar(BuildContext context) {
    final min = kpi.valorMin ?? 0;
    final max = kpi.valorMax ?? 1;
    final result = kpi.resultadoAcumulado;

    // Escala: desde 0 hasta max * 1.4 para dar margen visual
    final scaleMax = max * 1.4;
    final minPct = scaleMax > 0 ? (min / scaleMax).clamp(0.0, 1.0) : 0.0;
    final maxPct = scaleMax > 0 ? (max / scaleMax).clamp(0.0, 1.0) : 1.0;
    final resultPct =
        scaleMax > 0 ? (result / scaleMax).clamp(0.0, 1.0) : 0.5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final markerLeft = (w * resultPct - 2).clamp(0.0, w - 4);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Fondo gris
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Zona verde (rango objetivo)
                  Positioned(
                    top: 4,
                    left: w * minPct,
                    child: Container(
                      height: 8,
                      width: (w * (maxPct - minPct)).clamp(0, w),
                      decoration: BoxDecoration(
                        color: Colors.green.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Marcador del resultado
                  Positioned(
                    top: 0,
                    left: markerLeft,
                    child: Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _fg,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBetweenStats(BuildContext context, String unidad) {
    final cs = Theme.of(context).colorScheme;
    final min = kpi.valorMin ?? 0;
    final max = kpi.valorMax ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCell(
                label: 'Mínimo',
                value: '${_fmt(min)}$unidad',
                color: cs.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: _StatCell(
                label: 'Resultado',
                value: '${_fmt(kpi.resultadoAcumulado)}$unidad',
                color: _fg,
              ),
            ),
            Expanded(
              child: _StatCell(
                label: 'Máximo',
                value: '${_fmt(max)}$unidad',
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Rango objetivo: ${_fmt(min)} – ${_fmt(max)}$unidad',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ─── Stat Cell ────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}
