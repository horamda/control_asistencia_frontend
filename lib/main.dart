import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initLogging();
  runApp(const EmployeeAttendanceApp());
}

void _initLogging() {
  if (kReleaseMode) return;
  dev.log('Logging activo [${kDebugMode ? "DEBUG" : "PROFILE"}]', name: 'App');
}
