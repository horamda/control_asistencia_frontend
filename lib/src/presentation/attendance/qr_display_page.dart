import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';

class QrDisplayPage extends StatefulWidget {
  const QrDisplayPage({
    super.key,
    required this.apiClient,
    required this.token,
  });

  final MobileApiClient apiClient;
  final String token;

  @override
  State<QrDisplayPage> createState() => _QrDisplayPageState();
}

class _QrDisplayPageState extends State<QrDisplayPage> {
  bool _loading = true;
  String? _error;
  GenerarQrResponse? _qr;

  @override
  void initState() {
    super.initState();
    _generar();
  }

  Future<void> _generar() async {
    setState(() {
      _loading = true;
      _error = null;
      _qr = null;
    });
    try {
      final qr = await widget.apiClient.generarQr(token: widget.token);
      if (!mounted) return;
      setState(() {
        _qr = qr;
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
        _error = 'No se pudo generar el QR.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi QR de fichada')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _generar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final qr = _qr!;
    final imgBytes = _decodeQrImage(qr.qrPngBase64);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (imgBytes != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Image.memory(imgBytes, width: 260, height: 260),
            )
          else
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.qr_code, size: 80),
              ),
            ),
          const SizedBox(height: 24),
          _InfoRow(label: 'Acción', value: qr.accion),
          _InfoRow(label: 'Alcance', value: qr.scope),
          _InfoRow(label: 'Tipo de marca', value: qr.tipoMarca),
          if (qr.expiraAt != null)
            _InfoRow(label: 'Vence', value: _formatExpira(qr.expiraAt!)),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Presentá este QR ante el lector de la empresa para registrar tu fichada.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _generar,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerar QR'),
          ),
        ],
      ),
    );
  }

  Uint8List? _decodeQrImage(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      final clean = base64Str.contains(',')
          ? base64Str.split(',').last
          : base64Str;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  String _formatExpira(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoString;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
