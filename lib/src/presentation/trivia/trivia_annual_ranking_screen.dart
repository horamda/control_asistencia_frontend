import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

const _kPrimary = Color(0xFF0E3A5B);
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

class _TriviaAnnualRankingScreenState
    extends State<TriviaAnnualRankingScreen> {
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
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.apiClient.getRankingAnual(token: widget.token, anio: widget.anio),
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
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'No se pudo obtener el ranking anual.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranking = _ranking;
    final items = ranking?.items ?? [];
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: AppBar(
        title: Text('Ranking Anual ${widget.anio}'),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
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
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...items.map((item) => _AnualRankingTile(item: item)),
                      ],
                      const SizedBox(height: 16),
                    ],
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
        gradient: const LinearGradient(colors: [_kPrimary, Color(0xFF1A5276)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ranking Anual',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                'Trivia $anio',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
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
        color: _kGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          const Text('👑🏆', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const Text(
            'GANADOR DEL AÑO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7A4800),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ganador.empleadoNombre ?? 'Campeón',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7A4800),
            ),
            textAlign: TextAlign.center,
          ),
          if (ganador.sector != null)
            Text(
              ganador.sector!,
              style: TextStyle(fontSize: 13, color: Colors.brown.shade400),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (ganador.puntosAnuales != null)
                _Chip(label: '${ganador.puntosAnuales} pts'),
              const SizedBox(width: 10),
              if (ganador.triviasGanadas != null)
                _Chip(label: '${ganador.triviasGanadas} ganadas'),
              const SizedBox(width: 10),
              if (ganador.triviasParticipadas != null)
                _Chip(label: '${ganador.triviasParticipadas} jugadas'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Fuiste el mejor participante anual de la Trivia. Tu compromiso con la mejora continua es un ejemplo para todos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.brown.shade600,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text('👏 ¡Excelente trabajo!',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A4800))),
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
        color: _kGold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGold.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7A4800),
        ),
      ),
    );
  }
}

class _AnualRankingTile extends StatelessWidget {
  const _AnualRankingTile({required this.item});
  final TriviaRankingAnualItem item;

  Color get _posColor {
    switch (item.posicion) {
      case 1: return _kGold;
      case 2: return _kSilver;
      case 3: return _kBronze;
      default: return Colors.grey.shade400;
    }
  }

  String get _medalla {
    switch (item.posicion) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '${item.posicion ?? '-'}';
    }
  }

  bool get _tieneMedalla => (item.posicion ?? 0) <= 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _tieneMedalla ? _posColor.withValues(alpha: 0.4) : Colors.grey.shade200,
          width: _tieneMedalla ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: _tieneMedalla
                  ? Text(_medalla, style: const TextStyle(fontSize: 24))
                  : Center(
                      child: Text(
                        '${item.posicion ?? '-'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.empleadoNombre ?? 'Participante',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _kPrimary,
                      fontSize: 14,
                    ),
                  ),
                  if (item.sector != null)
                    Text(
                      item.sector!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.triviasParticipadas != null)
                        _Tag('${item.triviasParticipadas} jugadas'),
                      if (item.triviasGanadas != null && item.triviasGanadas! > 0) ...[
                        const SizedBox(width: 6),
                        _Tag('${item.triviasGanadas} ganadas', highlight: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.puntosAnuales ?? 0} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _tieneMedalla ? _posColor : _kPrimary,
                  ),
                ),
                if (item.correctasTotales != null)
                  Text(
                    '${item.correctasTotales} correctas',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: highlight ? const Color(0xFF7A4800) : Colors.grey.shade600,
        ),
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
          children: [
            Icon(Icons.emoji_events_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Aún no hay datos para este año.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
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
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
