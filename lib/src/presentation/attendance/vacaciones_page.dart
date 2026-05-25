import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import '../../core/utils/date_formatter.dart';

class VacacionesPage extends StatefulWidget {
  const VacacionesPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<VacacionesPage> createState() => _VacacionesPageState();
}

class _VacacionesPageState extends State<VacacionesPage> {
  bool _loading = true;
  bool _requesting = false;
  String? _error;
  int _anio = DateTime.now().year;
  VacacionesResumenResponse? _resumen;
  List<VacacionesMovimiento> _movimientos = [];

  bool get _puedeSolicitar {
    final resumen = _resumen?.vacaciones;
    if (resumen == null) return false;
    return _anio >= DateTime.now().year &&
        resumen.diasDisponiblesConPendientes > 0;
  }

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
        widget.apiClient.getVacacionesResumen(token: widget.token, anio: _anio),
        widget.apiClient.getVacacionesMovimientos(
          token: widget.token,
          anio: _anio,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _resumen = results[0] as VacacionesResumenResponse;
        _movimientos =
            (results[1] as VacacionesMovimientosResponse).movimientos;
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
        _error = 'Error inesperado al cargar vacaciones.';
        _loading = false;
      });
    }
  }

  Future<void> _changeYear(int delta) async {
    final next = _anio + delta;
    if (next < 2000 || next > 2100 || _loading) return;
    setState(() => _anio = next);
    await _load();
  }

  Future<void> _solicitar() async {
    if (!_puedeSolicitar || _requesting) return;
    final result = await showDialog<_VacacionFormResult>(
      context: context,
      builder: (ctx) => _VacacionFormDialog(
        anio: _anio,
        saldoDisponible: _resumen!.vacaciones.diasDisponiblesConPendientes,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _requesting = true);
    try {
      final response = await widget.apiClient.solicitarVacaciones(
        token: widget.token,
        fechaDesde: result.fechaDesde,
        fechaHasta: result.fechaHasta,
        observacion: result.observacion,
      );
      if (!mounted) return;
      setState(() => _requesting = false);
      final dias = response.solicitud.diasSolicitados;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dias > 0
                ? 'Solicitud enviada ($dias dia${dias == 1 ? '' : 's'}).'
                : 'Solicitud de vacaciones enviada.',
          ),
        ),
      );
      unawaited(_load());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red[700]),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar la solicitud.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vacaciones'),
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
      floatingActionButton: _puedeSolicitar
          ? FloatingActionButton.extended(
              onPressed: _requesting ? null : _solicitar,
              icon: _requesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_requesting ? 'Enviando...' : 'Solicitar'),
            )
          : null,
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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

    final resumen = _resumen;
    if (resumen == null) {
      return const Center(child: Text('Sin datos de vacaciones.'));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, _puedeSolicitar ? 88 : 20),
      children: [
        _YearSelector(
          anio: _anio,
          onPrevious: () => _changeYear(-1),
          onNext: () => _changeYear(1),
        ),
        const SizedBox(height: 12),
        _SaldoResumenCard(resumen: resumen, puedeSolicitar: _puedeSolicitar),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Movimientos',
          subtitle: _movimientos.isEmpty
              ? 'No hay movimientos en $_anio.'
              : '${_movimientos.length} movimiento${_movimientos.length == 1 ? '' : 's'}',
        ),
        const SizedBox(height: 8),
        if (_movimientos.isEmpty)
          const _EmptyMovimientos()
        else
          ..._movimientos.map((m) => _MovimientoCard(movimiento: m)),
      ],
    );
  }
}

class _YearSelector extends StatelessWidget {
  const _YearSelector({
    required this.anio,
    required this.onPrevious,
    required this.onNext,
  });

  final int anio;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Anio anterior',
          onPressed: anio > 2000 ? onPrevious : null,
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '$anio',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Anio siguiente',
          onPressed: anio < 2100 ? onNext : null,
        ),
      ],
    );
  }
}

class _SaldoResumenCard extends StatelessWidget {
  const _SaldoResumenCard({
    required this.resumen,
    required this.puedeSolicitar,
  });

  final VacacionesResumenResponse resumen;
  final bool puedeSolicitar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saldo = resumen.vacaciones;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.beach_access_outlined, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    resumen.empleado.nombre ?? 'Resumen anual',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  label: 'Disponible',
                  value: _formatDias(saldo.diasDisponiblesConPendientes),
                  color: saldo.diasDisponiblesConPendientes > 0
                      ? Colors.green.shade700
                      : cs.error,
                ),
                _MetricPill(
                  label: 'Pendiente',
                  value: _formatDias(saldo.diasPendientes),
                  color: Colors.amber.shade800,
                ),
                _MetricPill(
                  label: 'Tomado',
                  value: _formatDias(saldo.diasTomados),
                  color: cs.primary,
                ),
                _MetricPill(
                  label: 'Corresponde',
                  value: _formatDias(saldo.diasCorresponden),
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (saldo.desgloseCorresponde.isNotEmpty)
              _DesgloseCorresponde(desglose: saldo.desgloseCorresponde)
            else ...[
              _ResumenLine(
                label: 'Base calculada',
                value: '${_formatDias(saldo.diasBase)} dias',
              ),
              if (saldo.diasCompensatorios + saldo.diasAjustes != 0)
                _ResumenLine(
                  label: 'Compensatorios y ajustes',
                  value:
                      '${_formatDias(saldo.diasCompensatorios + saldo.diasAjustes)} dias',
                ),
            ],
            _ResumenLine(
              label: 'Antiguedad al 31/12',
              value: '${saldo.antiguedadAl3112} anios',
            ),
            _ResumenLine(
              label: 'Dias trabajados',
              value: saldo.diasTrabajadosPorcentaje != null
                  ? '${saldo.diasTrabajadosAnio} de ${saldo.diasHabilesAnio} (${saldo.diasTrabajadosPorcentaje!.toStringAsFixed(1)}%)'
                  : '${saldo.diasTrabajadosAnio}/${saldo.diasHabilesAnio}',
            ),
            if (saldo.aplicaControlProporcional && !saldo.calculoProporcional)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _InfoBanner(
                  text:
                      'Tenes menos de 1 anio de antiguedad. Si trabajas menos del ${saldo.umbralProporcionalPct.toStringAsFixed(0)}% de los dias habiles, el saldo se recalcula proporcionalmente.',
                  icon: Icons.info_outline,
                  color: cs.primaryContainer,
                  onColor: cs.onPrimaryContainer,
                ),
              ),
            if (saldo.calculoProporcional)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _InfoBanner(
                  text:
                      'El saldo se calculo proporcionalmente por dias trabajados.',
                  icon: Icons.info_outline,
                  color: cs.primaryContainer,
                  onColor: cs.onPrimaryContainer,
                ),
              ),
            if (!puedeSolicitar) ...[
              const SizedBox(height: 10),
              _InfoBanner(
                text: saldo.diasDisponiblesConPendientes <= 0
                    ? 'No hay saldo disponible para nuevas solicitudes.'
                    : 'Solo se pueden crear solicitudes para el anio actual o posterior.',
                icon: Icons.lock_outline,
                color: cs.surfaceContainerHighest,
                onColor: cs.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 142,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            '$value dias',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesgloseCorresponde extends StatelessWidget {
  const _DesgloseCorresponde({required this.desglose});
  final List<VacacionesDesgloseDia> desglose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final partes = desglose.map((d) => '${_formatDias(d.dias)} ${d.concepto}').join('  +  ');
    final total = desglose.fold<double>(0, (s, d) => s + d.dias);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Corresponde',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              desglose.length > 1
                  ? '$partes  =  ${_formatDias(total)} dias'
                  : '${_formatDias(total)} dias',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumenLine extends StatelessWidget {
  const _ResumenLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.text,
    required this.icon,
    required this.color,
    required this.onColor,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: onColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: onColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EmptyMovimientos extends StatelessWidget {
  const _EmptyMovimientos();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, size: 34, color: cs.primary),
          const SizedBox(height: 10),
          Text(
            'Sin movimientos de vacaciones.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MovimientoCard extends StatelessWidget {
  const _MovimientoCard({required this.movimiento});

  final VacacionesMovimiento movimiento;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esReversion = movimiento.esReversion;
    final afectaSaldo = movimiento.afectaSaldo;
    final opacity = afectaSaldo ? 1.0 : 0.55;

    return Opacity(
      opacity: opacity,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: esReversion
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: cs.outlineVariant,
                  style: BorderStyle.solid,
                ),
              )
            : null,
        color: esReversion ? cs.surfaceContainerHighest : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    esReversion ? Icons.undo : _tipoIcon(movimiento.tipo),
                    size: 22,
                    color: esReversion ? cs.onSurfaceVariant : cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      esReversion
                          ? 'Reversión'
                          : _tipoLabel(movimiento.tipo),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: esReversion ? cs.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                  if (!esReversion) _EstadoChip(estado: movimiento.estado),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.date_range_outlined, size: 16, color: cs.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _dateRange(movimiento.fechaDesde, movimiento.fechaHasta),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatDias(movimiento.dias)} dia${movimiento.dias == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (movimiento.observacion != null) ...[
                const SizedBox(height: 8),
                Text(
                  movimiento.observacion!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (!afectaSaldo) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'No afecta tu saldo',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
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
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({this.estado});

  final String? estado;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (estado) {
      'aprobado' => ('Aprobado', Colors.green.shade100, Colors.green.shade900),
      'rechazado' => ('Rechazado', cs.errorContainer, cs.onErrorContainer),
      _ => ('Pendiente', cs.primaryContainer, cs.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VacacionFormResult {
  const _VacacionFormResult({
    required this.fechaDesde,
    required this.fechaHasta,
    this.observacion,
  });

  final String fechaDesde;
  final String fechaHasta;
  final String? observacion;
}

class _VacacionFormDialog extends StatefulWidget {
  const _VacacionFormDialog({
    required this.anio,
    required this.saldoDisponible,
  });

  final int anio;
  final double saldoDisponible;

  @override
  State<_VacacionFormDialog> createState() => _VacacionFormDialogState();
}

class _VacacionFormDialogState extends State<_VacacionFormDialog> {
  DateTime? _inicio;
  DateTime? _fin;
  final _observacionCtrl = TextEditingController();

  @override
  void dispose() {
    _observacionCtrl.dispose();
    super.dispose();
  }

  DateTime get _firstDate {
    final yearStart = DateTime(widget.anio);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    if (widget.anio == normalizedToday.year &&
        normalizedToday.isAfter(yearStart)) {
      return normalizedToday;
    }
    return yearStart;
  }

  DateTime get _lastDate => DateTime(widget.anio, 12, 31);

  Future<void> _pickDate({required bool isInicio}) async {
    final first = _firstDate;
    final last = _lastDate;
    final initial = isInicio ? (_inicio ?? first) : (_fin ?? _inicio ?? first);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    setState(() {
      if (isInicio) {
        _inicio = picked;
        if (_fin != null && _fin!.isBefore(picked)) _fin = null;
      } else {
        _fin = picked;
      }
    });
  }

  int get _diasSeleccionados {
    final inicio = _inicio;
    final fin = _fin;
    if (inicio == null || fin == null || fin.isBefore(inicio)) return 0;
    return fin.difference(inicio).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dias = _diasSeleccionados;
    final saldo = widget.saldoDisponible;
    final excedeSaldo = dias > 0 && dias > saldo;
    final canSubmit = dias > 0 && !excedeSaldo;

    return AlertDialog(
      title: const Text('Solicitar vacaciones'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoBanner(
              text: 'Saldo disponible: ${_formatDias(saldo)} dias',
              icon: Icons.beach_access_outlined,
              color: cs.surfaceContainerHighest,
              onColor: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Fecha inicio'),
              subtitle: Text(_displayDate(_inicio)),
              onTap: () => _pickDate(isInicio: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Fecha fin'),
              subtitle: Text(_displayDate(_fin)),
              onTap: () => _pickDate(isInicio: false),
            ),
            if (dias > 0) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$dias dia${dias == 1 ? '' : 's'} seleccionados',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: excedeSaldo ? cs.error : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (excedeSaldo) ...[
              const SizedBox(height: 8),
              _InfoBanner(
                text: 'La solicitud supera el saldo disponible.',
                icon: Icons.error_outline,
                color: cs.errorContainer,
                onColor: cs.onErrorContainer,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _observacionCtrl,
              decoration: const InputDecoration(
                labelText: 'Observacion (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () => Navigator.of(context).pop(
                  _VacacionFormResult(
                    fechaDesde: DateFormatter.formatApiDate(_inicio!),
                    fechaHasta: DateFormatter.formatApiDate(_fin!),
                    observacion: _observacionCtrl.text.trim().isEmpty
                        ? null
                        : _observacionCtrl.text.trim(),
                  ),
                )
              : null,
          child: const Text('Enviar'),
        ),
      ],
    );
  }

  String _displayDate(DateTime? date) {
    if (date == null) return 'Sin seleccionar';
    return DateFormatter.formatDisplayDate(date);
  }
}

String _formatDias(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _dateRange(String? desde, String? hasta) {
  final start = DateFormatter.formatApiDateForDisplay(desde);
  final end = DateFormatter.formatApiDateForDisplay(hasta);
  if (start == '-' && end == '-') return 'Sin rango de fechas';
  if (start == end || end == '-') return start;
  if (start == '-') return end;
  return '$start - $end';
}

String _tipoLabel(String? tipo) {
  return switch (tipo) {
    'compensatorio' => 'Compensatorio',
    'ajuste' => 'Ajuste',
    _ => 'Vacaciones tomadas',
  };
}

IconData _tipoIcon(String? tipo) {
  return switch (tipo) {
    'compensatorio' => Icons.add_circle_outline,
    'ajuste' => Icons.tune_outlined,
    _ => Icons.beach_access_outlined,
  };
}
