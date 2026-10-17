import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'core/reuniones/reunion_navigation.dart';
import 'presentation/auth_gate_page.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/theme_preferences.dart';
import 'presentation/version/app_version_gate.dart';

class EmployeeAttendanceApp extends StatefulWidget {
  const EmployeeAttendanceApp({super.key, this.entryPage});

  /// Allows the navigation shell to be tested independently of native auth APIs.
  @visibleForTesting
  final Widget? entryPage;

  @override
  State<EmployeeAttendanceApp> createState() => _EmployeeAttendanceAppState();
}

class _EmployeeAttendanceAppState extends State<EmployeeAttendanceApp> {
  @override
  void initState() {
    super.initState();
    ThemePreferences.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemePreferences.instance,
      builder: (context, _) => MaterialApp(
        title: 'FichaYa',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: ThemePreferences.instance.mode,
        routes: {
          '/': (_) =>
              widget.entryPage ?? const AppVersionGate(child: AuthGatePage()),
        },
        onGenerateInitialRoutes: (route) {
          ReunionNavigation.open(route);
          return [
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/'),
              builder: (_) =>
                  widget.entryPage ??
                  const AppVersionGate(child: AuthGatePage()),
            ),
          ];
        },
        builder: (context, child) {
          final cfg = AppConfig.current;
          final viewport = AppViewport(child: child ?? const SizedBox.shrink());
          if (cfg.isProd) return viewport;
          return Banner(
            message: cfg.flavorLabel,
            location: BannerLocation.topStart,
            color: Colors.orange,
            textStyle: const TextStyle(fontSize: 10),
            child: viewport,
          );
        },
      ),
    );
  }
}
