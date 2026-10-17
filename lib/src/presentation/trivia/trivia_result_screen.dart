import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import 'trivia_play_screen.dart';
import 'trivia_ranking_screen.dart';

const _kPrimary = AppPalette.navy;
const _kAccent = AppPalette.blueLight;

class TriviaResultScreen extends StatefulWidget {
  const TriviaResultScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.triviaId,
    required this.resultado,
    required this.empleadoDni,
  });

  final MobileApiClient apiClient;
  final String token;
  final int triviaId;
  final TriviaFinalizarResponse resultado;
  final String empleadoDni;

  @override
  State<TriviaResultScreen> createState() => _TriviaResultScreenState();
}

class _TriviaResultScreenState extends State<TriviaResultScreen> {
  bool _iniciandoSiguiente = false;

  Future<void> _iniciarSiguiente(TriviaSiguiente siguiente) async {
    if (_iniciandoSiguiente) return;
    setState(() => _iniciandoSiguiente = true);
    try {
      final resp = await widget.apiClient.iniciarTrivia(token: widget.token);
      if (!mounted) return;
      setState(() => _iniciandoSiguiente = false);

      if (resp.preguntas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay preguntas disponibles en este momento.',
              textAlign: TextAlign.center,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TriviaPlayScreen(
            apiClient: widget.apiClient,
            token: widget.token,
            triviaId: resp.triviaId,
            titulo: resp.titulo ?? siguiente.titulo,
            preguntas: resp.preguntas,
            empleadoDni: widget.empleadoDni,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _iniciandoSiguiente = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _iniciandoSiguiente = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error al iniciar la siguiente trivia. Intentá nuevamente.',
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultado = widget.resultado;
    final pts = resultado.puntosTotal ?? 0;
    final correctas = resultado.correctas ?? 0;
    final incorrectas = resultado.incorrectas ?? 0;
    final posicion = resultado.posicion;
    final tiempo = resultado.tiempoTotalSegundos;
    final siguiente = resultado.siguienteTriviaDisponible;

    return Scaffold(
      backgroundColor: AppColors.of(context).surface(AppPalette.background),
      appBar: AppBar(
        title: const Text('Resultado', textAlign: TextAlign.center),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Tarjeta principal ───────────────────────────────────────────
          AppCard(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.of(
                        context,
                      ).surface(_kAccent.withValues(alpha: 0.1)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: AppColors.of(context).foreground(_kAccent),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Participación completada!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.of(context).foreground(_kPrimary),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¡Gracias por participar! Sumaste puntos para el ranking anual. Seguí demostrando tu conocimiento operativo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.of(
                        context,
                      ).foreground(Colors.grey.shade600),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats ───────────────────────────────────────────────────────
          AppCard(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (resultado.fueraRanking)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Participación sin ranking',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Text(
                    'Tu resultado',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.of(context).foreground(_kPrimary),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, box) {
                      final stacked =
                          box.maxWidth < 420 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3;
                      final tileWidth = stacked
                          ? box.maxWidth
                          : (box.maxWidth - 24) / 3;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            width: tileWidth,
                            child: _StatTile(
                              label: 'Puntaje',
                              value: '$pts pts',
                              icon: Icons.star_rounded,
                              color: const Color(0xFFF5A623),
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _StatTile(
                              label: 'Correctas',
                              value: '$correctas',
                              icon: Icons.check_circle_rounded,
                              color: _kAccent,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _StatTile(
                              label: 'Incorrectas',
                              value: '$incorrectas',
                              icon: Icons.cancel_rounded,
                              color: const Color(0xFFC85F0F),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (tiempo != null || posicion != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.center,
                      children: [
                        if (tiempo != null) ...[
                          Icon(
                            Icons.timer_rounded,
                            size: 16,
                            color: AppColors.of(
                              context,
                            ).foreground(Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tiempo: ${_fmtTiempo(tiempo)}',
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(width: 20),
                        ],
                        if (posicion != null) ...[
                          Icon(
                            Icons.leaderboard_rounded,
                            size: 16,
                            color: AppColors.of(
                              context,
                            ).foreground(Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Posición: #$posicion',
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Siguiente trivia disponible ─────────────────────────────────
          if (siguiente != null) ...[
            AppCard(
              elevation: 1,
              color: AppColors.of(
                context,
              ).surface(_kAccent.withValues(alpha: 0.06)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.of(
                    context,
                  ).border(_kAccent.withValues(alpha: 0.3)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.of(
                          context,
                        ).surface(_kAccent.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.quiz_rounded,
                        color: AppColors.of(context).foreground(_kAccent),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Siguiente trivia disponible',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.of(context).foreground(_kAccent),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            siguiente.titulo,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.of(
                                context,
                              ).foreground(_kPrimary),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 8),

          // ── Botones ─────────────────────────────────────────────────────
          if (siguiente != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.of(context).surface(_kAccent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _iniciandoSiguiente
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 24),
                label: Text(
                  _iniciandoSiguiente
                      ? 'Cargando...'
                      : 'Jugar siguiente trivia',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                onPressed: _iniciandoSiguiente
                    ? null
                    : () => _iniciarSiguiente(siguiente),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.of(context).surface(_kPrimary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.leaderboard_rounded),
            label: const Text(
              'Ver ranking',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TriviaRankingScreen(
                    apiClient: widget.apiClient,
                    token: widget.token,
                    triviaId: widget.triviaId,
                    empleadoDni: widget.empleadoDni,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.home_rounded),
            label: const Text(
              'Volver al inicio',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            onPressed: () {
              int count = 0;
              Navigator.of(context).popUntil((_) => count++ >= 2);
            },
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface(color.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.of(context).foreground(color), size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.of(context).foreground(color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.of(context).foreground(Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtTiempo(int? segundos) {
  if (segundos == null) return '-';
  final m = segundos ~/ 60;
  final s = segundos % 60;
  if (m == 0) return '${s}s';
  return '${m}m ${s}s';
}
