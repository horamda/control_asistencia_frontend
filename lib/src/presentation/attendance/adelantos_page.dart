import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class AdelantosPage extends StatefulWidget {
  const AdelantosPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<AdelantosPage> createState() => _AdelantosPageState();
}

class _AdelantosPageState extends State<AdelantosPage> {
  bool _loading = true;
  bool _requesting = false;
  String? _error;
  AdelantoEstadoResponse? _estado;

  static const _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

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
      final estado = await widget.apiClient.getAdelantoEstado(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = switch (e.statusCode) {
        null => 'Sin conexión al servidor. Verificá tu red e intentá de nuevo.',
        404 =>
          'La función de adelantos no está disponible en este momento. '
              'Contactá a RRHH si el problema persiste.',
        401 || 403 => 'Tu sesión no tiene acceso a esta sección.',
        _ => e.message,
      };
      setState(() {
        _error = msg;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error inesperado al consultar el adelanto.';
        _loading = false;
      });
    }
  }

  Future<void> _solicitar() async {
    final estado = _estado;
    if (estado == null) return;

    final mes = _mesLabel(estado.periodoMonth, estado.periodoYear);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar adelanto'),
        content: Text(
          '¿Confirmás la solicitud de adelanto de sueldo para $mes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _requesting = true);
    try {
      final adelanto = await widget.apiClient.createAdelanto(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _estado = AdelantoEstadoResponse(
          periodo: estado.periodo,
          periodoYear: estado.periodoYear,
          periodoMonth: estado.periodoMonth,
          yaSolicitado: true,
          adelanto: adelanto,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adelanto solicitado correctamente.')),
        );
      }
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
          content: Text('No se pudo solicitar el adelanto.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _mesLabel(int month, int year) {
    final nombre = (month >= 1 && month <= 12) ? _meses[month] : '—';
    return '$nombre $year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adelantos'),
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

    final estado = _estado;
    if (estado == null) {
      return const Center(child: Text('Sin datos.'));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodoHeader(
            label: _mesLabel(estado.periodoMonth, estado.periodoYear),
          ),
          const SizedBox(height: 20),
          if (!estado.yaSolicitado)
            _SinSolicitudCard(
              mes: _mesLabel(estado.periodoMonth, estado.periodoYear),
              requesting: _requesting,
              onSolicitar: _solicitar,
            )
          else
            _AdelantoCard(adelanto: estado.adelanto),
        ],
      ),
    );
  }
}

// ── Periodo header ────────────────────────────────────────────────────────────

class _PeriodoHeader extends StatelessWidget {
  const _PeriodoHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.calendar_month_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Sin solicitud ─────────────────────────────────────────────────────────────

class _SinSolicitudCard extends StatelessWidget {
  const _SinSolicitudCard({
    required this.mes,
    required this.requesting,
    required this.onSolicitar,
  });

  final String mes;
  final bool requesting;
  final VoidCallback onSolicitar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.payments_outlined,
              size: 48,
              color: cs.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin solicitud este mes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Podés solicitar un adelanto de sueldo para $mes. '
              'Solo se permite una solicitud por mes.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: requesting ? null : onSolicitar,
                icon: requesting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  requesting ? 'Solicitando...' : 'Solicitar adelanto',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Adelanto existente ────────────────────────────────────────────────────────

class _AdelantoCard extends StatelessWidget {
  const _AdelantoCard({required this.adelanto});

  final AdelantoItem? adelanto;

  @override
  Widget build(BuildContext context) {
    final estado = adelanto?.estado ?? 'pendiente';
    final fecha = adelanto?.fechaSolicitud;

    final (label, color, icon) = switch (estado) {
      'aprobado' => (
          'Aprobado',
          Colors.green[700]!,
          Icons.check_circle_outline,
        ),
      'rechazado' => (
          'Rechazado',
          Colors.red[700]!,
          Icons.cancel_outlined,
        ),
      'cancelado' => (
          'Cancelado',
          Colors.grey[600]!,
          Icons.block_outlined,
        ),
      _ => (
          'Pendiente de aprobación',
          Colors.amber[700]!,
          Icons.hourglass_empty_outlined,
        ),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                      ),
                      if (fecha != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Solicitado el $fecha',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _mensajeEstado(estado),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mensajeEstado(String estado) {
    return switch (estado) {
      'aprobado' =>
        'Tu solicitud fue aprobada. El adelanto será acreditado según la política de la empresa.',
      'rechazado' =>
        'Tu solicitud fue rechazada. Podés consultar con RRHH para más información.',
      'cancelado' =>
        'La solicitud fue cancelada.',
      _ =>
        'Tu solicitud está siendo revisada por el área de RRHH. Te notificarán cuando haya una respuesta.',
    };
  }
}
