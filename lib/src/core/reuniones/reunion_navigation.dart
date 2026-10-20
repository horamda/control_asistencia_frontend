import 'dart:async';
import 'dart:convert';
import '../../config/app_config.dart';
import '../network/mobile_api_client.dart';
import 'notifications_navigation.dart';
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
  static void fromWeb(Map<String, dynamic> data) {
    unawaited(_ackLocal(data));
    if (data['notificacion_id'] != null) {
      NotificationsNavigation.open(data['notificacion_id']);
    } else if (!NotificationsNavigation.openRoute(data['ruta']?.toString())) {
      final route = data['ruta']?.toString();
      if (route?.startsWith('/reuniones') == true ||
          route?.startsWith('/comunicados') == true) {
        open(route);
      } else {
        NotificationsNavigation.open(0);
      }
    }
  }

  static void open(String? route) {
    if (NotificationsNavigation.openRoute(route)) return;
    if (ComunicadosNavigation.open(route)) return;
    final id = route == '/reuniones' || route == '/reuniones/'
        ? 0
        : meetingIdFromRoute(route);
    if (id != null) pending.value = id;
  }

  static Future<void> _ackLocal(Map<String, dynamic> data) async {
    if (data['envio_id'] == null || data['acuse'] == null) return;
    final config = AppConfig.current;
    if (config.apiBaseUrl.isEmpty) return;
    final api = MobileApiClient(
      baseUrl: config.apiBaseUrl,
      mobileApiPrefix: config.mobileApiPrefix,
    );
    try {
      await api.acknowledgePush(
        envioId: '${data['envio_id']}',
        signature: '${data['acuse']}',
        event: 'abierto',
      );
    } catch (_) {
      /* Receipt failures must not block opening the message. */
    } finally {
      api.dispose();
    }
  }

  static void fromLocal(String? payload, int? owner) {
    if (payload?.startsWith('{') == true) {
      try {
        final decoded = jsonDecode(payload!) as Map;
        if (owner == null || decoded['owner'] != owner) return;
        final data = Map<String, dynamic>.from(decoded['data'] as Map);
        unawaited(_ackLocal(data));
        if (data['notificacion_id'] != null) {
          NotificationsNavigation.open(data['notificacion_id']);
        } else if (!NotificationsNavigation.openRoute(
          data['ruta']?.toString(),
        )) {
          final route = data['ruta']?.toString();
          if (route?.startsWith('/reuniones') == true ||
              route?.startsWith('/comunicados') == true) {
            open(route);
          } else {
            NotificationsNavigation.open(0);
          }
        }
      } catch (_) {
        /* Ignore invalid local payloads. */
      }
      return;
    }
    final parts = payload?.split(':');
    if (parts == null ||
        parts.length != 4 ||
        (parts[0] != 'reunion' &&
            parts[0] != 'comunicado' &&
            parts[0] != 'notificacion') ||
        owner == null ||
        parts[1] != '$owner') {
      return;
    }
    if (parts[0] == 'notificacion') {
      NotificationsNavigation.open(parts[2]);
      return;
    }
    open(
      '/${parts[0] == 'comunicado' ? 'comunicados' : 'reuniones'}/${parts[2]}',
    );
  }
}
