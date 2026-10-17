import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'src/core/reuniones/push_service.dart';
import 'src/core/reuniones/reunion_reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initLogging();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
      await ReunionReminders.instance.prepareChannel();
    } catch (_) {
      // Push is optional: a setup failure must never prevent attendance/login.
    }
  }
  runApp(const EmployeeAttendanceApp());
}

void _initLogging() {
  if (kReleaseMode) return;
  dev.log('Logging activo [${kDebugMode ? "DEBUG" : "PROFILE"}]', name: 'App');
}
