import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/image/profile_photo_cache.dart';
import '../../core/network/mobile_api_client.dart';
import '../profile/profile_page.dart';
import 'attendance_history_page.dart';
import 'employee_stats_page.dart';
import 'marks_history_page.dart';
import 'qr_scan_page.dart';
import 'security_events_page.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  bool _submitting = false;
  bool _loadingConfig = false;
  bool _loadingProfile = false;
  bool _locatingGps = false;
  String? _lastQrData;
  String? _profileLoadError;
  _GpsPoint? _lastGps;
  AttendanceConfig? _config;
  EmployeeProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadProfile();
  }

  Future<void> _fichar() async {
    await _runScanAndClock();
  }

  Future<void> _openSecurityEvents() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SecurityEventsPage(
          apiClient: widget.apiClient,
          token: widget.token,
        ),
      ),
    );
  }

  Future<void> _openAttendanceHistory() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceHistoryPage(
          apiClient: widget.apiClient,
          token: widget.token,
        ),
      ),
    );
  }

  Future<void> _openMarksHistory() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MarksHistoryPage(apiClient: widget.apiClient, token: widget.token),
      ),
    );
  }

  Future<void> _openStats() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EmployeeStatsPage(apiClient: widget.apiClient, token: widget.token),
      ),
    );
  }

  Future<void> _openProfile() async {
    if (_submitting) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProfilePage(apiClient: widget.apiClient, token: widget.token),
      ),
    );
    if (!mounted) {
      return;
    }
    ProfilePhotoCache.bump();
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final previousPhotoUrl = (_profile?.foto ?? widget.empleado.foto ?? '')
        .trim();
    if (_loadingProfile) {
      return;
    }
    setState(() {
      _loadingProfile = true;
    });
    try {
      final profile = await widget.apiClient.getMe(token: widget.token);
      final nextPhotoUrl = (profile.foto ?? widget.empleado.foto ?? '').trim();
      if (previousPhotoUrl != nextPhotoUrl) {
        await ProfilePhotoCache.evict(previousPhotoUrl);
        ProfilePhotoCache.bump();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _profileLoadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileLoadError = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileLoadError = 'No se pudo cargar el perfil/foto.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadConfig() async {
    if (_loadingConfig) {
      return;
    }
    setState(() {
      _loadingConfig = true;
    });
    try {
      final config = await widget.apiClient.getConfigAsistencia(
        token: widget.token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingConfig = false;
        });
      }
    }
  }

  Future<String?> _capturePhotoBase64() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 70,
        requestFullMetadata: false,
      );
      if (photo == null) {
        return null;
      }
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<_GpsPoint?> _captureGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      return _GpsPoint(
        lat: position.latitude,
        lon: position.longitude,
        accuracyM: position.accuracy,
        capturedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _captureAndShowGps() async {
    if (_submitting || _loadingConfig || _locatingGps) {
      return;
    }
    setState(() {
      _locatingGps = true;
    });
    try {
      final gps = await _captureGps();
      if (!mounted) {
        return;
      }
      if (gps == null) {
        _showMessage(
          'No se pudo obtener GPS. Verifica permisos y GPS del telefono.',
          isError: true,
        );
        return;
      }
      setState(() {
        _lastGps = gps;
      });
      _showMessage(
        'GPS OK: ${gps.lat.toStringAsFixed(6)}, ${gps.lon.toStringAsFixed(6)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _locatingGps = false;
        });
      }
    }
  }

  Future<void> _runScanAndClock() async {
    if (_submitting || _loadingConfig) {
      return;
    }

    await _loadConfig();
    if (!mounted) {
      return;
    }
    final effectiveConfig = _config;
    if (effectiveConfig == null) {
      _showMessage(
        'No se pudo obtener la configuracion de fichada. Reintenta.',
        isError: true,
      );
      return;
    }
    if (!effectiveConfig.isMetodoHabilitado('qr')) {
      _showMessage(
        'El metodo QR no esta habilitado para tu empresa en este momento.',
        isError: true,
      );
      return;
    }

    final qrData = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScanPage(title: 'Escanear QR para fichar'),
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
      String? foto;
      double? lat;
      double? lon;

      if (effectiveConfig.requiereFoto) {
        foto = await _capturePhotoBase64();
        if (foto == null || foto.isEmpty) {
          throw ApiException(message: 'La empresa requiere foto para fichar.');
        }
      }

      final gps = await _captureGps();
      if (gps == null) {
        throw ApiException(
          message: 'Debes habilitar la ubicacion para fichar por QR.',
        );
      }
      setState(() {
        _lastGps = gps;
      });
      lat = gps.lat;
      lon = gps.lon;

      final response = await widget.apiClient.registrarScanQr(
        token: widget.token,
        qrToken: cleanQrData,
        foto: foto,
        lat: lat,
        lon: lon,
      );

      if (!mounted) {
        return;
      }

      final accion = (response.accion ?? 'movimiento').trim();
      final estado = response.estado ?? '-';
      _showMessage(
        'Fichada de $accion registrada. ID: ${response.id}. Estado: $estado',
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.code == 'scan_cooldown') {
        _showCooldownMessage(e);
      } else if (e.alertaFraude == true) {
        _showFraudMessage(e);
      } else {
        _showMessage(e.message, isError: true);
      }
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

  void _showFraudMessage(ApiException error) {
    final eventSuffix = error.eventoId != null
        ? ' Evento #${error.eventoId}.'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${error.message}$eventSuffix'),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Ver eventos',
          textColor: Colors.white,
          onPressed: () {
            _openSecurityEvents();
          },
        ),
      ),
    );
  }

  void _showCooldownMessage(ApiException error) {
    final remaining = error.cooldownSegundosRestantes;
    final message = (remaining != null && remaining > 0)
        ? 'Escaneo duplicado. Espera $remaining segundos para volver a fichar.'
        : error.message;
    _showMessage(message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final empleado = widget.empleado;
    final fotoUrl = ProfilePhotoCache.withRevision(
      (_profile?.foto ?? empleado.foto ?? '').trim(),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichada por QR'),
        actions: [
          IconButton(
            onPressed: _submitting ? null : _openProfile,
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi perfil',
          ),
          IconButton(
            onPressed: _submitting ? null : _openSecurityEvents,
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Eventos de seguridad',
          ),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EmployeeAvatar(photoUrl: fotoUrl),
                      const SizedBox(width: 12),
                      Expanded(
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
                    ],
                  ),
                ),
              ),
              if (_profileLoadError != null) ...[
                const SizedBox(height: 10),
                Card(
                  color: const Color(0xFFFFF4E5),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_profileLoadError!),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_config != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _ruleChip(label: 'QR', enabled: _config!.requiereQr),
                        _ruleChip(
                          label: 'FOTO',
                          enabled: _config!.requiereFoto,
                        ),
                        _ruleChip(label: 'GPS', enabled: true),
                        _infoChip(
                          'Cooldown: ${_config!.cooldownScanSegundos}s',
                        ),
                        if (_config!.toleranciaGlobal != null)
                          _infoChip(
                            'Tolerancia: ${_config!.toleranciaGlobal} min',
                          ),
                        if (_config!.metodosHabilitados.isNotEmpty)
                          _infoChip(
                            'Metodos: ${_config!.metodosHabilitados.join(', ')}',
                          ),
                      ],
                    ),
                  ),
                ),
              if (_config != null) const SizedBox(height: 12),
              _PhysicalClockButton(
                label: 'Escanear QR y fichar',
                icon: Icons.qr_code_scanner_rounded,
                color: const Color(0xFF0E5A8A),
                enabled: !_submitting,
                onPressed: _fichar,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: (_submitting || _locatingGps)
                    ? null
                    : _captureAndShowGps,
                icon: _locatingGps
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: Text(
                  _locatingGps ? 'Obteniendo GPS...' : 'Obtener ubicacion GPS',
                ),
              ),
              const SizedBox(height: 8),
              if (_lastGps != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Ultimo GPS: ${_lastGps!.lat.toStringAsFixed(6)}, '
                      '${_lastGps!.lon.toStringAsFixed(6)}'
                      '${_lastGps!.accuracyM != null ? " | precision ${_lastGps!.accuracyM!.toStringAsFixed(1)} m" : ""}'
                      '${_lastGps!.capturedAt != null ? " | ${_lastGps!.capturedAt!.hour.toString().padLeft(2, '0')}:${_lastGps!.capturedAt!.minute.toString().padLeft(2, '0')}" : ""}',
                    ),
                  ),
                ),
              if (_lastGps != null) const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _openProfile,
                icon: const Icon(Icons.person_outline),
                label: const Text('Mi perfil'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _openAttendanceHistory,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Ver asistencias'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _openMarksHistory,
                icon: const Icon(Icons.timeline_outlined),
                label: const Text('Ver marcas'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _openStats,
                icon: const Icon(Icons.insights_outlined),
                label: const Text('Ver estadisticas'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _openSecurityEvents,
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Ver eventos de seguridad'),
              ),
              const SizedBox(height: 20),
              if (_submitting)
                const Center(child: CircularProgressIndicator())
              else
                const Text(
                  'Escanea el codigo QR y el backend determina si es ingreso o egreso. '
                  'Para QR, la ubicacion del dispositivo es obligatoria.',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              if (_lastQrData != null)
                Text(
                  'Ultimo QR leido: ${_shortQr(_lastQrData!)}',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleChip({required String label, required bool enabled}) {
    return Chip(
      label: Text('$label: ${enabled ? "requerido" : "opcional"}'),
      backgroundColor: enabled
          ? const Color(0xFFE6F4EA)
          : const Color(0xFFF1F3F5),
    );
  }

  Widget _infoChip(String text) {
    return Chip(label: Text(text), backgroundColor: const Color(0xFFE8EEF7));
  }

  String _shortQr(String token) {
    if (token.length <= 38) {
      return token;
    }
    return '${token.substring(0, 22)}...${token.substring(token.length - 12)}';
  }
}

class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isEmpty) {
      return const CircleAvatar(
        radius: 26,
        backgroundColor: Color(0xFFE5ECF3),
        child: Icon(Icons.person_outline),
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFFE5ECF3),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (_, __) => const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          errorWidget: (_, __, ___) => const Icon(Icons.person_outline),
        ),
      ),
    );
  }
}

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

class _GpsPoint {
  const _GpsPoint({
    required this.lat,
    required this.lon,
    this.accuracyM,
    this.capturedAt,
  });

  final double lat;
  final double lon;
  final double? accuracyM;
  final DateTime? capturedAt;
}
