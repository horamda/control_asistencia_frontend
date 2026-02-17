import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'presentation/auth_gate_page.dart';

class EmployeeAttendanceApp extends StatelessWidget {
  const EmployeeAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF0E3A5B);
    return MaterialApp(
      title: 'Control Asistencia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: baseColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F5F8),
        useMaterial3: true,
      ),
      home: const AuthGatePage(),
      builder: (context, child) {
        final cfg = AppConfig.current;
        return Banner(
          message: cfg.flavorLabel,
          location: BannerLocation.topStart,
          color: cfg.isProd ? Colors.green : Colors.orange,
          textStyle: const TextStyle(fontSize: 10),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
