import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../network/reuniones_models.dart';
import 'reunion_navigation.dart';

class ReunionReminder {
  ReunionReminder(this.occurrence, this.at);
  final ReunionOccurrence occurrence;
  final DateTime at;
  int get id {
    // Stable positive 31-bit FNV hash, unlike String.hashCode across runs.
    var hash = 2166136261;
    for (final c in occurrence.key.codeUnits) {
      hash = ((hash ^ c) * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}

List<ReunionReminder> planReunionReminders(
  List<ReunionOccurrence> items,
  DateTime now,
) {
  final unique = <String, ReunionReminder>{};
  for (final item in items) {
    if (item.cancelada || item.estado != 'pendiente') continue;
    final at = item.inicio.subtract(const Duration(minutes: 30));
    if (at.isAfter(now)) unique[item.key] = ReunionReminder(item, at);
  }
  final result = unique.values.toList()..sort((a, b) => a.at.compareTo(b.at));
  return result;
}

// Canal con el tono de FichaYa (res/raw/fichaya.wav). En Android 8+ el sonido
// queda fijo al crear el canal: para cambiar el tono hay que usar otro id (y
// actualizar CANAL_ANDROID en el backend). El canal viejo 'reuniones' se deja.
const fichayaChannelId = 'fichaya';
const _fichayaChannelName = 'Avisos de FichaYa';
const _fichayaChannelDescription =
    'Avisos, comunicados y recordatorios de FichaYa';
const _fichayaSound = RawResourceAndroidNotificationSound('fichaya');

// Canal de urgentes (salida sin fichar, reunion por empezar): prioridad maxima y
// vibracion mas larga. Debe coincidir con CANAL_ANDROID_URGENTE del backend.
const fichayaUrgentChannelId = 'fichaya_urgente';
const _urgentChannelName = 'Avisos urgentes de FichaYa';
const _urgentChannelDescription =
    'Ingreso o salida sin fichar y reunión por empezar';
const urgentPushTypes = {
  'salida_pendiente',
  'recordatorio',
  'ingreso_pendiente',
  'ingreso_equipo',
};

// Vibracion propia (ms: espera, vibra, pausa, vibra...). Como el sonido, queda
// fija al crear el canal: avisos, dos pulsos cortos; urgentes, tres largos.
final _fichayaVibration = Int64List.fromList([0, 180, 120, 180]);
final _urgentVibration = Int64List.fromList([0, 450, 200, 450, 200, 450]);

NotificationDetails _details({required bool urgent}) => NotificationDetails(
  android: AndroidNotificationDetails(
    urgent ? fichayaUrgentChannelId : fichayaChannelId,
    urgent ? _urgentChannelName : _fichayaChannelName,
    channelDescription: urgent
        ? _urgentChannelDescription
        : _fichayaChannelDescription,
    importance: urgent ? Importance.max : Importance.high,
    priority: urgent ? Priority.max : Priority.high,
    sound: _fichayaSound,
    enableVibration: true,
    vibrationPattern: urgent ? _urgentVibration : _fichayaVibration,
    category: urgent ? AndroidNotificationCategory.reminder : null,
  ),
  iOS: const DarwinNotificationDetails(),
);

class ReunionReminders {
  ReunionReminders._();
  static final instance = ReunionReminders._();
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  Future<void> _tail = Future.value();
  int _generation = 0;
  int? _owner;
  bool _ownerKnown = false;
  bool _pushActive = false;
  String? _launchPayload;
  Future<void> setPushActive(bool value) async {
    _pushActive = value;
    if (value) await clear();
  }

  Future<void> prepareChannel() async {
    if (!supported) return;
    await _initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        fichayaChannelId,
        _fichayaChannelName,
        description: _fichayaChannelDescription,
        importance: Importance.high,
        sound: _fichayaSound,
        enableVibration: true,
        vibrationPattern: _fichayaVibration,
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        fichayaUrgentChannelId,
        _urgentChannelName,
        description: _urgentChannelDescription,
        importance: Importance.max,
        sound: _fichayaSound,
        enableVibration: true,
        vibrationPattern: _urgentVibration,
      ),
    );
  }

  Future<void> showPush(
    int id,
    String title,
    String body,
    int? meetingId, {
    String? route,
    int? notificationId,
    bool urgent = false,
    Map<String, dynamic>? receipt,
  }) async {
    if (!supported) return;
    await prepareChannel();
    await _plugin.show(
      id,
      title,
      body,
      _details(urgent: urgent),
      payload: receipt != null
          ? jsonEncode({'owner': _owner, 'data': receipt})
          : notificationId != null
          ? 'notificacion:$_owner:$notificationId:push'
          : RegExp(r'^/comunicados/[1-9][0-9]*/?$').hasMatch(route ?? '')
          ? 'comunicado:$_owner:${route!.split('/')[2]}:push'
          : meetingId == null
          ? null
          : 'reunion:$_owner:$meetingId:push',
    );
  }

  static const _prefix = 'reunion:';

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _initialize() => _initializing ??= () async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_reunion'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          ReunionNavigation.fromLocal(response.payload, _owner),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _launchPayload = launch?.notificationResponse?.payload;
      if (_owner != null) {
        ReunionNavigation.fromLocal(_launchPayload, _owner);
        _launchPayload = null;
      }
    }
  }();

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<void> _cancelMeetings({int? keepOwner}) async {
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (pending.payload?.startsWith(_prefix) == true &&
          (keepOwner == null ||
              !pending.payload!.startsWith('$_prefix$keepOwner:'))) {
        await _plugin.cancel(pending.id);
      }
    }
  }

  Future<void> setOwner(int? employeeId) {
    if (_ownerKnown && _owner == employeeId) return Future.value();
    _ownerKnown = true;
    _owner = employeeId;
    if (!supported) return Future.value();
    final generation = ++_generation;
    final task = _tail.then((_) async {
      await _initialize();
      if (generation != _generation) return;
      ReunionNavigation.fromLocal(_launchPayload, employeeId);
      _launchPayload = null;
      // Keep this account's scheduled reminders on an offline app restart.
      await _cancelMeetings(keepOwner: employeeId);
    });
    _tail = task.catchError((Object _) {});
    return task;
  }

  Future<void> replace(List<ReunionOccurrence> items, {int? employeeId}) {
    if (employeeId != null && employeeId != _owner) return Future.value();
    if (!supported) return Future.value();
    final generation = ++_generation;
    final task = _tail.then((_) async {
      await _initialize();
      if (generation != _generation) return;
      await _cancelMeetings();
      final plan = planReunionReminders(
        _pushActive ? [] : items,
        DateTime.now(),
      );
      // Leave room below iOS's 64 pending notification limit.
      final scheduled = defaultTargetPlatform == TargetPlatform.iOS
          ? plan.take(60)
          : plan;
      for (final reminder in scheduled) {
        if (generation != _generation) return;
        await _plugin.zonedSchedule(
          reminder.id,
          reminder.occurrence.nombre,
          'En 30 minutos${reminder.occurrence.location.isEmpty ? '' : ' · ${reminder.occurrence.location}'}',
          tz.TZDateTime.from(reminder.at, tz.UTC),
          // La reunion empieza en 30 minutos: canal de urgentes.
          _details(urgent: true),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '$_prefix$_owner:${reminder.occurrence.key}',
        );
      }
    });
    _tail = task.catchError((Object _) {});
    return task;
  }

  Future<void> clear() => replace([]);
}
