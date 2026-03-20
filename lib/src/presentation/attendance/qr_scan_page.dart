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
      Future.delayed(const Duration(milliseconds: 200), () {
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
        ? 'Apunta la camara al QR para fichar.\nLuego deberas tomar una foto de verificacion.'
        : 'Apunta la camara al QR para fichar.';

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 600 ? 12.0 : 20.0;
          final topPadding = constraints.maxHeight < 700 ? 12.0 : 20.0;
          final bottomPadding = constraints.maxHeight < 700 ? 12.0 : 20.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              if (_detected)
                Container(
                  color: Colors.green.withAlpha(180),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 80,
                    ),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      0,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          instructionText,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!_detected)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        bottomPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            label: const Text('Cancelar'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
