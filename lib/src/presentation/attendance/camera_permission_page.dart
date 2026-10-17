import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/permissions/device_permission_bootstrap.dart';
import '../widgets/app_card.dart';
import '../widgets/browser_permission_dialog.dart';

class CameraPermissionPage extends StatefulWidget {
  const CameraPermissionPage({super.key, this.permissions});

  final DevicePermissionBootstrap? permissions;

  @override
  State<CameraPermissionPage> createState() => _CameraPermissionPageState();
}

class _CameraPermissionPageState extends State<CameraPermissionPage>
    with WidgetsBindingObserver {
  late final DevicePermissionBootstrap _permissions;
  bool _busy = false;
  bool? _granted;
  String? _message;

  @override
  void initState() {
    super.initState();
    _permissions = widget.permissions ?? DevicePermissionBootstrap();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() => _run(() async {
    _granted = await _permissions.isCameraGranted();
  });

  Future<void> _request() => _run(() async {
    _granted = await _permissions.retryCameraAccess();
    if (_granted != true) {
      _message =
          'El permiso sigue desactivado. Si el sistema ya no muestra la '
          'solicitud, abrí Ajustes y permití el acceso a la cámara.';
    }
  });

  Future<void> _settings() => _run(() async {
    if (kIsWeb) {
      await ensureBrowserPermissions(
        context,
        _permissions,
        location: false,
        showHelp: true,
      );
      _granted = await _permissions.isCameraGranted();
    } else if (!await _permissions.openAppSettings()) {
      _message =
          'No se pudieron abrir los ajustes. Entrá en Ajustes del teléfono '
          '→ Aplicaciones → FichaYa → Permisos → Cámara.';
    }
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      _message =
          'No se pudo consultar o cambiar el permiso. Volvé a intentar '
          'o revisá los ajustes del dispositivo.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cámara y permisos')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Permiso de cámara',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _granted == null
                          ? 'Sin verificar'
                          : _granted!
                          ? 'Permitido'
                          : 'No permitido',
                      semanticsLabel:
                          'Estado del permiso de cámara: '
                          '${_granted == null
                              ? "sin verificar"
                              : _granted!
                              ? "permitido"
                              : "no permitido"}',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'FichaYa usa la cámara para leer códigos QR y tomar '
                      'las fotos necesarias para la fichada.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Si el permiso está permitido pero la cámara no abre, '
                      'revisá que el acceso general a la cámara esté activado en '
                      'los ajustes de privacidad del teléfono.',
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(_message!, semanticsLabel: _message),
                    ],
                    const SizedBox(height: 24),
                    if (_granted == false) ...[
                      FilledButton.icon(
                        onPressed: _busy ? null : _request,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Habilitar cámara'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _settings,
                      icon: const Icon(Icons.settings_outlined),
                      label: Text(
                        kIsWeb ? 'Permisos del navegador' : 'Abrir Ajustes',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _check,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Verificar permiso'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
