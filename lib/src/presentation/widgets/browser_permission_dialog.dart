import 'package:flutter/material.dart';
import '../../core/permissions/device_permission_bootstrap.dart';

Future<bool> ensureBrowserPermissions(
  BuildContext context,
  DevicePermissionBootstrap permissions, {
  bool camera = true,
  bool location = true,
  bool showHelp = false,
}) async {
  final cameraReady = !camera || await permissions.isCameraGranted();
  final locationReady = !location || await permissions.isLocationGranted();
  if (!context.mounted) return false;
  if (!showHelp && cameraReady && locationReady) return true;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PermissionDialog(
          permissions: permissions,
          camera: camera,
          location: location,
        ),
      ) ??
      false;
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({
    required this.permissions,
    required this.camera,
    required this.location,
  });
  final DevicePermissionBootstrap permissions;
  final bool camera;
  final bool location;

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog> {
  bool _busy = false;
  String? _error;
  bool _cameraDone = false;
  bool _locationDone = false;

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    // Each device request starts from its own tap, without awaiting the other
    // permission first (important for browser user activation on Safari).
    final askingCamera = widget.camera && !_cameraDone;
    if (askingCamera) {
      _cameraDone = await widget.permissions.requestCameraAccess();
    } else if (widget.location) {
      _locationDone = await widget.permissions.requestLocationAccess();
    }
    if (!mounted) return;
    final cameraOk = !widget.camera || _cameraDone;
    final locationOk = !widget.location || _locationDone;
    if (cameraOk && locationOk) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = askingCamera
          ? (cameraOk
                ? null
                : widget.permissions.cameraAccessError ??
                      'No se pudo abrir la cámara.')
          : (widget.permissions.locationAccessError ??
                'No se pudo obtener tu ubicación. Revisá el permiso y que la localización esté activada.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = _error != null
        ? 'Reintentar'
        : widget.camera && !_cameraDone
        ? 'Activar cámara'
        : 'Activar ubicación';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Permisos del navegador',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Activá los permisos para continuar. Elegí Permitir cuando el navegador lo solicite.',
                    ),
                    const SizedBox(height: 16),
                    if (widget.camera)
                      _permissionCard(
                        icon: Icons.camera_alt_outlined,
                        title: 'Cámara',
                        subtitle: 'Para escanear el QR y tomar fotos.',
                        done: _cameraDone,
                      ),
                    if (widget.location)
                      _permissionCard(
                        icon: Icons.location_on_outlined,
                        title: 'Ubicación',
                        subtitle: 'Para verificar dónde estás al fichar.',
                        done: _locationDone,
                      ),
                    if (_error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_busy) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Esperando respuesta del navegador…'),
                    ],
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: const Text('¿Necesitás ayuda?'),
                      children: const [
                        Text(
                          'iPhone / Safari: menú de la página → Configuración del sitio web → Cámara y Ubicación.\n\nAndroid / Chrome: información del sitio junto a la dirección → Permisos.\n\nActivá la localización del teléfono y abrí FichaYa directamente en Safari o Chrome.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final primary = FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _busy ? null : _request,
                    child: Text(
                      _busy ? 'Esperando…' : label,
                      textAlign: TextAlign.center,
                    ),
                  );
                  final cancel = TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Ahora no'),
                  );
                  if (constraints.maxWidth < 360 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [primary, const SizedBox(height: 4), cancel],
                    );
                  }
                  return Row(
                    children: [
                      cancel,
                      const SizedBox(width: 12),
                      Expanded(child: primary),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool done,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? colors.secondaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(done ? Icons.check_circle_outline : icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(done ? 'Activada' : subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
