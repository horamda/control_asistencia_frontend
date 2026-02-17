import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../core/network/mobile_api_client.dart';
import 'attendance/attendance_home_page.dart';
import 'auth/login_page.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  late final MobileApiClient _apiClient;
  LoginResponse? _session;

  @override
  void initState() {
    super.initState();
    _apiClient = MobileApiClient(baseUrl: AppConfig.current.apiBaseUrl);
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  void _onLoginSuccess(LoginResponse session) {
    setState(() {
      _session = session;
    });
  }

  void _logout() {
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return LoginPage(
        apiClient: _apiClient,
        onLoginSuccess: _onLoginSuccess,
      );
    }

    return AttendanceHomePage(
      apiClient: _apiClient,
      token: session.token,
      empleado: session.empleado,
      onLogout: _logout,
    );
  }
}
