import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/version/app_version_service.dart';
import '../widgets/app_startup_screen.dart';

/// Comprueba la versión antes de montar el contenido de la aplicación.
class AppVersionGate extends StatefulWidget {
  const AppVersionGate({
    super.key,
    required this.child,
    this.checkVersion = AppVersionService.check,
  });

  final Widget child;
  final Future<AppVersionCheckResult?> Function() checkVersion;

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate> {
  bool _checked = false;
  AppVersionCheckResult? _requiredUpdate;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final result = await widget
        .checkVersion()
        .then<AppVersionCheckResult?>((value) => value)
        .timeout(const Duration(seconds: 10), onTimeout: () => null);
    if (!mounted) return;

    setState(() {
      _checked = true;
      _requiredUpdate = result?.requiresUpdate == true ? result : null;
    });

    if (result == null) return; // fallo silencioso, dejar pasar

    if (result.recommendsUpdate) {
      await _showRecommendUpdateDialog(result);
    }
  }

  Widget _buildRequiredUpdate(AppVersionCheckResult result) {
    final downloadUrl = result.urlDescarga?.trim();
    final hasDownload = downloadUrl != null && downloadUrl.isNotEmpty;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.system_update_alt_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Actualización requerida',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    result.mensaje ??
                        'Tu versión de FichaYa (${result.currentVersion}) ya no es compatible. '
                            'Actualizá la app para continuar.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Versión mínima requerida: ${result.versionMinima}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (hasDownload)
                    FilledButton.icon(
                      onPressed: () => _openUrl(downloadUrl),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text(
                        'Actualizar ahora',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    const Text(
                      'Contactá al administrador para obtener la versión actualizada.',
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRecommendUpdateDialog(AppVersionCheckResult result) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.new_releases_rounded, size: 48),
        title: const Text(
          'Nueva versión disponible',
          textAlign: TextAlign.center,
        ),
        content: Text(
          result.mensaje ??
              'Hay una nueva versión de FichaYa disponible (${result.versionRecomendada}). '
                  'Te recomendamos actualizar para disfrutar las últimas mejoras.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Más tarde', textAlign: TextAlign.center),
          ),
          if (result.urlDescarga != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openUrl(result.urlDescarga!);
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Actualizar', textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras verifica, mostramos un splash mínimo para evitar flicker
    if (!_checked) {
      return const AppStartupScreen();
    }
    final requiredUpdate = _requiredUpdate;
    if (requiredUpdate != null) return _buildRequiredUpdate(requiredUpdate);
    return widget.child;
  }
}
