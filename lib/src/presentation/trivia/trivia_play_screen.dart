import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import 'trivia_result_screen.dart';

const _kPrimary = Color(0xFF0E3A5B);
const _kAccent = Color(0xFF00B09C);

class TriviaPlayScreen extends StatefulWidget {
  const TriviaPlayScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.triviaId,
    required this.titulo,
    required this.preguntas,
    required this.empleadoDni,
  });

  final MobileApiClient apiClient;
  final String token;
  final int triviaId;
  final String titulo;
  final List<TriviaQuestion> preguntas;
  final String empleadoDni;

  @override
  State<TriviaPlayScreen> createState() => _TriviaPlayScreenState();
}

class _TriviaPlayScreenState extends State<TriviaPlayScreen> {
  int _currentIndex = 0;
  // Mapa pregunta_id → (respuesta seleccionada, tiempo inicio)
  final Map<int, String> _respuestas = {};
  final Map<int, DateTime> _tiemposInicio = {};
  final Map<int, int> _tiemposRespuesta = {};

  String? _seleccionActual;
  bool _enviando = false;

  TriviaQuestion get _preguntaActual => widget.preguntas[_currentIndex];
  bool get _esUltima => _currentIndex == widget.preguntas.length - 1;

  @override
  void initState() {
    super.initState();
    _tiemposInicio[_preguntaActual.id] = DateTime.now();
  }

  void _seleccionarOpcion(String opcion) {
    if (_enviando) return;
    setState(() => _seleccionActual = opcion);
  }

  void _siguiente() {
    if (_seleccionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccioná una opción antes de continuar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final pregId = _preguntaActual.id;
    final inicio = _tiemposInicio[pregId];
    final tiempoSegundos = inicio != null
        ? DateTime.now().difference(inicio).inSeconds
        : null;

    _respuestas[pregId] = _seleccionActual!;
    if (tiempoSegundos != null) _tiemposRespuesta[pregId] = tiempoSegundos;

    if (_esUltima) {
      unawaited(_finalizar());
      return;
    }

    setState(() {
      _currentIndex++;
      _seleccionActual = null;
      _tiemposInicio[_preguntaActual.id] = DateTime.now();
    });
  }

  Future<void> _finalizar() async {
    if (_enviando) return;
    setState(() => _enviando = true);

    final respuestasEnvio = _respuestas.entries.map((e) {
      return TriviaRespuestaEnvio(
        preguntaId: e.key,
        respuesta: e.value,
        tiempoRespuestaSegundos: _tiemposRespuesta[e.key],
      );
    }).toList();

    try {
      final resultado = await widget.apiClient.finalizarTrivia(
        token: widget.token,
        triviaId: widget.triviaId,
        respuestas: respuestasEnvio,
      );
      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TriviaResultScreen(
            apiClient: widget.apiClient,
            token: widget.token,
            triviaId: widget.triviaId,
            resultado: resultado,
            empleadoDni: widget.empleadoDni,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      final code = e.statusCode;
      if (code == 409) {
        // Ya participó — redirigir al resultado/home
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (code == 410) {
        _showError('La trivia ya finalizó.');
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _showError('Error al enviar respuestas. Intentá nuevamente.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _onWillPop() async {
    if (_enviando) return false;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir de la trivia'),
        content: const Text('Si salís ahora, tu participación quedará en curso. ¿Querés salir igual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Quedarme'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return salir == true;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.preguntas.length;
    final progreso = (_currentIndex + 1) / total;
    final pregunta = _preguntaActual;

    return PopScope(
      canPop: !_enviando,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F8),
        appBar: AppBar(
          title: Text(widget.titulo),
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          leading: _enviando
              ? const SizedBox.shrink()
              : BackButton(onPressed: () async {
                  final salir = await _onWillPop();
                  if (salir && context.mounted) Navigator.of(context).pop();
                }),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // ── Header de progreso ───────────────────────────────────
                Container(
                  color: _kPrimary,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pregunta ${_currentIndex + 1} de $total',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            '${(progreso * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progreso,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(_kAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Pregunta y opciones ──────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            pregunta.texto,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _kPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _OpcionButton(
                        letra: 'A',
                        texto: pregunta.opcionA,
                        seleccionada: _seleccionActual == 'A',
                        onTap: () => _seleccionarOpcion('A'),
                      ),
                      const SizedBox(height: 10),
                      _OpcionButton(
                        letra: 'B',
                        texto: pregunta.opcionB,
                        seleccionada: _seleccionActual == 'B',
                        onTap: () => _seleccionarOpcion('B'),
                      ),
                      const SizedBox(height: 10),
                      _OpcionButton(
                        letra: 'C',
                        texto: pregunta.opcionC,
                        seleccionada: _seleccionActual == 'C',
                        onTap: () => _seleccionarOpcion('C'),
                      ),
                      const SizedBox(height: 10),
                      _OpcionButton(
                        letra: 'D',
                        texto: pregunta.opcionD,
                        seleccionada: _seleccionActual == 'D',
                        onTap: () => _seleccionarOpcion('D'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                // ── Botón siguiente / finalizar ──────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _esUltima ? const Color(0xFF2A789E) : _kAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _enviando ? null : _siguiente,
                      child: Text(
                        _esUltima ? 'Finalizar trivia' : 'Siguiente pregunta',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── Overlay de envío ─────────────────────────────────────────
            if (_enviando)
              const _EnviandoOverlay(),
          ],
        ),
      ),
    );
  }
}

class _OpcionButton extends StatelessWidget {
  const _OpcionButton({
    required this.letra,
    required this.texto,
    required this.seleccionada,
    required this.onTap,
  });

  final String letra;
  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: seleccionada ? _kPrimary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: seleccionada ? _kPrimary : Colors.grey.shade300,
          width: seleccionada ? 2 : 1,
        ),
        boxShadow: seleccionada
            ? [BoxShadow(color: _kPrimary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
            : [],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seleccionada ? Colors.white : _kPrimary.withValues(alpha: 0.08),
                ),
                child: Center(
                  child: Text(
                    letra,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: seleccionada ? _kPrimary : _kPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: seleccionada ? FontWeight.w600 : FontWeight.normal,
                    color: seleccionada ? Colors.white : Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnviandoOverlay extends StatelessWidget {
  const _EnviandoOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black45),
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _kAccent),
                SizedBox(height: 20),
                Text(
                  'Enviando respuestas...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'Por favor espera',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
