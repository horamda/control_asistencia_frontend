import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

const _kPrimary = Color(0xFF0E3A5B);
const _kGold = Color(0xFFF5A623);
const _kSilver = Color(0xFF9E9E9E);
const _kBronze = Color(0xFF795548);

class TriviaRankingScreen extends StatefulWidget {
  const TriviaRankingScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.triviaId,
    required this.empleadoDni,
  });

  final MobileApiClient apiClient;
  final String token;
  final int triviaId;
  final String empleadoDni;

  @override
  State<TriviaRankingScreen> createState() => _TriviaRankingScreenState();
}

class _TriviaRankingScreenState extends State<TriviaRankingScreen> {
  TriviaRankingResponse? _ranking;
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
      final r = await widget.apiClient.getRankingTrivia(
        token: widget.token,
        triviaId: widget.triviaId,
      );
      if (!mounted) return;
      setState(() { _ranking = r; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'No se pudo obtener el ranking.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranking = _ranking;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: AppBar(
        title: Text(ranking != null ? 'Ranking: ${ranking.trivia.titulo}' : 'Ranking'),
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
                      if (ranking != null) ...[
                        _TriviaInfoBanner(trivia: ranking.trivia),
                        const SizedBox(height: 12),
                        _ReglasEmpate(),
                        const SizedBox(height: 16),
                        if (ranking.ranking.isEmpty)
                          _EmptyState()
                        else
                          ...ranking.ranking.map(
                            (item) => _RankingTile(
                              item: item,
                              esPropio: item.empleadoId != null &&
                                  widget.empleadoDni.isNotEmpty,
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _TriviaInfoBanner extends StatelessWidget {
  const _TriviaInfoBanner({required this.trivia});
  final TriviaInfo trivia;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, Color(0xFF1A5276)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.leaderboard, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              trivia.titulo,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ]),
          if (trivia.premio != null) ...[
            const SizedBox(height: 8),
            Text('Premio: ${trivia.premio}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _ReglasEmpate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'En caso de empate gana quien tenga menor tiempo. Si el tiempo también coincide, gana quien empezó primero.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.item, required this.esPropio});
  final TriviaRankingItem item;
  final bool esPropio;

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
      default: return '${item.posicion}';
    }
  }

  bool get _tieneMedalla => item.posicion <= 3;

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
        boxShadow: _tieneMedalla
            ? [BoxShadow(color: _posColor.withValues(alpha: 0.15), blurRadius: 6)]
            : [],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: _tieneMedalla
            ? Text(_medalla, style: const TextStyle(fontSize: 26))
            : Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${item.posicion}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
        title: Text(
          item.empleadoNombre ?? 'Participante',
          style: TextStyle(
            fontWeight: item.posicion <= 3 ? FontWeight.w700 : FontWeight.w600,
            color: _kPrimary,
          ),
        ),
        subtitle: Text(
          item.sector ?? '',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.puntosTotal ?? 0} pts',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _tieneMedalla ? _posColor : _kPrimary,
              ),
            ),
            if (item.tiempoTotalSegundos != null)
              Text(
                _fmtTiempo(item.tiempoTotalSegundos),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
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
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.leaderboard_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aún no hay participantes.',
                style: TextStyle(color: Colors.grey.shade500)),
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
            Text(message, textAlign: TextAlign.center,
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

String _fmtTiempo(int? s) {
  if (s == null) return '-';
  final m = s ~/ 60;
  final sec = s % 60;
  return m == 0 ? '${sec}s' : '${m}m ${sec}s';
}
