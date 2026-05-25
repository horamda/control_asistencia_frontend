import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import 'trivia_history_screen.dart';
import 'trivia_my_history_screen.dart';
import 'trivia_play_screen.dart';
import 'trivia_ranking_screen.dart';
import 'trivia_annual_ranking_screen.dart';

// Colores de marca reutilizados en el módulo Trivia
const _kPrimary = Color(0xFF0E3A5B);
const _kAccent = Color(0xFF00B09C);
const _kGold = Color(0xFFF5A623);
const _kBg = Color(0xFFF2F5F8);

class TriviaHomeScreen extends StatefulWidget {
  const TriviaHomeScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.empleadoDni,
    required this.empleadoId,
  });

  final MobileApiClient apiClient;
  final String token;
  final String empleadoDni;
  final int empleadoId;

  @override
  State<TriviaHomeScreen> createState() => _TriviaHomeScreenState();
}

class _TriviaHomeScreenState extends State<TriviaHomeScreen> {
  TriviaEstadoResponse? _estado;
  List<TriviaNotificacion> _notificaciones = [];
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
        widget.apiClient.getTriviaEstado(token: widget.token),
        widget.apiClient.getTriviaNotificaciones(token: widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _estado = results[0] as TriviaEstadoResponse;
        _notificaciones = results[1] as List<TriviaNotificacion>;
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
        _error = 'No se pudo conectar. Verificá tu conexión a internet.';
        _loading = false;
      });
    }
  }

  Future<void> _iniciarJuego() async {
    setState(() => _loading = true);
    try {
      final resp = await widget.apiClient.iniciarTrivia(token: widget.token);
      if (!mounted) return;
      setState(() => _loading = false);

      if (resp.preguntas.isEmpty) {
        _showError('No hay preguntas disponibles en este momento.');
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TriviaPlayScreen(
            apiClient: widget.apiClient,
            token: widget.token,
            triviaId: resp.triviaId,
            titulo: resp.titulo ?? 'Trivia',
            preguntas: resp.preguntas,
            empleadoDni: widget.empleadoDni,
          ),
        ),
      );
      unawaited(_load());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final code = e.statusCode;
      if (code == 409) {
        _showError('Ya participaste en esta trivia.');
        unawaited(_load());
      } else {
        _showError(e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Error al iniciar la trivia. Intentá nuevamente.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _openRanking(int triviaId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TriviaRankingScreen(
        apiClient: widget.apiClient,
        token: widget.token,
        triviaId: triviaId,
        empleadoDni: widget.empleadoDni,
      ),
    ));
  }

  void _openHistorial() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TriviaHistoryScreen(
        apiClient: widget.apiClient,
        token: widget.token,
        empleadoDni: widget.empleadoDni,
      ),
    ));
  }

  void _openMiHistorial() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TriviaMyHistoryScreen(
        apiClient: widget.apiClient,
        token: widget.token,
      ),
    ));
  }

  void _openRankingAnual() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TriviaAnnualRankingScreen(
        apiClient: widget.apiClient,
        token: widget.token,
        anio: DateTime.now().year,
        empleadoDni: widget.empleadoDni,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Trivia'),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Actualizar',
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
                      if (_notificaciones.isNotEmpty) ...[
                        _NotificacionBanner(notificaciones: _notificaciones),
                        const SizedBox(height: 12),
                      ],
                      _buildBody(),
                      const SizedBox(height: 24),
                      _SeccionAccesos(
                        onHistorial: _openHistorial,
                        onMiHistorial: _openMiHistorial,
                        onRankingAnual: _openRankingAnual,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBody() {
    final estado = _estado;
    if (estado == null) return const SizedBox.shrink();

    if (!estado.hayTriviaActiva) {
      return _SinTriviaCard(
        onHistorial: _openHistorial,
        onRankingAnual: _openRankingAnual,
      );
    }

    final trivia = estado.trivia!;
    final estadoTrivia = trivia.estado;

    if (estadoTrivia == 'programada') {
      return _ProgramadaCard(trivia: trivia);
    }

    if (estadoTrivia == 'activa') {
      if (estado.yaParticipo) {
        return _YaParticipoCard(
          trivia: trivia,
          participacion: estado.participacion,
          onRanking: () => _openRanking(trivia.id),
          onMiHistorial: _openMiHistorial,
        );
      }
      return _ActivaCard(
        trivia: trivia,
        onJugar: _iniciarJuego,
      );
    }

    if (estadoTrivia == 'finalizada') {
      return _FinalizadaCard(
        trivia: trivia,
        participacion: estado.participacion,
        onRanking: () => _openRanking(trivia.id),
        onHistorial: _openHistorial,
      );
    }

    return _SinTriviaCard(
      onHistorial: _openHistorial,
      onRankingAnual: _openRankingAnual,
    );
  }
}

// ─── Tarjetas de estado ───────────────────────────────────────────────────────

class _ProgramadaCard extends StatelessWidget {
  const _ProgramadaCard({required this.trivia});
  final TriviaInfo trivia;

  @override
  Widget build(BuildContext context) {
    return _TriviaCard(
      icon: Icons.schedule_outlined,
      iconColor: const Color(0xFF315D52),
      badge: 'Próxima trivia',
      badgeColor: const Color(0xFF315D52),
      title: trivia.titulo,
      description: trivia.descripcion,
      children: [
        if (trivia.fechaInicio != null)
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            text: 'Disponible desde: ${_fmtFecha(trivia.fechaInicio)}',
          ),
        if (trivia.fechaFin != null)
          _InfoRow(
            icon: Icons.flag_outlined,
            text: 'Finaliza: ${_fmtFecha(trivia.fechaFin)}',
          ),
        if (trivia.premio != null)
          _InfoRow(icon: Icons.card_giftcard_outlined, text: 'Premio: ${trivia.premio}'),
        const SizedBox(height: 12),
        Text(
          'La trivia estará disponible desde el día y hora indicado.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ActivaCard extends StatelessWidget {
  const _ActivaCard({required this.trivia, required this.onJugar});
  final TriviaInfo trivia;
  final VoidCallback onJugar;

  @override
  Widget build(BuildContext context) {
    return _TriviaCard(
      icon: Icons.quiz_outlined,
      iconColor: _kAccent,
      badge: 'Trivia disponible',
      badgeColor: _kAccent,
      title: trivia.titulo,
      description: trivia.descripcion,
      children: [
        if (trivia.premio != null)
          _InfoRow(icon: Icons.card_giftcard_outlined, text: 'Premio: ${trivia.premio}'),
        if (trivia.fechaFin != null)
          _InfoRow(
            icon: Icons.timer_outlined,
            text: 'Cierra: ${_fmtFecha(trivia.fechaFin)}',
          ),
        const SizedBox(height: 16),
        Text(
          'Demostra tu conocimiento operativo y suma puntos para el ranking anual.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text('Jugar ahora', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            onPressed: onJugar,
          ),
        ),
      ],
    );
  }
}

class _YaParticipoCard extends StatelessWidget {
  const _YaParticipoCard({
    required this.trivia,
    required this.participacion,
    required this.onRanking,
    required this.onMiHistorial,
  });
  final TriviaInfo trivia;
  final TriviaParticipacion? participacion;
  final VoidCallback onRanking;
  final VoidCallback onMiHistorial;

  @override
  Widget build(BuildContext context) {
    final p = participacion;
    return _TriviaCard(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF2A789E),
      badge: 'Ya participaste',
      badgeColor: const Color(0xFF2A789E),
      title: trivia.titulo,
      description: null,
      children: [
        if (p != null) ...[
          _StatRow(label: 'Puntaje', value: '${p.puntosTotal ?? 0} pts'),
          if (p.posicion != null)
            _StatRow(label: 'Posición actual', value: '#${p.posicion}'),
          _StatRow(label: 'Correctas', value: '${p.correctas ?? 0}'),
          _StatRow(label: 'Incorrectas', value: '${p.incorrectas ?? 0}'),
          if (p.tiempoTotalSegundos != null)
            _StatRow(label: 'Tiempo total', value: _fmtTiempo(p.tiempoTotalSegundos)),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('Mi historial'),
              onPressed: onMiHistorial,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              icon: const Icon(Icons.leaderboard),
              label: const Text('Ver ranking'),
              onPressed: onRanking,
            ),
          ),
        ]),
      ],
    );
  }
}

class _FinalizadaCard extends StatelessWidget {
  const _FinalizadaCard({
    required this.trivia,
    required this.participacion,
    required this.onRanking,
    required this.onHistorial,
  });
  final TriviaInfo trivia;
  final TriviaParticipacion? participacion;
  final VoidCallback onRanking;
  final VoidCallback onHistorial;

  @override
  Widget build(BuildContext context) {
    final p = participacion;
    return _TriviaCard(
      icon: Icons.emoji_events_outlined,
      iconColor: _kGold,
      badge: 'Trivia finalizada',
      badgeColor: Colors.grey.shade600,
      title: trivia.titulo,
      description: null,
      children: [
        if (p != null) ...[
          _StatRow(label: 'Tu puntaje', value: '${p.puntosTotal ?? 0} pts'),
          if (p.posicion != null) _StatRow(label: 'Tu posición', value: '#${p.posicion}'),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('Historial'),
              onPressed: onHistorial,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              icon: const Icon(Icons.leaderboard),
              label: const Text('Ver ranking'),
              onPressed: onRanking,
            ),
          ),
        ]),
      ],
    );
  }
}

class _SinTriviaCard extends StatelessWidget {
  const _SinTriviaCard({required this.onHistorial, required this.onRankingAnual});
  final VoidCallback onHistorial;
  final VoidCallback onRankingAnual;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.quiz_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay trivias activas por el momento',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onHistorial,
                  child: const Text('Ver historial'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                  onPressed: onRankingAnual,
                  child: const Text('Ranking anual'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets internos ─────────────────────────────────────────────────────────

class _TriviaCard extends StatelessWidget {
  const _TriviaCard({
    required this.icon,
    required this.iconColor,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String badge;
  final Color badgeColor;
  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 12),
              Text(description!, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kPrimary),
          ),
        ],
      ),
    );
  }
}

class _SeccionAccesos extends StatelessWidget {
  const _SeccionAccesos({
    required this.onHistorial,
    required this.onMiHistorial,
    required this.onRankingAnual,
  });
  final VoidCallback onHistorial;
  final VoidCallback onMiHistorial;
  final VoidCallback onRankingAnual;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explorar',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _AccesoChip(icon: Icons.history_outlined, label: 'Historial', onTap: onHistorial),
          const SizedBox(width: 10),
          _AccesoChip(icon: Icons.person_outlined, label: 'Mi historial', onTap: onMiHistorial),
          const SizedBox(width: 10),
          _AccesoChip(icon: Icons.emoji_events_outlined, label: 'Ranking anual', onTap: onRankingAnual),
        ]),
      ],
    );
  }
}

class _AccesoChip extends StatelessWidget {
  const _AccesoChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: _kPrimary),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kPrimary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificacionBanner extends StatelessWidget {
  const _NotificacionBanner({required this.notificaciones});
  final List<TriviaNotificacion> notificaciones;

  @override
  Widget build(BuildContext context) {
    final notif = notificaciones.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Color(0xFFC47500)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notif.mensaje ?? 'Todavía no participaste. La trivia finaliza pronto.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF7A4800)),
            ),
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
            Icon(Icons.wifi_off_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
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

// ─── Helpers de formato ───────────────────────────────────────────────────────

String _fmtFecha(String? iso) {
  if (iso == null) return '-';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  } catch (_) {
    return iso;
  }
}

String _fmtTiempo(int? segundos) {
  if (segundos == null) return '-';
  final m = segundos ~/ 60;
  final s = segundos % 60;
  if (m == 0) return '${s}s';
  return '${m}m ${s}s';
}
