import 'package:flutter/foundation.dart';

class ComunicadosNavigation {
  static final pending = ValueNotifier<int?>(null);
  static final refresh = ValueNotifier<int>(0);

  static bool open(String? route) {
    if (route == '/comunicados' || route == '/comunicados/') {
      pending.value = 0;
      return true;
    }
    final match = RegExp(
      r'^/comunicados/([1-9][0-9]*)/?$',
    ).firstMatch(route ?? '');
    final id = match == null ? null : int.tryParse(match[1]!);
    if (id == null) return false;
    pending.value = id;
    return true;
  }
}
