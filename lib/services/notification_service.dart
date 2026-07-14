import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../pages/breath_test_page.dart';
import 'phone_state_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;
    tz.initializeTimeZones();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final context = _navigatorKey?.currentContext;
        if (context != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BreathTestPage()),
          );
        }
      },
    );
  }

  static Future<void> scheduleDailyBreathReminder({required String sleepTime}) async {
    final parts = sleepTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 21;
    final minute = int.tryParse(parts[1]) ?? 0;
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    scheduledDate = scheduledDate.subtract(const Duration(minutes: 45));
    var finalDate = scheduledDate.isBefore(now)
        ? scheduledDate.add(const Duration(days: 1))
        : scheduledDate;

    final isDriving = await _isLikelyDrivingNow();
    if (isDriving) {
      finalDate = finalDate.add(const Duration(minutes: 20));
    }

    await _plugin.zonedSchedule(
      0,
      'Nefes Testi',
      isDriving
          ? 'Sürüşte güvenliğiniz için hatırlatma kısa süre ertelendi.'
          : 'Günlük nefes testi zamanı geldi.',
      finalDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'breath_reminder_channel',
          'Nefes testi hatırlatıcı',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleTaskFollowUpReminder({
    required String taskTitle,
    Duration delay = const Duration(minutes: 30),
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var fireAt = now.add(delay);
    final isDriving = await _isLikelyDrivingNow();
    if (isDriving) {
      fireAt = fireAt.add(const Duration(minutes: 20));
    }

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    await _plugin.zonedSchedule(
      notificationId,
      'Görev Takibi',
      isDriving
          ? 'Sürüş bitince görevi değerlendirin: $taskTitle'
          : 'Görev sonucu hazır mı? $taskTitle',
      fireAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_followup_channel',
          'Görev takip hatırlatıcı',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<bool> _isLikelyDrivingNow() async {
    try {
      final summary = await PhoneStateService().inferDailyStateSummary();
      return summary['drivingPrediction'] == 'driving';
    } catch (_) {
      return false;
    }
  }
}
