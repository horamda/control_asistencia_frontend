import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({
    super.key,
    required this.title,
    this.requiresPhoto = false,
  });

  final String title;
  final bool requiresPhoto;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }
      _handled = true;
      setState(() {
        _detected = true;
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) {
          return;
        }
        try {
          Navigator.of(context).pop(value);
        } catch (_) {
          if (mounted) {
            setState(() {
              _handled = false;
              _detected = false;
            });
          }
        }
      });
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final instructionText = widget.requiresPhoto
        ? 'Apuntá al QR del punto de control.\nLuego tomá una foto de verificación.'
        : 'Apunta al QR del punto de control para fichar.';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camara ──────────────────────────────────────────────────────
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // ── Visor con overlay oscuro + brackets + línea animada ──────────
          _ScannerViewfinderOverlay(detected: _detected),

          // ── Instrucción en la parte superior ────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _detected
                        ? _DetectedBadge(key: const ValueKey('detected'))
                        : _InstructionBadge(
                            key: const ValueKey('instruction'),
                            text: instructionText,
                            requiresPhoto: widget.requiresPhoto,
                          ),
                  ),
                ),
              ),
            ),
          ),

          // ── Botón cancelar (solo antes de detectar) ──────────────────────
          if (!_detected)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 20),
                        label: const Text('Cancelar'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Overlay del visor ──────────────────────────────────────────────────────────

class _ScannerViewfinderOverlay extends StatefulWidget {
  const _ScannerViewfinderOverlay({required this.detected});

  final bool detected;

  @override
  State<_ScannerViewfinderOverlay> createState() =>
      _ScannerViewfinderOverlayState();
}

class _ScannerViewfinderOverlayState extends State<_ScannerViewfinderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scanLine;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scanLine = Tween<double>(begin: 0.06, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scanLine,
      builder: (_, __) => CustomPaint(
        painter: _ViewfinderPainter(
          detected: widget.detected,
          scanProgress: _scanLine.value,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({
    required this.detected,
    required this.scanProgress,
  });

  final bool detected;
  final double scanProgress;

  static const double _bracketLen = 28.0;
  static const double _bracketStroke = 3.5;
  static const double _boxFraction = 0.70; // porcentaje del lado corto

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * _boxFraction;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final l = cx - side / 2;
    final t = cy - side / 2;
    final r = cx + side / 2;
    final b = cy + side / 2;

    // ── Overlay oscuro fuera del cuadro ────────────────────────────────
    final overlayColor = detected
        ? Colors.black.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.55);
    final overlayPaint = Paint()..color = overlayColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, t), overlayPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, b, size.width, size.height - b), overlayPaint);
    canvas.drawRect(Rect.fromLTWH(0, t, l, side), overlayPaint);
    canvas.drawRect(Rect.fromLTWH(r, t, size.width - r, side), overlayPaint);

    if (detected) {
      // ── Borde verde de éxito ──────────────────────────────────────────
      final successPaint = Paint()
        ..color = Colors.greenAccent.shade400
        ..strokeWidth = _bracketStroke + 0.5
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(l, t, r, b),
          const Radius.circular(6),
        ),
        successPaint,
      );
    } else {
      // ── Brackets en las esquinas ──────────────────────────────────────
      final bp = Paint()
        ..color = Colors.white
        ..strokeWidth = _bracketStroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Top-left
      canvas.drawLine(Offset(l, t), Offset(l + _bracketLen, t), bp);
      canvas.drawLine(Offset(l, t), Offset(l, t + _bracketLen), bp);
      // Top-right
      canvas.drawLine(Offset(r, t), Offset(r - _bracketLen, t), bp);
      canvas.drawLine(Offset(r, t), Offset(r, t + _bracketLen), bp);
      // Bottom-left
      canvas.drawLine(Offset(l, b), Offset(l + _bracketLen, b), bp);
      canvas.drawLine(Offset(l, b), Offset(l, b - _bracketLen), bp);
      // Bottom-right
      canvas.drawLine(Offset(r, b), Offset(r - _bracketLen, b), bp);
      canvas.drawLine(Offset(r, b), Offset(r, b - _bracketLen), bp);

      // ── Línea de escaneo animada ──────────────────────────────────────
      final scanY = t + side * scanProgress;
      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.cyanAccent.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(l, scanY - 1, side, 2))
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(l + 12, scanY),
        Offset(r - 12, scanY),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      old.detected != detected || old.scanProgress != scanProgress;
}

// ── Badge de instrucción ───────────────────────────────────────────────────────

class _InstructionBadge extends StatelessWidget {
  const _InstructionBadge({
    super.key,
    required this.text,
    required this.requiresPhoto,
  });

  final String text;
  final bool requiresPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_scanner, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          if (requiresPhoto) ...[
            const SizedBox(width: 10),
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 16),
          ],
        ],
      ),
    );
  }
}

// ── Badge de detección exitosa ─────────────────────────────────────────────────

class _DetectedBadge extends StatelessWidget {
  const _DetectedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text(
            'QR detectado — procesando...',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
