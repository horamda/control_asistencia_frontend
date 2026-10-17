import 'package:flutter/foundation.dart';
import 'comunicados_navigation.dart';

/// Only internal meeting routes are accepted, never arbitrary notification URLs.
int? meetingIdFromRoute(String? route) {
  if (route == null) return null;
  final match = RegExp(r'^/reuniones/([1-9][0-9]*)/?$').firstMatch(route);
  return match == null ? null : int.tryParse(match[1]!);
}

class ReunionNavigation {
  static final pending = ValueNotifier<int?>(null);
  static final refresh = ValueNotifier<int>(0);
  static void open(String? route) {
    if (ComunicadosNavigation.open(route)) return;
    final id = route == '/reuniones' || route == '/reuniones/'
        ? 0
        : meetingIdFromRoute(route);
    if (id != null) pending.value = id;
  }

  static void fromLocal(String? payload, int? owner) {
    final parts = payload?.split(':');
    if (parts == null ||
        parts.length != 4 ||
        (parts[0] != 'reunion' && parts[0] != 'comunicado') ||
        owner == null ||
        parts[1] != '$owner') {
      return;
    }
    open(
      '/${parts[0] == 'comunicado' ? 'comunicados' : 'reuniones'}/${parts[2]}',
    );
  }
}
