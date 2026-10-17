import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de', textAlign: TextAlign.center),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              children: [
                // Logo oficial de FichaYa.
                Center(
                  child: Image.asset(
                    'assets/branding/fichaya-header.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo de FichaYa',
                  ),
                ),
                const SizedBox(height: 20),

                // Nombre y versión
                Center(
                  child: Text(
                    'FichaYa',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _version != null ? 'Versión $_version' : 'Versión...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 24),

                // Desarrollado por
                const _InfoTile(
                  icon: Icons.business_rounded,
                  label: 'Desarrollado por',
                  value: 'Área de Operaciones\ndel Palacio S.A.',
                ),
                const SizedBox(height: 16),
                const _InfoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Gerente de operaciones',
                  value: 'Yeuchuk Horacio\ndel Palacio S.A.',
                ),
                const SizedBox(height: 16),
                const _InfoTile(
                  icon: Icons.phone_android_rounded,
                  label: 'Plataforma',
                  value: 'Android / iOS',
                ),
                const SizedBox(height: 32),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 20),

                Center(
                  child: Text(
                    '© ${DateTime.now().year} del Palacio S.A.\nTodos los derechos reservados.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: cs.onSecondaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
