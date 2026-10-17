import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import '../widgets/app_page_layout.dart';
import '../widgets/scrollable_error_state.dart';
import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import 'widgets/horario_semanal.dart';

class HorariosPage extends StatefulWidget {
  const HorariosPage({super.key, required this.apiClient, required this.token});

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
        title: const Text('Horarios', textAlign: TextAlign.center),
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
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
              onPressed: _load,
            ),
        ],
      ),
      body: AppPageBody(
        child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return ScrollableErrorState(message: _error!, onRetry: _load);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildActualSection(),
                const SizedBox(height: 24),
                HorarioSemanal(
                  apiClient: widget.apiClient,
                  token: widget.token,
                ),
                const SizedBox(height: 24),
                _buildHistorialSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActualSection() {
    final cs = Theme.of(context).colorScheme;
    final actual = _actual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Horario vigente',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: actual == null || actual.asignacion == null
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule_rounded, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sin horario asignado actualmente',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
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
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      if (actual.asignacion!.fechaDesde != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Desde: ${actual.asignacion!.fechaDesde}${actual.asignacion!.fechaHasta != null ? '  •  Hasta: ${actual.asignacion!.fechaHasta}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (actual.dias.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: actual.dias.map((dia) {
                            final nombre = _diasNombres[dia] ?? 'Día $dia';
                            return Chip(
                              label: Text(
                                nombre.substring(0, 3),
                                style: const TextStyle(fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: cs.primaryContainer,
                              labelStyle: TextStyle(
                                color: cs.onPrimaryContainer,
                              ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Historial de asignaciones',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (_historial.isEmpty)
          const AppCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Sin historial de horarios.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          ..._historial.map(
            (a) => _AsignacionCard(
              asignacion: a,
              vigente: a.id == _actual?.asignacion?.id,
            ),
          ),
      ],
    );
  }
}

class _AsignacionCard extends StatelessWidget {
  const _AsignacionCard({required this.asignacion, required this.vigente});
  final AsignacionHorario asignacion;
  final bool vigente;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              vigente ? Icons.schedule_rounded : Icons.history_rounded,
              size: 20,
              color: vigente ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    asignacion.horarioNombre ??
                        'Horario #${asignacion.horarioId}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${asignacion.fechaDesde ?? '—'} → ${asignacion.fechaHasta ?? 'actualidad'}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
