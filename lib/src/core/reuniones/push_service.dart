import 'notifications_navigation.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/app_config.dart';
import '../network/mobile_api_client.dart';
import 'reunion_navigation.dart';
import 'comunicados_navigation.dart';
import 'reunion_reminders.dart';

const pushTypes = {
  'reunion_nueva',
  'reunion_cambio',
  'reunion_cancelada',
  'reunion_reactivada',
  'reunion_horario',
  'recordatorio',
  'prueba',
  // Contrato 1.44.0: con la app abierta Firebase no muestra nada; sin estos
  // tipos el aviso se descartaba en primer plano.
  'comunicado',
  'salida_pendiente',
  'epp_resuelto',
  'epp_entregado',
  'reintegro',
  'reintegro_recordatorio',
  'adelanto',
  'pedido_mercaderia',
  // Contrato 1.48.0: todos los avisos al empleado pasan por push.
  'justificacion',
  'vacaciones',
  'vacaciones_inicio',
  'vacaciones_equipo',
  'feedback_asignado',
  'feedback_resuelto',
  'trivia_nueva',
  'trivia_recordatorio',
  'revision_pendiente',
  // Contrato 1.49.0: Seguridad e Higiene.
  'seguridad_resultado',
  'seguridad_accion',
  // Contrato 1.54.0: ingreso sin fichar (al empleado y a su jefe directo).
  'ingreso_pendiente',
  'ingreso_equipo',
};

/// Contrato 1.47.0: avisa al servidor que el push llego (`recibido`) o que lo
/// tocaron (`abierto`). Sin JWT ni reintentos: un acuse perdido solo deja el
/// aviso como "Enviado" en el panel.
Future<void> acknowledgePush(
  RemoteMessage message,
  String event, {
  MobileApiClient? api,
}) async {
  final envioId = message.data['envio_id']?.toString() ?? '';
  final signature = message.data['acuse']?.toString() ?? '';
  if (envioId.isEmpty || signature.isEmpty) return;
  final config = AppConfig.current;
  if (api == null && config.apiBaseUrl.isEmpty) return;
  final client =
      api ??
      MobileApiClient(
        baseUrl: config.apiBaseUrl,
        mobileApiPrefix: config.mobileApiPrefix,
      );
  try {
    await client.acknowledgePush(
      envioId: envioId,
      signature: signature,
      event: event,
    );
  } catch (_) {
    /* Best effort: never block or retry a receipt. */
  }
}

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification messages are displayed by Android. Do not show them twice;
  // only confirm the delivery (runs even with the app closed).
  await acknowledgePush(message, 'recibido');
}

class PushService {
  PushService._();
  static final instance = PushService._();
  final status = ValueNotifier<String>('Notificaciones sin verificar');
  final foreground = StreamController<RemoteMessage>.broadcast();
  MobileApiClient? _api;
  String? _jwt, _deviceToken;
  int? _owner;
  bool active = false;
  bool _listening = false;
  int _generation = 0;
  Future<void> _tail = Future.value();
  final _acknowledged = <String>{};
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'push_device_token_v1';

  bool get supported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  Future<void> _enqueue(Future<void> Function() action) {
    final task = _tail.then((_) => action()).catchError((Object _) {
      status.value =
          'No se pudieron conectar las notificaciones. Volvé a intentar.';
    });
    _tail = task;
    return task;
  }

  Future<void> bind(MobileApiClient api, String jwt, int owner) {
    if (!supported || jwt.startsWith('offline_')) return Future.value();
    if (_owner == owner && _jwt == jwt) return Future.value();
    final oldOwner = _owner;
    final oldJwt = _jwt;
    final oldApi = _api;
    _api = api;
    _jwt = jwt;
    _owner = owner;
    final generation = ++_generation;
    return _enqueue(() async {
      if (oldOwner != null && oldOwner != owner) {
        try {
          await _remove(oldApi, oldJwt);
        } catch (_) {
          /* Old token is revoked where possible. */
        }
        ReunionNavigation.pending.value = null;
        ComunicadosNavigation.pending.value = null;
      }
      if (generation != _generation) return;
      await _connect(generation);
    });
  }

  Future<void> refresh() => _enqueue(() => _connect(_generation));

  Future<void> _connect(int generation) async {
    final api = _api;
    final jwt = _jwt;
    if (!supported || api == null || jwt == null) return;
    final config = await api.getPushConfig(token: jwt);
    if (generation != _generation) return;
    final wasActive = active;
    active = config['activo'] == true;
    await ReunionReminders.instance.setPushActive(active);
    if (wasActive != active) ReunionNavigation.refresh.value++;
    if (!active) {
      status.value =
          'Push desactivado por el servidor. Se usan recordatorios locales.';
      return;
    }
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        final web = Map<String, dynamic>.from(config['web'] as Map);
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: web['apiKey'] as String,
            appId: web['appId'] as String,
            messagingSenderId: web['messagingSenderId'] as String,
            projectId: web['projectId'] as String,
            authDomain: web['authDomain'] as String?,
            storageBucket: web['storageBucket'] as String?,
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    }
    if (generation != _generation) return;
    final messaging = FirebaseMessaging.instance;
    if (!await messaging.isSupported()) {
      status.value =
          'Este dispositivo o navegador no admite notificaciones push.';
      return;
    }
    await ReunionReminders.instance.prepareChannel();
    if (!_listening) {
      _listening = true;
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
      }
      messaging.onTokenRefresh.listen(
        (token) {
          final g = _generation;
          unawaited(_enqueue(() => _register(token, g)));
        },
        onError: (Object _) {
          status.value = 'No se pudo renovar el registro de notificaciones.';
        },
      );
      FirebaseMessaging.onMessage.listen(_receive);
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await messaging.getInitialMessage();
      if (initial != null && generation == _generation) _open(initial);
    }
    var permission = await messaging.getNotificationSettings();
    // Browser prompts must originate from a user gesture, never startup.
    if (permission.authorizationStatus == AuthorizationStatus.notDetermined &&
        !kIsWeb) {
      permission = await messaging.requestPermission();
    }
    if (generation != _generation) return;
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      status.value =
          'Notificaciones desactivadas. Activá los avisos o revisá los permisos en Ajustes.';
      return;
    }
    final token = await messaging.getToken(
      vapidKey: kIsWeb ? config['vapid_key'] as String? : null,
    );
    if (token != null) await _register(token, generation);
  }

  Future<bool> enable() async {
    // Called from the button after config/init, preserving browser user activation.
    if (active && Firebase.apps.isNotEmpty) {
      await FirebaseMessaging.instance.requestPermission();
    }
    await refresh();
    return status.value == 'Notificaciones conectadas';
  }

  Future<void> _register(String token, int generation) async {
    if (generation != _generation || !active || _jwt == null || _api == null) {
      return;
    }
    final info = await PackageInfo.fromPlatform();
    if (generation != _generation) return;
    _deviceToken = token;
    await _storage.write(key: _tokenKey, value: token);
    if (generation != _generation) return;
    await _api!.registerPushDevice(
      token: _jwt!,
      deviceToken: token,
      platform: kIsWeb ? 'web' : 'android',
      appVersion: '${info.version}+${info.buildNumber}',
    );
    if (generation == _generation) status.value = 'Notificaciones conectadas';
  }

  void _acknowledge(RemoteMessage message, String event) {
    if (!_acknowledged.add('${message.data['envio_id']}:$event')) return;
    unawaited(acknowledgePush(message, event, api: _api));
  }

  void openMessage(RemoteMessage message) => _open(message);

  void _open(RemoteMessage message) {
    _acknowledge(message, 'abierto');
    if (_owner == null || !pushTypes.contains(message.data['tipo'])) return;
    if (message.data['notificacion_id'] != null) {
      NotificationsNavigation.open(message.data['notificacion_id']);
    } else {
      if (NotificationsNavigation.openRoute(message.data['ruta'] as String?)) {
        return;
      }
      ReunionNavigation.open(message.data['ruta'] as String?);
      if (!(message.data['ruta']?.toString().startsWith('/reuniones') ??
              false) &&
          !(message.data['ruta']?.toString().startsWith('/comunicados') ??
              false) &&
          !NotificationsNavigation.openHome(message.data['tipo'])) {
        NotificationsNavigation.open(0);
      }
    }
  }

  void _receive(RemoteMessage message) {
    _acknowledge(message, 'recibido');
    if (_owner == null ||
        !active ||
        !pushTypes.contains(message.data['tipo'])) {
      return;
    }
    NotificationsNavigation.refresh.value++;
    ReunionNavigation.refresh.value++;
    if (message.data['tipo'] == 'comunicado') {
      ComunicadosNavigation.refresh.value++;
    }
    foreground.add(message);
    if (!kIsWeb) {
      unawaited(
        ReunionReminders.instance
            .showPush(
              (message.messageId ?? DateTime.now().toString()).hashCode &
                  0x7fffffff,
              message.notification?.title ?? 'FichaYa',
              message.notification?.body ?? '',
              meetingIdFromRoute(message.data['ruta'] as String?),
              route: message.data['ruta'] as String?,
              notificationId: int.tryParse(
                '${message.data['notificacion_id']}',
              ),
              receipt: message.data,
              urgent: urgentPushTypes.contains(message.data['tipo']),
            )
            .catchError((Object _) {}),
      );
    }
  }

  Future<void> _remove(MobileApiClient? api, String? jwt) async {
    final deviceToken = _deviceToken ?? await _storage.read(key: _tokenKey);
    _deviceToken = null;
    try {
      if (api != null && jwt != null && deviceToken != null) {
        await api.removePushDevice(token: jwt, deviceToken: deviceToken);
      }
    } finally {
      if (Firebase.apps.isNotEmpty && supported) {
        await FirebaseMessaging.instance.deleteToken();
      }
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<void> disconnect() {
    final api = _api;
    final jwt = _jwt;
    _generation++;
    _owner = null;
    NotificationsNavigation.pending.value = null;
    NotificationsNavigation.route.value = null;
    _jwt = null;
    _api = null;
    active = false;
    ReunionNavigation.pending.value = null;
    ComunicadosNavigation.pending.value = null;
    return _enqueue(() async {
      try {
        await _remove(api, jwt);
      } finally {
        await ReunionReminders.instance.setPushActive(false);
        status.value = 'Notificaciones sin sesión';
      }
    });
  }
}
