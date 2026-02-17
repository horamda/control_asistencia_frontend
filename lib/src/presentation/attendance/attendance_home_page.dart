import 'package:flutter/material.dart';

import '../../core/network/mobile_api_client.dart';
import 'qr_scan_page.dart';

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({
    super.key,
    required this.apiClient,
    required this.token,
    required this.empleado,
    required this.onLogout,
  });

  final MobileApiClient apiClient;
  final String token;
  final EmployeeSummary empleado;
  final VoidCallback onLogout;

  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage> {
  bool _submitting = false;
  String? _lastQrData;

  Future<void> _ficharEntrada() => _fichar(_FichadaTipo.entrada);

  Future<void> _ficharSalida() => _fichar(_FichadaTipo.salida);

  Future<void> _fichar(_FichadaTipo tipo) async {
    if (_submitting) {
      return;
    }

    final qrData = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanPage(
          title: tipo == _FichadaTipo.entrada
              ? 'Escanear QR para entrada'
              : 'Escanear QR para salida',
        ),
      ),
    );

    if (!mounted || qrData == null) {
      return;
    }

    final cleanQrData = qrData.trim();
    if (cleanQrData.isEmpty) {
      _showMessage('QR invalido.', isError: true);
      return;
    }

    setState(() {
      _submitting = true;
      _lastQrData = cleanQrData;
    });

    try {
      final response = tipo == _FichadaTipo.entrada
          ? await widget.apiClient.registrarEntrada(
              token: widget.token,
              qrData: cleanQrData,
            )
          : await widget.apiClient.registrarSalida(
              token: widget.token,
              qrData: cleanQrData,
            );

      if (!mounted) {
        return;
      }

      final accion = tipo == _FichadaTipo.entrada ? 'entrada' : 'salida';
      final estado = response.estado ?? '-';
      _showMessage('Fichada de $accion registrada. ID: ${response.id}. Estado: $estado');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Error inesperado al registrar la fichada.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empleado = widget.empleado;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichada por QR'),
        actions: [
          IconButton(
            onPressed: _submitting ? null : widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesion',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        empleado.nombreCompleto,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text('DNI: ${empleado.dni}'),
                      if (empleado.empresaId != null)
                        Text('Empresa: ${empleado.empresaId}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _PhysicalClockButton(
                label: 'Boton fisico ENTRADA',
                icon: Icons.login_rounded,
                color: const Color(0xFF1F7A4D),
                enabled: !_submitting,
                onPressed: _ficharEntrada,
              ),
              const SizedBox(height: 14),
              _PhysicalClockButton(
                label: 'Boton fisico SALIDA',
                icon: Icons.logout_rounded,
                color: const Color(0xFF8A3B2A),
                enabled: !_submitting,
                onPressed: _ficharSalida,
              ),
              const SizedBox(height: 20),
              if (_submitting)
                const Center(child: CircularProgressIndicator())
              else
                const Text(
                  'Escanea el codigo QR y la app enviara la fichada al backend.',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              if (_lastQrData != null)
                Text(
                  'Ultimo QR leido: $_lastQrData',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _FichadaTipo { entrada, salida }

class _PhysicalClockButton extends StatelessWidget {
  const _PhysicalClockButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: Colors.black45,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white24, width: 1.5),
          ),
        ),
        icon: Icon(icon, size: 28),
        label: Text(label),
      ),
    );
  }
}
