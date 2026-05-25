import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

const _kPrimary = Color(0xFF0E3A5B);
const _kAccent = Color(0xFF00B09C);
const _kGold = Color(0xFFF5A623);

class TriviaMyHistoryScreen extends StatefulWidget {
  const TriviaMyHistoryScreen({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<TriviaMyHistoryScreen> createState() => _TriviaMyHistoryScreenState();
}

class _TriviaMyHistoryScreenState extends State<TriviaMyHistoryScreen> {
  List<TriviaMyHistorialItem> _items = [];
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
      final r = await widget.apiClient.getMiHistorialTrivia(token: widget.token);
      if (!mounted) return;
      setState(() { _items = r; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'No se pudo obtener tu historial.'; _loading = false; });
    }
  }

  // Resumen calculado desde los datos devueltos por el backend
  int get _puntosAcumulados =>
      _items.fold(0, (sum, i) => sum + (i.puntosTotal ?? 0));
  int get _triviasJugadas => _items.length;
  int get _triviasGanadas => _items.where((i) => i.esGanador).length;
  int? get _mejorPosicion {
    final posiciones = _items
        .where((i) => i.posicion != null)
        .map((i) => i.posicion!)
        .toList();
    if (posiciones.isEmpty) return null;
    return posiciones.reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: AppBar(
        title: const Text('Mi Historial'),
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
                      if (_items.isNotEmpty) ...[
                        _ResumenCard(
                          puntosAcumulados: _puntosAcumulados,
                          triviasJugadas: _triviasJugadas,
                          triviasGanadas: _triviasGanadas,
                          mejorPosicion: _mejorPosicion,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Participaciones',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._items.map((item) => _MyHistorialTile(item: item)),
                      ] else
                        _EmptyState(),
                    ],
                  ),
                ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.puntosAcumulados,
    required this.triviasJugadas,
    required this.triviasGanadas,
    required this.mejorPosicion,
  });

  final int puntosAcumulados;
  final int triviasJugadas;
  final int triviasGanadas;
  final int? mejorPosicion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kPrimary, Color(0xFF1A5276)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'Mi resumen',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '$puntosAcumulados pts',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text('puntos acumulados',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ResumenStat(label: 'Jugadas', value: '$triviasJugadas'),
              _ResumenStat(label: 'Ganadas', value: '$triviasGanadas', highlight: triviasGanadas > 0),
              _ResumenStat(
                label: 'Mejor pos.',
                value: mejorPosicion != null ? '#$mejorPosicion' : '-',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumenStat extends StatelessWidget {
  const _ResumenStat({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: highlight ? _kGold : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

class _MyHistorialTile extends StatelessWidget {
  const _MyHistorialTile({required this.item});
  final TriviaMyHistorialItem item;

  @override
  Widget build(BuildContext context) {
    final esGanador = item.esGanador;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esGanador ? _kGold.withValues(alpha: 0.5) : Colors.grey.shade200,
          width: esGanador ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (esGanador) ...[
                  const Text('🏆', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    item.titulo ?? 'Trivia',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _kPrimary,
                    ),
                  ),
                ),
                if (item.posicion != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#${item.posicion}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _kPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniStat(
                  label: 'Puntos',
                  value: '${item.puntosTotal ?? 0}',
                  color: _kAccent,
                ),
                const SizedBox(width: 10),
                _MiniStat(
                  label: 'Correctas',
                  value: '${item.correctas ?? 0}',
                  color: const Color(0xFF2A789E),
                ),
                const SizedBox(width: 10),
                _MiniStat(
                  label: 'Incorrectas',
                  value: '${item.incorrectas ?? 0}',
                  color: const Color(0xFFC85F0F),
                ),
                const SizedBox(width: 10),
                _MiniStat(
                  label: 'Tiempo',
                  value: _fmtTiempo(item.tiempoTotalSegundos),
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            if (item.fechaFinalizacion != null) ...[
              const SizedBox(height: 8),
              Text(
                'Participaste el ${_fmtFechaCorta(item.fechaFinalizacion)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
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
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.person_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Todavía no participaste en ninguna trivia.',
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

String _fmtTiempo(int? s) {
  if (s == null) return '-';
  final m = s ~/ 60;
  final sec = s % 60;
  return m == 0 ? '${sec}s' : '${m}m ${sec}s';
}

String _fmtFechaCorta(String? iso) {
  if (iso == null) return '-';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year}';
  } catch (_) {
    return iso;
  }
}
