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

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final cameraOk =
        !widget.camera || await widget.permissions.requestCameraAccess();
    if (!mounted) return;
    final locationOk =
        !widget.location || await widget.permissions.requestLocationAccess();
    if (!mounted) return;
    if (cameraOk && locationOk) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = [
        if (!cameraOk) 'No se pudo abrir la cámara.',
        if (!locationOk)
          widget.permissions.locationAccessError ??
              'No se pudo obtener tu ubicación. Revisá el permiso y que la localización esté activada.',
      ].join('\n');
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: true,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Permisos del navegador'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            [
              if (widget.camera)
                'Cámara: para escanear el QR o tomar una foto.',
              if (widget.location)
                'Ubicación: para verificar dónde estás al fichar.',
            ].join('\n'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tocá Activar permisos y elegí Permitir cuando el navegador lo solicite.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Si lo bloqueaste anteriormente:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'iPhone / Safari: menú de la página → Configuración del sitio web → Cámara y Ubicación.\n\nAndroid / Chrome: información del sitio junto a la dirección → Permisos.\n\nActivá también la localización del teléfono. Abrí el enlace directamente en Safari o Chrome usando HTTPS.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const Text('Esperando permiso o ubicación…'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: _busy ? null : _request,
          child: Text(_error == null ? 'Activar permisos' : 'Reintentar'),
        ),
      ],
    ),
  );
}
