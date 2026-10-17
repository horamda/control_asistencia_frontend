import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemePreferences extends ChangeNotifier {
  ThemePreferences({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  static final instance = ThemePreferences();
  static const storageKey = 'app_appearance_v1';
  final FlutterSecureStorage _storage;
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  int _revision = 0;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    final revision = _revision;
    try {
      final saved = await _storage.read(key: storageKey);
      if (revision != _revision) return;
      _mode =
          ThemeMode.values.where((m) => m.name == saved).firstOrNull ??
          ThemeMode.system;
      notifyListeners();
    } catch (_) {
      // If storage is unavailable, the system setting remains usable.
    }
  }

  Future<void> setMode(ThemeMode mode) {
    _revision++;
    _mode = mode;
    notifyListeners();
    final write = _writes.then(
      (_) => _storage.write(key: storageKey, value: mode.name),
    );
    _writes = write.catchError((Object _) {});
    return write;
  }
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Apariencia')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: ThemePreferences.instance,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Elegí cómo querés ver FichaYa.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                for (final option in [
                  (
                    ThemeMode.system,
                    Icons.brightness_auto_outlined,
                    'Según el sistema',
                    'Se adapta a la configuración del dispositivo.',
                  ),
                  (
                    ThemeMode.light,
                    Icons.light_mode_outlined,
                    'Claro',
                    'Fondos claros y azul institucional.',
                  ),
                  (
                    ThemeMode.dark,
                    Icons.dark_mode_outlined,
                    'Oscuro',
                    'Fondos oscuros y texto de alto contraste.',
                  ),
                ])
                  AppCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: Icon(option.$2),
                      title: Text(option.$3, textAlign: TextAlign.center),
                      subtitle: Text(option.$4, textAlign: TextAlign.center),
                      selected: ThemePreferences.instance.mode == option.$1,
                      trailing: ThemePreferences.instance.mode == option.$1
                          ? const Icon(Icons.check_circle_outline)
                          : const SizedBox(width: 24),
                      onTap: () async {
                        try {
                          await ThemePreferences.instance.setMode(option.$1);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'El tema se aplicó, pero no se pudo guardar en este dispositivo.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
