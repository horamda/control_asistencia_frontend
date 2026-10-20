import 'package:flutter/material.dart';
import '../theme/app_visual.dart';

class AppMenuEntry<T> {
  const AppMenuEntry(this.value, this.icon, this.label);
  final T value;
  final IconData icon;
  final String label;
}

/// A scrollable menu that grows with accessible text instead of a narrow popup.
class AppMenuPage<T> extends StatelessWidget {
  const AppMenuPage({super.key, required this.sections});
  final Map<String, List<AppMenuEntry<T>>> sections;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Más opciones')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppVisual.cardPadding),
              children: [
                for (final section in sections.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      section.key,
                      style: AppVisual.sectionTitle,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  Material(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppVisual.cardRadius),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final entry in section.value)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            minLeadingWidth: 24,
                            horizontalTitleGap: 16,
                            leading: Icon(entry.icon, color: cs.primary),
                            title: Text(
                              entry.label,
                              style: AppVisual.body,
                              textAlign: TextAlign.start,
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                            onTap: () => Navigator.of(context).pop(entry.value),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
