import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import '../theme/app_palette.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import 'trivia_ranking_screen.dart';

const _kPrimary = AppPalette.navy;
const _kGold = Color(0xFFF5A623);

class TriviaHistoryScreen extends StatefulWidget {
  const TriviaHistoryScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.empleadoDni,
  });

  final MobileApiClient apiClient;
  final String token;
  final String empleadoDni;

  @override
  State<TriviaHistoryScreen> createState() => _TriviaHistoryScreenState();
}

class _TriviaHistoryScreenState extends State<TriviaHistoryScreen> {
  TriviaHistorialResponse? _historial;
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
      final r = await widget.apiClient.getHistorialTrivia(token: widget.token);
      if (!mounted) return;
      setState(() {
        _historial = r;
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
        _error = 'No se pudo obtener el historial.';
        _loading = false;
      });
    }
  }

  void _openRanking(int triviaId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TriviaRankingScreen(
          apiClient: widget.apiClient,
          token: widget.token,
          triviaId: triviaId,
          empleadoDni: widget.empleadoDni,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _historial?.items ?? [];
    return Scaffold(
      backgroundColor: AppColors.of(context).surface(AppPalette.background),
      appBar: AppBar(
        title: const Text('Historial de Trivias', textAlign: TextAlign.center),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : items.isEmpty
          ? _EmptyState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _HistorialTile(
                  item: items[i],
                  onRanking: () => _openRanking(items[i].id),
                ),
              ),
            ),
    );
  }
}

class _HistorialTile extends StatelessWidget {
  const _HistorialTile({required this.item, required this.onRanking});
  final TriviaHistorialItem item;
  final VoidCallback onRanking;

  @override
  Widget build(BuildContext context) {
    final ganador = item.ganadorNombre;
    return AppCard(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.quiz_rounded,
                  size: 18,
                  color: AppColors.of(context).foreground(_kPrimary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.titulo ?? 'Trivia',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.of(context).foreground(_kPrimary),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.fechaInicio != null)
              _InfoChip(text: 'Inicio: ${_fmtFecha(item.fechaInicio)}'),
            if (item.fechaFin != null)
              _InfoChip(text: 'Fin: ${_fmtFecha(item.fechaFin)}'),
            if (item.premio != null)
              _InfoChip(
                text: 'Premio: ${item.premio}',
                icon: Icons.card_giftcard_rounded,
              ),
            if (ganador != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.of(
                    context,
                  ).surface(_kGold.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.of(
                      context,
                    ).border(_kGold.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '🏆',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Ganador',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.of(
                                context,
                              ).foreground(const Color(0xFF7A4800)),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            ganador,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.of(
                                context,
                              ).foreground(const Color(0xFF7A4800)),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (item.ganadorPuntos != null)
                            Text(
                              '${item.ganadorPuntos} pts',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.of(
                                  context,
                                ).foreground(const Color(0xFF7A4800)),
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.leaderboard_rounded, size: 18),
                label: const Text('Ver ranking', textAlign: TextAlign.center),
                onPressed: onRanking,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.calendar_today_rounded,
            size: 13,
            color: AppColors.of(context).foreground(Colors.grey.shade500),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.of(context).foreground(Colors.grey.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 56,
            color: AppColors.of(context).foreground(Colors.grey.shade300),
          ),
          const SizedBox(height: 12),
          Text(
            'No hay trivias finalizadas aún.',
            style: TextStyle(
              color: AppColors.of(context).foreground(Colors.grey.shade500),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

String _fmtFecha(String? iso) {
  if (iso == null) return '-';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  } catch (_) {
    return iso;
  }
}
