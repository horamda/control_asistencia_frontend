import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class HorariosPage extends StatefulWidget {
  const HorariosPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<HorariosPage> createState() => _HorariosPageState();
}

class _HorariosPageState extends State<HorariosPage> {
  bool _loading = true;
  String? _error;
  HorarioActualResponse? _actual;
  List<AsignacionHorario> _historial = [];

  static const _diasNombres = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };

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
      final results = await Future.wait([
        widget.apiClient.getHorarioActual(token: widget.token),
        widget.apiClient.getHorarios(token: widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _actual = results[0] as HorarioActualResponse;
        _historial = results[1] as List<AsignacionHorario>;
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
        _error = 'Error inesperado al cargar los horarios.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horarios'),
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildActualSection(),
        const SizedBox(height: 24),
        _buildHistorialSection(),
      ],
    );
  }

  Widget _buildActualSection() {
    final cs = Theme.of(context).colorScheme;
    final actual = _actual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horario vigente',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: actual == null || actual.asignacion == null
                ? const Row(
                    children: [
                      Icon(Icons.schedule_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Sin horario asignado actualmente'),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 20,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              actual.asignacion!.horarioNombre ??
                                  'Horario #${actual.asignacion!.horarioId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (actual.asignacion!.fechaDesde != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Desde: ${actual.asignacion!.fechaDesde}${actual.asignacion!.fechaHasta != null ? '  •  Hasta: ${actual.asignacion!.fechaHasta}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (actual.dias.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: actual.dias.map((dia) {
                            final nombre = _diasNombres[dia] ?? 'Día $dia';
                            return Chip(
                              label: Text(
                                nombre.substring(0, 3),
                                style: const TextStyle(fontSize: 12),
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: cs.primaryContainer,
                              labelStyle: TextStyle(color: cs.onPrimaryContainer),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorialSection() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historial de asignaciones',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (_historial.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Sin historial de horarios.')),
            ),
          )
        else
          ..._historial.map((a) => _AsignacionCard(asignacion: a)),
      ],
    );
  }
}

class _AsignacionCard extends StatelessWidget {
  const _AsignacionCard({required this.asignacion});
  final AsignacionHorario asignacion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vigente = asignacion.fechaHasta == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              vigente ? Icons.schedule : Icons.history,
              size: 20,
              color: vigente ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asignacion.horarioNombre ??
                        'Horario #${asignacion.horarioId}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${asignacion.fechaDesde ?? '—'} → ${asignacion.fechaHasta ?? 'actualidad'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (vigente)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Vigente',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
