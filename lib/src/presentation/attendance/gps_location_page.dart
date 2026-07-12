import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/attendance/qr_clock_submission_service.dart';
import '../../core/attendance/clock_gps_service.dart';
import '../../core/permissions/device_permission_bootstrap.dart';
import '../../core/utils/date_formatter.dart';

class GpsLocationPage extends StatefulWidget {
  const GpsLocationPage({
    super.key,
    this.gpsService,
    this.permissionBootstrap,
    this.timeLimit = const Duration(seconds: 8),
  });

  final ClockGpsService? gpsService;
  final DevicePermissionBootstrap? permissionBootstrap;
  final Duration timeLimit;

  @override
  State<GpsLocationPage> createState() => _GpsLocationPageState();
}

class _GpsLocationPageState extends State<GpsLocationPage>
    with WidgetsBindingObserver {
  late final DevicePermissionBootstrap _permissionBootstrap;
  late final ClockGpsService _gpsService;

  bool _loading = true;
  bool _refreshing = false;
  ClockGpsAvailability? _availability;
  ClockGpsPoint? _location;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionBootstrap =
        widget.permissionBootstrap ?? DevicePermissionBootstrap();
    _gpsService =
        widget.gpsService ??
        ClockGpsService(
          locationServiceEnabledProvider: Geolocator.isLocationServiceEnabled,
          locationGrantedProvider: _permissionBootstrap.isLocationGranted,
        );
    unawaited(_loadLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_loadLocation());
    }
  }

  Future<void> _loadLocation() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;

    if (mounted) {
      setState(() {
        _loading = _location == null;
        _error = null;
      });
    }

    try {
      final availability = await _gpsService.readAvailability();
      ClockGpsPoint? location;
      String? error;

      if (!availability.locationServiceEnabled) {
        error = 'El GPS del dispositivo esta apagado.';
      } else if (!availability.locationGranted) {
        error = 'La app no tiene permiso de ubicacion.';
      } else {
        location = await _gpsService.capture(
          forceRefresh: true,
          gpsTtl: Duration.zero,
          timeLimit: widget.timeLimit,
        );
        if (location == null) {
          error = 'No se pudo obtener la ubicacion actual.';
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _availability = availability;
        _location = location;
        _error = error;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo consultar el GPS real.';
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _openLocationSettings() async {
    await _permissionBootstrap.openLocationSettings();
  }

  Future<void> _openAppSettings() async {
    await _permissionBootstrap.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final availability = _availability;
    final cs = Theme.of(context).colorScheme;

    if (_loading && location == null && _error == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi ubicacion GPS'),
          actions: [
            if (_refreshing)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi ubicacion GPS'),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          else
            IconButton(
              tooltip: 'Actualizar GPS real',
              onPressed: () => unawaited(_loadLocation()),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLocation,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _GpsHeroCard(
              availability: availability,
              hasLocation: location != null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(
                message: _error!,
                onRefresh: _refreshing ? null : _loadLocation,
                onOpenLocationSettings: _openLocationSettings,
                onOpenAppSettings: _openAppSettings,
              ),
            ],
            const SizedBox(height: 12),
            _CoordinatesCard(location: location),
            const SizedBox(height: 12),
            _DetailsCard(
              location: location,
              availability: availability,
              onRefresh: _refreshing ? null : _loadLocation,
              onOpenLocationSettings: _openLocationSettings,
              onOpenAppSettings: _openAppSettings,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'La lectura usa GPS real del dispositivo con alta precision. '
                  'Si no aparece una ubicacion, revisa permisos y el GPS del telefono.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsHeroCard extends StatelessWidget {
  const _GpsHeroCard({required this.availability, required this.hasLocation});

  final ClockGpsAvailability? availability;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final serviceEnabled = availability?.locationServiceEnabled;
    final permissionGranted = availability?.locationGranted;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.my_location_outlined,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLocation ? 'GPS real disponible' : 'Buscando GPS real',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mostramos la ultima lectura actual del dispositivo, no una estimacion vieja.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: serviceEnabled == null
                            ? 'GPS: verificando'
                            : serviceEnabled
                            ? 'GPS: activo'
                            : 'GPS: apagado',
                        color: _statusColor(context, enabled: serviceEnabled),
                      ),
                      _StatusChip(
                        label: permissionGranted == null
                            ? 'Permiso: verificando'
                            : permissionGranted
                            ? 'Permiso: concedido'
                            : 'Permiso: pendiente',
                        color: _statusColor(
                          context,
                          enabled: permissionGranted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoordinatesCard extends StatelessWidget {
  const _CoordinatesCard({required this.location});

  final ClockGpsPoint? location;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lat = location?.lat.toStringAsFixed(6) ?? '-';
    final lon = location?.lon.toStringAsFixed(6) ?? '-';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Coordenadas actuales',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _CoordinateBlock(label: 'Latitud', value: lat),
            const SizedBox(height: 10),
            _CoordinateBlock(label: 'Longitud', value: lon),
            const SizedBox(height: 12),
            Text(
              'Estas coordenadas salen de la lectura del GPS del dispositivo.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.location,
    required this.availability,
    required this.onRefresh,
    required this.onOpenLocationSettings,
    required this.onOpenAppSettings,
  });

  final ClockGpsPoint? location;
  final ClockGpsAvailability? availability;
  final Future<void> Function()? onRefresh;
  final Future<void> Function() onOpenLocationSettings;
  final Future<void> Function() onOpenAppSettings;

  @override
  Widget build(BuildContext context) {
    final locationText = location == null
        ? 'Sin lectura'
        : '${location!.lat.toStringAsFixed(6)}, ${location!.lon.toStringAsFixed(6)}';
    final accuracyText = location?.accuracyM == null
        ? 'Sin precision reportada'
        : '${location!.accuracyM!.toStringAsFixed(1)} m';
    final capturedAtText = _formatCapturedAt(location?.capturedAt);
    final serviceText = availability == null
        ? 'Verificando'
        : availability!.locationServiceEnabled
        ? 'Activo'
        : 'Apagado';
    final permissionText = availability == null
        ? 'Verificando'
        : availability!.locationGranted
        ? 'Concedido'
        : 'Pendiente';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Detalle de lectura',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Lectura', value: locationText),
            _DetailRow(label: 'Precision', value: accuracyText),
            _DetailRow(label: 'Tomada', value: capturedAtText),
            _DetailRow(label: 'Estado GPS', value: serviceText),
            _DetailRow(label: 'Permiso', value: permissionText),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onRefresh == null
                      ? null
                      : () => unawaited(onRefresh!()),
                  icon: const Icon(Icons.gps_fixed_outlined),
                  label: const Text('Actualizar GPS'),
                ),
                OutlinedButton.icon(
                  onPressed: () => unawaited(onOpenLocationSettings()),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Ajustes de ubicacion'),
                ),
                OutlinedButton.icon(
                  onPressed: () => unawaited(onOpenAppSettings()),
                  icon: const Icon(Icons.app_settings_alt_outlined),
                  label: const Text('Ajustes de la app'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRefresh,
    required this.onOpenLocationSettings,
    required this.onOpenAppSettings,
  });

  final String message;
  final Future<void> Function()? onRefresh;
  final Future<void> Function() onOpenLocationSettings;
  final Future<void> Function() onOpenAppSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onRefresh == null
                      ? null
                      : () => unawaited(onRefresh!()),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => unawaited(onOpenLocationSettings()),
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Abrir ubicacion'),
                ),
                OutlinedButton.icon(
                  onPressed: () => unawaited(onOpenAppSettings()),
                  icon: const Icon(Icons.app_settings_alt_outlined, size: 16),
                  label: const Text('Abrir app'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoordinateBlock extends StatelessWidget {
  const _CoordinateBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          SelectableText(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _statusColor(BuildContext context, {required bool? enabled}) {
  if (enabled == null) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
  if (enabled) {
    return const Color(0xFF1F5A35);
  }
  return const Color(0xFF9A2E2E);
}

String _formatCapturedAt(DateTime? capturedAt) {
  if (capturedAt == null) {
    return 'Sin lectura';
  }
  final local = capturedAt.toLocal();
  final date = DateFormatter.formatDisplayDate(local);
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
