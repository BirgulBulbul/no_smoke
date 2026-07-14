import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../pages/breath_test_page.dart';
import 'language_service.dart';
import 'phone_state_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static final StreamController<Map<String, String>> _taskActionController =
      StreamController<Map<String, String>>.broadcast();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static const String _typeBreath = 'breath';
  static const String _typeTaskStart = 'task_start';
  static const String _typeTaskFollowUp = 'task_followup';

  static const String _actionTaskDone = 'task_done';
  static const String _actionTaskNotNow = 'task_not_now';
  static const String _actionSmokedYes = 'smoked_yes';
  static const String _actionSmokedNo = 'smoked_no';

  static const String _categoryTaskStart = 'task_start_category';
  static const String _categoryTaskFollowUp = 'task_followup_category';

  static Stream<Map<String, String>> get taskActionStream => _taskActionController.stream;

  static Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;
    tz.initializeTimeZones();
    final initSettings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            _categoryTaskStart,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _actionTaskDone,
                'Tamam',
                options: <DarwinNotificationActionOption>{DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                _actionTaskNotNow,
                'Şimdi Uygun Değil',
                options: <DarwinNotificationActionOption>{DarwinNotificationActionOption.foreground},
              ),
            ],
          ),
          DarwinNotificationCategory(
            _categoryTaskFollowUp,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _actionSmokedYes,
                'Evet',
                options: <DarwinNotificationActionOption>{DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                _actionSmokedNo,
                'Hayır',
                options: <DarwinNotificationActionOption>{DarwinNotificationActionOption.foreground},
              ),
            ],
          ),
        ],
      ),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    final payload = _decodePayload(response.payload);
    if (payload == null) {
      return;
    }

    final type = payload['type'];
    if (type == _typeBreath) {
      final context = _navigatorKey?.currentContext;
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BreathTestPage()),
        );
      }
      return;
    }

    if (type == _typeTaskStart || type == _typeTaskFollowUp) {
      final actionId = response.actionId;
      _taskActionController.add(
        {
          'type': type ?? '',
          'taskTitle': payload['taskTitle'] ?? '',
          'actionId': actionId ?? '',
        },
      );
    }
  }

  static Map<String, String>? _decodePayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return null;
    }
  }

  static Future<void> showFirstTaskTriggerNotification({
    required String taskTitle,
    required String taskDescription,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    await _plugin.show(
      id,
      taskTitle,
      taskDescription,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_start_channel',
          'İlk görev tetikleme',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              _actionTaskDone,
              'Tamam',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              _actionTaskNotNow,
              'Şimdi Uygun Değil',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskStart,
        ),
      ),
      payload: jsonEncode(
        {
          'type': _typeTaskStart,
          'taskTitle': taskTitle,
        },
      ),
    );
  }

  static Future<void> scheduleFirstTaskTriggerNotification({
    required String taskDescription,
    Duration delay = const Duration(minutes: 10),
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final fireAt = now.add(delay);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    await _plugin.zonedSchedule(
      id,
      'İlk Görev',
      taskDescription,
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_start_channel',
          'İlk görev tetikleme',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              _actionTaskDone,
              'Tamam',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              _actionTaskNotNow,
              'Şimdi Uygun Değil',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskStart,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(
        {
          'type': _typeTaskStart,
          'taskTitle': taskDescription,
        },
      ),
    );
  }

  static Future<void> scheduleDailyBreathReminder({required String sleepTime}) async {
    final code = await LanguageService.loadSelectedLanguageCode();
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
      _text(code, 'breathReminderTitle'),
      isDriving
        ? _text(code, 'breathReminderDriving')
        : _text(code, 'breathReminderBody'),
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
      payload: jsonEncode({'type': _typeBreath}),
    );
  }

  static Future<void> scheduleTaskFollowUpReminder({
    required String taskTitle,
    Duration delay = const Duration(minutes: 30),
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);
    var fireAt = now.add(delay);
    final isDriving = await _isLikelyDrivingNow();
    if (isDriving) {
      fireAt = fireAt.add(const Duration(minutes: 20));
    }

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    await _plugin.zonedSchedule(
      notificationId,
      _text(code, 'taskFollowUpTitlePush'),
      isDriving
        ? _text(code, 'taskFollowUpQuestionDriving')
        : '${_text(code, 'taskFollowUpQuestion')}\n$taskTitle',
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_followup_channel',
          'Görev takip hatırlatıcı',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              _actionSmokedYes,
              'Evet',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              _actionSmokedNo,
              'Hayır',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskFollowUp,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(
        {
          'type': _typeTaskFollowUp,
          'taskTitle': taskTitle,
        },
      ),
    );
  }

  static Future<void> showTaskTimerStartedNotification({
    required String taskTitle,
    required Duration duration,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    await _plugin.show(
      id,
      _text(code, 'taskTimerStartedTitle'),
      '${_text(code, 'taskTimerStartedBody')}\n$taskTitle\n${_text(code, 'taskTimerDuration')}: ${duration.inMinutes} ${_text(code, 'minutesShort')}.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_start_channel',
          'Task timer start',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
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

  static String _text(String code, String key) {
    const tr = <String, String>{
      'breathReminderTitle': 'Nefes Testi',
      'breathReminderBody': 'Günlük nefes testi zamanı geldi.',
      'breathReminderDriving': 'Sürüşte güvenliğiniz için hatırlatma kısa süre ertelendi.',
      'taskFollowUpTitlePush': 'Görev Takibi',
      'taskFollowUpQuestion': 'Bu süre boyunca sigara içtiniz mi?',
      'taskFollowUpQuestionDriving': 'Sürüş sonrası cevaplayın: Bu süre boyunca sigara içtiniz mi?',
      'taskTimerStartedTitle': 'İlk Görev',
      'taskTimerStartedBody': '15 dakikalık görev başladı:',
      'taskTimerDuration': 'Sayaç',
      'minutesShort': 'dakika',
    };

    const en = <String, String>{
      'breathReminderTitle': 'Breath Test',
      'breathReminderBody': 'Time for your daily breath test.',
      'breathReminderDriving': 'Reminder delayed briefly for driving safety.',
      'taskFollowUpTitlePush': 'Task Follow-up',
      'taskFollowUpQuestion': 'Did you smoke during this period?',
      'taskFollowUpQuestionDriving': 'Answer after driving: Did you smoke during this period?',
      'taskTimerStartedTitle': 'First Task',
      'taskTimerStartedBody': 'Your 15-minute task has started:',
      'taskTimerDuration': 'Timer',
      'minutesShort': 'minutes',
    };

    final map = code == 'tr' ? tr : en;
    return map[key] ?? en[key] ?? key;
  }
}
