import 'package:flutter/foundation.dart';

class NotificationsNavigation {
  static final route = ValueNotifier<String?>(null);
  static bool openRoute(String? value) {
    if (!RegExp(
      r'^/(equipo/)?vacaciones/[1-9][0-9]*/?$',
    ).hasMatch(value ?? '')) {
      return false;
    }
    route.value = value;
    return true;
  }

  /// Avisos de fichada: solo push, no quedan en la bandeja. Al tocarlos se
  /// vuelve a la pantalla principal, donde se ficha.
  static const homeTypes = {
    'salida_pendiente',
    'ingreso_pendiente',
    'ingreso_equipo',
  };
  static final home = ValueNotifier<int>(0);
  static bool openHome(dynamic tipo) {
    if (!homeTypes.contains('$tipo')) return false;
    home.value++;
    return true;
  }

  static final pending = ValueNotifier<int?>(null);
  static final refresh = ValueNotifier<int>(0);
  static void open(dynamic id) {
    pending.value = int.tryParse('$id') ?? 0;
  }
}
