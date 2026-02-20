import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const actionTaken = 'ACTION_TAKEN';
  static const actionSnooze = 'ACTION_SNOOZE';
  static const actionMissed = 'ACTION_MISSED';

  static const _channelId = 'med_reminders';
  static const _channelName = 'İlaç Hatırlatmaları';
  static const _channelDesc = 'İlaç doz hatırlatmaları';

  static Future<void> init({
    required void Function(int doseEventId, String actionId) onAction,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null) return;
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final id = int.parse(data['doseEventId'].toString());
        onAction(id, resp.actionId ?? '');
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse resp) {
    // MVP: background isolate DB setup yok.
  }

  static NotificationDetails _details() {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(actionTaken, 'Aldım'),
        AndroidNotificationAction(actionSnooze, 'Ertele 10dk'),
        AndroidNotificationAction(actionMissed, 'Atladım'),
      ],
    );

    const ios = DarwinNotificationDetails(
      categoryIdentifier: 'med_category',
    );

    return NotificationDetails(android: android, iOS: ios);
  }

  static Future<void> scheduleDose({
    required int notificationId,
    required int doseEventId,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    final payload = jsonEncode({'doseEventId': doseEventId});

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      when,
      _details(),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int notificationId) => _plugin.cancel(notificationId);
  static Future<void> cancelAll() => _plugin.cancelAll();
}
