import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'presentation/auth_gate_page.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/version/app_version_gate.dart';

class EmployeeAttendanceApp extends StatelessWidget {
  const EmployeeAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FichaYa',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppVersionGate(child: AuthGatePage()),
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
    );
  }
}
