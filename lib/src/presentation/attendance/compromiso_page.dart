import 'package:ficharqr/src/presentation/theme/app_palette.dart';
import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import '../widgets/scrollable_error_state.dart';

/// Indice de compromiso: el del area del empleado, su sucursal y la empresa, con el año anterior (contrato 1.55.0).
class CompromisoPage extends StatefulWidget {
  const CompromisoPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<CompromisoPage> createState() => _CompromisoPageState();
}

class _CompromisoPageState extends State<CompromisoPage> {
  bool _loading = true;
  String? _error;
  CompromisoResponse? _data;

  /// null: el ultimo año con datos (lo elige el servidor).
  int? _anio;

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
      final data = await widget.apiClient.getCompromiso(
        token: widget.token,
        anio: _anio,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _anio = data.anio;
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
        _error = 'Error inesperado al cargar el índice de compromiso.';
        _loading = false;
      });
    }
  }

  void _elegirAnio(int anio) {
    if (anio == _anio) return;
    setState(() => _anio = anio);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Índice de compromiso'),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data;
    if (_loading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ScrollableErrorState(message: _error!, onRetry: _load);
    }
    if (data == null) return const SizedBox.shrink();
    final anios = {...data.aniosDisponibles, data.anio}.toList()
      ..sort((a, b) => b.compareTo(a));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (anios.length > 1)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in anios)
                  ChoiceChip(
                    label: Text('$a'),
                    selected: a == data.anio,
                    onSelected: _loading ? null : (_) => _elegirAnio(a),
                  ),
              ],
            )
          else
            Center(
              child: Text(
                '${data.anio}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 16),
          if (data.sinDatos)
            const _SinDatos()
          else ...[
            _NivelCard(
              titulo: 'Mi área',
              nivel: data.area,
              destacado: true,
              anio: data.anio,
            ),
            const SizedBox(height: 12),
            _NivelCard(
              titulo: 'Mi sucursal',
              nivel: data.sucursal,
              anio: data.anio,
            ),
            const SizedBox(height: 12),
            _NivelCard(
              titulo: 'La empresa',
              nivel: data.empresa,
              anio: data.anio,
            ),
            const SizedBox(height: 16),
            Text(
              'El índice mide cuánto se identifican las personas con su trabajo y la empresa, de 0 a 100. '
              'Lo carga Recursos Humanos con el resultado de la encuesta.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _NivelCard extends StatelessWidget {
  const _NivelCard({
    required this.titulo,
    required this.nivel,
    required this.anio,
    this.destacado = false,
  });

  final String titulo;
  final CompromisoNivel nivel;
  final int anio;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final indice = nivel.indice;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppPalette.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              nivel.nombre,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (indice == null)
              Text(
                'Sin dato para $anio',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.muted,
                ),
              )
            else ...[
              Text(
                '${indice.toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                style:
                    (destacado
                            ? theme.textTheme.displaySmall
                            : theme.textTheme.headlineMedium)
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (indice / 100).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  semanticsLabel: '$titulo: ${indice.toStringAsFixed(1)} %',
                ),
              ),
              const SizedBox(height: 8),
              _Variacion(nivel: nivel),
              if (nivel.calculado)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Promedio de las áreas',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.muted,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Variacion extends StatelessWidget {
  const _Variacion({required this.nivel});

  final CompromisoNivel nivel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variacion = nivel.variacion;
    if (variacion == null) {
      return Text(
        nivel.anterior == null
            ? 'Sin dato del año anterior'
            : 'Año anterior: ${nivel.anterior!.toStringAsFixed(1)}%',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.muted),
      );
    }
    final sube = variacion > 0;
    final igual = variacion == 0;
    final color = igual
        ? AppPalette.muted
        : (sube ? AppPalette.success : AppPalette.danger);
    final icono = igual
        ? Icons.trending_flat_rounded
        : (sube ? Icons.trending_up_rounded : Icons.trending_down_rounded);
    final signo = sube ? '+' : '';
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Icon(icono, size: 18, color: color),
        Text(
          '$signo${variacion.toStringAsFixed(1)} puntos vs. año anterior '
          '(${nivel.anterior!.toStringAsFixed(1)}%)',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SinDatos extends StatelessWidget {
  const _SinDatos();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 48,
            color: AppPalette.muted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no hay datos',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cuando Recursos Humanos cargue el resultado de la encuesta de compromiso, lo vas a ver acá.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
