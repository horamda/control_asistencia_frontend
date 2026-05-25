import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/version/app_version_service.dart';

/// Llama al chequeo de versión al montarse. Si detecta que la versión está
/// desactualizada muestra el diálogo apropiado y llama a [onChecked] cuando
/// el usuario puede continuar (o inmediatamente si no hay problema).
class AppVersionGate extends StatefulWidget {
  const AppVersionGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final result = await AppVersionService.check();
    if (!mounted) return;

    setState(() => _checked = true);

    if (result == null) return; // fallo silencioso, dejar pasar

    if (result.requiresUpdate) {
      await _showForceUpdateDialog(result);
    } else if (result.recommendsUpdate) {
      await _showRecommendUpdateDialog(result);
    }
  }

  Future<void> _showForceUpdateDialog(AppVersionCheckResult result) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.system_update_alt, size: 48),
          title: const Text('Actualización requerida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.mensaje ??
                    'Tu versión de FichaYa (${result.currentVersion}) ya no es compatible. '
                    'Actualizá la app para continuar.',
              ),
              const SizedBox(height: 8),
              Text(
                'Versión mínima requerida: ${result.versionMinima}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            if (result.urlDescarga != null)
              FilledButton.icon(
                onPressed: () => _openUrl(result.urlDescarga!),
                icon: const Icon(Icons.download),
                label: const Text('Actualizar ahora'),
              )
            else
              FilledButton(
                onPressed: () {},
                child: const Text('Actualizar'),
              ),
          ],
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
        icon: const Icon(Icons.new_releases_outlined, size: 48),
        title: const Text('Nueva versión disponible'),
        content: Text(
          result.mensaje ??
              'Hay una nueva versión de FichaYa disponible (${result.versionRecomendada}). '
              'Te recomendamos actualizar para disfrutar las últimas mejoras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Más tarde'),
          ),
          if (result.urlDescarga != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openUrl(result.urlDescarga!);
              },
              icon: const Icon(Icons.download),
              label: const Text('Actualizar'),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
