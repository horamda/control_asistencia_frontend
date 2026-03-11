import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, required this.title});

  final String title;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;

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
      Navigator.of(context).pop(value);
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        child: const Text(
                          'Apunta la camara al QR para fichar.',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
