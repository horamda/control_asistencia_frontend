import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'package:flutter/material.dart';
import '../../../core/network/mobile_api_client.dart';
import '../../theme/app_palette.dart';
import '../../theme/card_typography.dart';

/// Uses only the employee-bound branch scope returned by the server.
class BranchSafetyCard extends StatefulWidget {
  const BranchSafetyCard({
    super.key,
    required this.api,
    required this.token,
    required this.onOpen,
    this.offline = false,
  });
  final MobileApiClient api;
  final String token;
  final VoidCallback onOpen;
  final bool offline;

  @override
  State<BranchSafetyCard> createState() => BranchSafetyCardState();
}

class BranchSafetyCardState extends State<BranchSafetyCard>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _data;
  bool _loading = true, _failed = false;
  int _generation = 0;
  DateTime? _loadedAt;
  Future<void>? _pending;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void didUpdateWidget(covariant BranchSafetyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token ||
        oldWidget.api != widget.api ||
        oldWidget.offline != widget.offline) {
      _generation++;
      _pending = null;
      _loadedAt = null;
      _data = null;
      refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh(force: false);
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refresh({bool force = true}) {
    if (_pending != null) return _pending!;
    final now = DateTime.now();
    final loadedAt = _loadedAt;
    if (!force &&
        !_failed &&
        loadedAt != null &&
        now.difference(loadedAt) < const Duration(minutes: 1) &&
        now.year == loadedAt.year &&
        now.month == loadedAt.month &&
        now.day == loadedAt.day) {
      return Future<void>.value();
    }
    final request = _load();
    _pending = request;
    return request.whenComplete(() {
      if (identical(_pending, request)) _pending = null;
    });
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (widget.offline) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await widget.api.getSeguridad(
        token: widget.token,
        path: '/indicadores',
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _loadedAt = DateTime.now();
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final branchName = (_data?['sucursal_nombre'] as String?)?.trim();
    final branchLabel = branchName == null || branchName.isEmpty
        ? 'Mi sucursal'
        : branchName;
    final scopes = _data?['alcances'];
    final branch = scopes is Map && scopes['sucursal'] is Map
        ? scopes['sucursal'] as Map
        : const {};
    final days = int.tryParse('${branch['dias_sin_accidentes']}');
    final available = branch['disponible'] == true && days != null && days >= 0;
    final cutoff = DateTime.tryParse('${_data?['hasta']}');
    final now = DateTime.now();
    final current =
        cutoff != null &&
        cutoff.year == now.year &&
        cutoff.month == now.month &&
        cutoff.day == now.day;
    final confirmed = available && current && !_failed && !_loading && days > 0;
    final colors = Theme.of(context).colorScheme;
    final foreground = confirmed ? AppPalette.success : colors.onSurface;
    final reason = switch (branch['motivo']) {
      'sin_sucursal' => 'No tenés una sucursal asignada.',
      'sin_inicio_configurado' => 'Falta configurar el inicio del registro.',
      _ => 'Sin datos disponibles',
    };
    final date = cutoff == null
        ? 'Fecha de corte no disponible'
        : 'Datos al ${cutoff.day.toString().padLeft(2, '0')}/${cutoff.month.toString().padLeft(2, '0')}/${cutoff.year}';
    return AppCard(
      color: confirmed
          ? colors.brightness == Brightness.dark
                ? Color.alphaBlend(
                    const Color(0xFF6EE7A0).withValues(alpha: .10),
                    colors.surface,
                  )
                : const Color(0xFFEAF5EF)
          : colors.surface,
      child: InkWell(
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.health_and_safety_outlined,
                      color: AppColors.of(context).foreground(foreground),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seguridad en tu sucursal',
                        style: CardTypography.label(context),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loading && _data == null)
                  const Text(
                    'Consultando días sin accidentes…',
                    textAlign: TextAlign.center,
                  )
                else if (available) ...[
                  Text(
                    '$days ${days == 1 ? 'día' : 'días'} sin accidentes',
                    style: CardTypography.indicator(context).copyWith(
                      color: AppColors.of(context).foreground(foreground),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$branchLabel · $date',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_failed)
                    const Text(
                      'No se pudo actualizar. Se muestra la última consulta.',
                      textAlign: TextAlign.center,
                    )
                  else if (!current)
                    const Text(
                      'El dato no corresponde al día de hoy.',
                      textAlign: TextAlign.center,
                    ),
                ] else
                  Text(
                    _failed
                        ? 'Sin datos disponibles. No se pudo consultar el indicador.'
                        : reason,
                    textAlign: TextAlign.center,
                  ),
                if (_loading && _data != null) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_failed && !widget.offline)
                  TextButton.icon(
                    onPressed: _loading ? null : refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'Reintentar',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (widget.offline)
                  const Text(
                    'Conectate para actualizar el indicador.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
