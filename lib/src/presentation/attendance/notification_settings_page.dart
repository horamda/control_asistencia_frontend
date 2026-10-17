import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/reuniones/push_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page_layout.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  bool _busy = false;
  String _permission = 'Consultando permisos…';
  String? _error;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_run());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_run());
  }

  Future<void> _run({bool enable = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (enable) {
        await PushService.instance.enable();
      } else {
        await PushService.instance.refresh();
      }
      final permission = _android ? await Permission.notification.status : null;
      if (!mounted) return;
      setState(
        () => _permission = _android
            ? (permission!.isGranted
                  ? 'Permiso de Android: habilitado'
                  : 'Permiso de Android: deshabilitado')
            : kIsWeb
            ? 'Los permisos se administran desde el navegador.'
            : 'Disponible en Android y web.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo verificar la configuración. Revisá tu conexión y reintentá.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settings() async {
    try {
      if (!await openAppSettings() && mounted) {
        setState(
          () => _error =
              'Abrí Ajustes del celular → Aplicaciones → FichaYa → Notificaciones.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Abrí Ajustes del celular → Aplicaciones → FichaYa → Notificaciones.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notificaciones')),
    body: AppPageBody(
      maxWidth: 640,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(_permission, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: PushService.instance.status,
                  builder: (_, status, _) =>
                      Text(status, textAlign: TextAlign.center),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 12),
                AppAdaptiveActions(
                  children: [
                    FilledButton(
                      onPressed: _busy || !PushService.instance.supported
                          ? null
                          : () => _run(enable: true),
                      child: const Text(
                        'Activar notificaciones',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _run(),
                      child: const Text('Verificar conexión'),
                    ),
                    if (_android)
                      OutlinedButton(
                        onPressed: _busy ? null : _settings,
                        child: const Text('Ajustes de Android'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                const Text(
                  'Sonido y avisos en pantalla',
                  style: TextStyle(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _android
                      ? 'En Ajustes de Android, entrá en Notificaciones. Allí podés activar o silenciar los avisos y ajustar sonido, vibración y avisos emergentes según las opciones de tu celular.'
                      : 'En el navegador, abrí los permisos de este sitio y revisá Notificaciones. Si bloqueaste el permiso, habilitalo allí y volvé a verificar la conexión.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const AppCard(
            child: Column(
              children: [
                Text(
                  'Con la app cerrada',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'Mantené tu sesión iniciada, los permisos habilitados y conexión a Internet. Si forzás la detención desde Android, abrí FichaYa nuevamente.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Los comunicados que la empresa conserve siguen disponibles en Comunicados, aunque borres la notificación del celular.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
