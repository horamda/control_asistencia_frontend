import '../theme/app_palette.dart';
import 'ranking_entry_layout.dart';
import '../widgets/app_page_layout.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

const _kPrimary = AppPalette.navy;
const _kGold = Color(0xFFF5A623);
const _kSilver = Color(0xFF9E9E9E);
const _kBronze = Color(0xFF795548);

class TriviaAnnualRankingScreen extends StatefulWidget {
  const TriviaAnnualRankingScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.anio,
    required this.empleadoDni,
  });

  final MobileApiClient apiClient;
  final String token;
  final int anio;
  final String empleadoDni;

  @override
  State<TriviaAnnualRankingScreen> createState() =>
      _TriviaAnnualRankingScreenState();
}

class _TriviaAnnualRankingScreenState extends State<TriviaAnnualRankingScreen> {
  TriviaRankingAnualResponse? _ranking;
  TriviaGanadorAnualResponse? _ganador;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiClient.getRankingAnual(
          token: widget.token,
          anio: widget.anio,
        ),
        widget.apiClient
            .getGanadorAnual(token: widget.token, anio: widget.anio)
            .then<TriviaGanadorAnualResponse?>((v) => v)
            .catchError((_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _ranking = results[0] as TriviaRankingAnualResponse;
        _ganador = results[1] as TriviaGanadorAnualResponse?;
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
        _error = 'No se pudo obtener el ranking anual.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranking = _ranking;
    final items = ranking?.items ?? [];
    return Scaffold(
      backgroundColor: AppColors.of(context).surface(AppPalette.background),
      appBar: AppBar(
        title: Text(
          'Ranking Anual ${widget.anio}',
          textAlign: TextAlign.center,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: AppPageBody(
        maxWidth: 840,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeaderBanner(anio: widget.anio),
                    const SizedBox(height: 12),
                    if (_ganador != null) ...[
                      _GanadorAnualCard(ganador: _ganador!),
                      const SizedBox(height: 12),
                    ],
                    if (items.isEmpty)
                      _EmptyState()
                    else ...[
                      Text(
                        'Clasificación',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.of(
                            context,
                          ).foreground(Colors.grey.shade600),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ...items.map((item) => _AnualRankingTile(item: item)),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.anio});
  final int anio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.of(context).brandGradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '👑',
            style: TextStyle(fontSize: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Ranking Anual',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Trivia $anio',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GanadorAnualCard extends StatelessWidget {
  const _GanadorAnualCard({required this.ganador});
  final TriviaGanadorAnualResponse ganador;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface(_kGold.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.of(context).border(_kGold.withValues(alpha: 0.4)),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '👑🏆',
            style: TextStyle(fontSize: 36),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'GANADOR DEL AÑO',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.of(context).foreground(const Color(0xFF7A4800)),
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            ganador.empleadoNombre ?? 'Campeón',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.of(context).foreground(const Color(0xFF7A4800)),
            ),
            textAlign: TextAlign.center,
          ),
          if (ganador.sector != null)
            Text(
              ganador.sector!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.of(context).foreground(Colors.brown.shade400),
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              if (ganador.puntosAnuales != null)
                _Chip(label: '${ganador.puntosAnuales} pts'),
              if (ganador.triviasGanadas != null)
                _Chip(label: '${ganador.triviasGanadas} ganadas'),
              if (ganador.triviasParticipadas != null)
                _Chip(label: '${ganador.triviasParticipadas} jugadas'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Fuiste el mejor participante anual de la Trivia. Tu compromiso con la mejora continua es un ejemplo para todos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.of(context).foreground(Colors.brown.shade600),
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '👏 ¡Excelente trabajo!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.of(context).foreground(const Color(0xFF7A4800)),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface(_kGold.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.of(context).border(_kGold.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.of(context).foreground(const Color(0xFF7A4800)),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _AnualRankingTile extends StatelessWidget {
  const _AnualRankingTile({required this.item});
  final TriviaRankingAnualItem item;

  Color get _posColor {
    switch (item.posicion) {
      case 1:
        return _kGold;
      case 2:
        return _kSilver;
      case 3:
        return _kBronze;
      default:
        return Colors.grey.shade400;
    }
  }

  String get _medalla {
    switch (item.posicion) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '${item.posicion ?? '-'}';
    }
  }

  bool get _tieneMedalla => (item.posicion ?? 0) <= 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface(Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.of(context).border(
            _tieneMedalla
                ? _posColor.withValues(alpha: 0.4)
                : Colors.grey.shade200,
          ),
          width: _tieneMedalla ? 1.5 : 1,
        ),
      ),
      child: RankingEntryLayout(
        leading: Text(
          _medalla,
          style: const TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        title: Text(
          item.empleadoNombre ?? 'Participante',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.sector != null)
              Text(item.sector!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.triviasParticipadas != null)
                  _Tag('${item.triviasParticipadas} jugadas'),
                if ((item.triviasGanadas ?? 0) > 0)
                  _Tag('${item.triviasGanadas} ganadas', highlight: true),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${item.puntosAnuales ?? 0} pts',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.of(
                  context,
                ).foreground(_tieneMedalla ? _posColor : _kPrimary),
              ),
            ),
            if (item.correctasTotales != null)
              Text(
                '${item.correctasTotales} correctas',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? _kGold : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface(color.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.of(context).foreground(
            highlight ? const Color(0xFF7A4800) : Colors.grey.shade600,
          ),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              size: 56,
              color: AppColors.of(context).foreground(Colors.grey.shade300),
            ),
            const SizedBox(height: 12),
            Text(
              'Aún no hay datos para este año.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.of(context).foreground(Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_rounded,
              size: 48,
              color: AppColors.of(context).foreground(Colors.grey.shade400),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.of(context).foreground(Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.of(context).surface(_kPrimary),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
