import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = AppConfig.current;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Control de Asistencia',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Aplicacion movil de empleados'),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _line('API Base URL', cfg.apiBaseUrl),
                  _line('Flavor', cfg.flavorLabel),
                  _line(
                    'Contrato',
                    'v${cfg.mobileContractVersion} ${cfg.mobileApiPrefix}',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
    );
  }
}
