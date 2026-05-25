import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class PremiosPage extends StatefulWidget {
  const PremiosPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<PremiosPage> createState() => _PremiosPageState();
}

class _PremiosPageState extends State<PremiosPage> {
  bool _loading = true;
  String? _error;
  PremiosResponse? _data;
  late int _anio;

  @override
  void initState() {
    super.initState();
    _anio = DateTime.now().year;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.apiClient.getPremios(
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
        _error = 'Error inesperado al cargar los premios.';
        _loading = false;
      });
    }
  }

  void _changeYear(int delta) {
    setState(() => _anio += delta);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premios y Concursos'),
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
      body: Column(
        children: [
          _YearSelector(
            anio: _anio,
            onPrev: () => _changeYear(-1),
            onNext: _anio < DateTime.now().year ? () => _changeYear(1) : null,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
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

    final data = _data;
    if (data == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (data.sector?.nombre != null) ...[
            const SizedBox(height: 12),
            _SectorChip(nombre: data.sector!.nombre!),
          ],
          const SizedBox(height: 16),
          _ResumenHeader(resumen: data.resumen),
          const SizedBox(height: 20),
          if (data.resumen.totalPremios == 0)
            _EmptyYear(anio: _anio)
          else
            ...data.meses.map((mes) => _MesCard(mes: mes)),
        ],
      ),
    );
  }
}

// ─── Year selector ────────────────────────────────────────────────────────────

class _YearSelector extends StatelessWidget {
  const _YearSelector({
    required this.anio,
    required this.onPrev,
    this.onNext,
  });

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
            tooltip: 'Año anterior',
          ),
          const SizedBox(width: 8),
          Text(
            '$anio',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Año siguiente',
            color: onNext != null ? null : cs.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

// ─── Sector chip ──────────────────────────────────────────────────────────────

class _SectorChip extends StatelessWidget {
  const _SectorChip({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_outlined, size: 14, color: cs.onSecondaryContainer),
              const SizedBox(width: 6),
              Text(
                nombre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Resumen header ───────────────────────────────────────────────────────────

class _ResumenHeader extends StatelessWidget {
  const _ResumenHeader({required this.resumen});

  final PremiosResumen resumen;

  @override
  Widget build(BuildContext context) {
    if (resumen.totalPremios == 0) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ResumenTile(
          icon: Icons.emoji_events_outlined,
          label: 'Premios',
          value: '${resumen.totalPremios}',
          color: Colors.amber.shade700,
        ),
        if (resumen.mejorRanking != null)
          _ResumenTile(
            icon: Icons.trending_up_outlined,
            label: 'Mejor puesto',
            value: '${resumen.mejorRanking}°',
            color: _rankColor(resumen.mejorRanking!),
          ),
        if (resumen.primerosPuestos > 0)
          _ResumenTile(
            icon: Icons.looks_one_outlined,
            label: '1° puestos',
            value: '${resumen.primerosPuestos}',
            color: Colors.amber.shade600,
          ),
        if (resumen.podios > 0)
          _ResumenTile(
            icon: Icons.military_tech_outlined,
            label: 'Podios',
            value: '${resumen.podios}',
            color: Colors.blueGrey.shade600,
          ),
      ],
    );
  }

  Color _rankColor(int rank) {
    return switch (rank) {
      1 => Colors.amber.shade700,
      2 => Colors.blueGrey.shade400,
      3 => Colors.brown.shade400,
      _ => Colors.blueGrey.shade600,
    };
  }
}

class _ResumenTile extends StatelessWidget {
  const _ResumenTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color.withValues(alpha: 0.85),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Mes card ─────────────────────────────────────────────────────────────────

class _MesCard extends StatelessWidget {
  const _MesCard({required this.mes});

  final PremiosMesItem mes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tienePremios = mes.premios.isNotEmpty;

    if (!tienePremios) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                mes.nombre ?? 'Mes ${mes.mes}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.35),
                    ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              mes.nombre ?? 'Mes ${mes.mes}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
          ...mes.premios.map((p) => _PremioCard(premio: p)),
        ],
      ),
    );
  }
}

// ─── Premio card ──────────────────────────────────────────────────────────────

class _PremioCard extends StatelessWidget {
  const _PremioCard({required this.premio});

  final PremioItem premio;

  static Color _rankColor(int? rank) {
    return switch (rank) {
      1 => Colors.amber.shade700,
      2 => Colors.blueGrey.shade400,
      3 => Colors.brown.shade400,
      _ => Colors.blueGrey.shade600,
    };
  }

  static IconData _rankIcon(int? rank) {
    return switch (rank) {
      1 => Icons.looks_one_outlined,
      2 => Icons.looks_two_outlined,
      3 => Icons.looks_3_outlined,
      _ => Icons.emoji_events_outlined,
    };
  }

  static String _rankLabel(int? rank) {
    if (rank == null) return '—';
    return switch (rank) {
      1 => '1° Puesto',
      2 => '2° Puesto',
      3 => '3° Puesto',
      _ => '$rank° Puesto',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _rankColor(premio.ranking);
    final concursoNombre =
        premio.concurso?.nombre ?? premio.concurso?.codigo ?? 'Concurso';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              color: color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_rankIcon(premio.ranking),
                          color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            concursoNombre,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (premio.concurso?.alcance == 'global')
                            Text(
                              'Concurso general',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            )
                          else if (premio.sectorEmpleado?.nombre != null)
                            Text(
                              premio.sectorEmpleado!.nombre!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          if ((premio.observaciones ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              premio.observaciones!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _rankLabel(premio.ranking),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty year ───────────────────────────────────────────────────────────────

class _EmptyYear extends StatelessWidget {
  const _EmptyYear({required this.anio});

  final int anio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Sin premios en $anio',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí aparecerán tus rankings cuando participes en concursos.',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
