import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../pages/breath_test_page.dart';
import 'language_service.dart';
import 'phone_state_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService.handleBackgroundNotificationResponse(response);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
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
  static const String _taskStartChannelId = 'task_start_channel_v4';
  static const String _taskFollowUpChannelId = 'task_followup_channel_v5';
  static const String _taskEscalationChannelId = 'task_escalation_channel_v1';
  static const String _breathReminderChannelId = 'breath_reminder_channel_v3';
  static const int _notificationTimeoutMs = 10000;
  static const Duration _unansweredReminderDelay = Duration(minutes: 10);
  static final Int64List _taskVibrationPattern = Int64List.fromList(<int>[
    0,
    1000,
    500,
    1000,
    500,
    1000,
    500,
    1000,
    500,
    1000,
    500,
    1000,
  ]);

  static Stream<Map<String, String>> get taskActionStream =>
      _taskActionController.stream;

  static Future<void> initialize({
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    final code = await LanguageService.loadSelectedLanguageCode();
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
                _text(code, 'taskActionDone'),
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _actionTaskNotNow,
                _text(code, 'taskActionNotNow'),
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
          DarwinNotificationCategory(
            _categoryTaskFollowUp,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _actionSmokedYes,
                _text(code, 'yes'),
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _actionSmokedNo,
                _text(code, 'no'),
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
        ],
      ),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request runtime notification permission (Android 13+ and iOS).
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    try {
      final canScheduleExact =
          await androidPlugin.canScheduleExactNotifications() ?? false;
      if (canScheduleExact) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }

      final granted = await androidPlugin.requestExactAlarmsPermission();
      if (granted == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      // Fallback to inexact scheduling on unsupported devices/APIs.
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    _processNotificationResponse(response, allowNavigation: true);
  }

  static void handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) {
    _processNotificationResponse(response, allowNavigation: false);
  }

  static void _processNotificationResponse(
    NotificationResponse response, {
    required bool allowNavigation,
  }) {
    final payload = _decodePayload(response.payload);
    if (payload == null) {
      return;
    }

    final reminderId = int.tryParse(payload['reminderId'] ?? '');
    if (reminderId != null) {
      unawaited(_plugin.cancel(reminderId));
    }

    final type = payload['type'];
    if (type == _typeBreath && allowNavigation) {
      final context = _navigatorKey?.currentContext;
      if (context != null) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const BreathTestPage()));
      }
      return;
    }

    if (type == _typeTaskStart || type == _typeTaskFollowUp) {
      final actionId = response.actionId;
      final event = {
        'type': type ?? '',
        'taskTitle': payload['taskTitle'] ?? '',
        'actionId': actionId ?? '',
      };

      if (_taskActionController.hasListener) {
        _taskActionController.add(event);
      } else {
        unawaited(_handleActionWithoutUi(event));
      }
    }
  }

  static Future<void> _handleActionWithoutUi(Map<String, String> event) async {
    final taskTitle = event['taskTitle']?.trim() ?? '';
    final actionId = event['actionId']?.trim() ?? '';
    if (taskTitle.isEmpty || actionId.isEmpty) {
      return;
    }

    if (actionId == _actionTaskDone) {
      final delay = _resolveInitialTaskDelay(taskTitle);
      await showTaskTimerStartedNotification(
        taskTitle: taskTitle,
        duration: delay,
      );
      await scheduleTaskFollowUpReminder(taskTitle: taskTitle, delay: delay);
      return;
    }

    if (actionId == _actionTaskNotNow) {
      await scheduleFirstTaskTriggerNotification(
        taskDescription: taskTitle,
        delay: const Duration(minutes: 10),
      );
    }
  }

  static Map<String, String>? _decodePayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return null;
    }
  }

  static int _deriveReminderId(int sourceId) {
    return (sourceId + 1000000000).remainder(2147483647);
  }

  static Duration _resolveInitialTaskDelay(String taskTitle) {
    final minuteMatch = RegExp(
      r'(\d+)\s*(dakika|minute|minutes|min)',
      caseSensitive: false,
    ).firstMatch(taskTitle);
    if (minuteMatch != null) {
      final minutes = int.tryParse(minuteMatch.group(1) ?? '');
      if (minutes != null && minutes > 0) {
        return Duration(minutes: minutes);
      }
    }

    final hourMatch = RegExp(
      r'(\d+)\s*(saat|hour|hours)',
      caseSensitive: false,
    ).firstMatch(taskTitle);
    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1) ?? '');
      if (hours != null && hours > 0) {
        return Duration(hours: hours);
      }
    }

    return const Duration(minutes: 30);
  }

  static Future<void> _scheduleUnansweredTaskUpdateReminder({
    required String taskTitle,
    required String type,
    required int reminderId,
    required tz.TZDateTime triggerAt,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final scheduleMode = await _resolveAndroidScheduleMode();
    await _plugin.zonedSchedule(
      reminderId,
      _text(code, 'taskEscalationTitle'),
      '${_text(code, 'taskEscalationBodyPrefix')}\n$taskTitle',
      triggerAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskEscalationChannelId,
          'Gorev guncelleme hatirlatici',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          timeoutAfter: _notificationTimeoutMs,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionTaskDone,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionTaskNotNow,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskStart,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': type, 'taskTitle': taskTitle}),
    );
  }

  static Future<void> showFirstTaskTriggerNotification({
    required String taskTitle,
    required String taskDescription,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final reminderId = _deriveReminderId(id);
    await _plugin.show(
      id,
      taskTitle,
      taskDescription,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          'İlk görev tetikleme',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          autoCancel: true,
          onlyAlertOnce: false,
          timeoutAfter: _notificationTimeoutMs,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionTaskDone,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionTaskNotNow,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskStart,
        ),
      ),
      payload: jsonEncode({
        'type': _typeTaskStart,
        'taskTitle': taskTitle,
        'reminderId': '$reminderId',
      }),
    );

    final reminderAt = tz.TZDateTime.now(
      tz.local,
    ).add(_unansweredReminderDelay);
    await _scheduleUnansweredTaskUpdateReminder(
      taskTitle: taskTitle,
      type: _typeTaskStart,
      reminderId: reminderId,
      triggerAt: reminderAt,
    );
  }

  static Future<void> scheduleFirstTaskTriggerNotification({
    required String taskDescription,
    Duration delay = const Duration(minutes: 10),
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final scheduleMode = await _resolveAndroidScheduleMode();
    final now = tz.TZDateTime.now(tz.local);
    final fireAt = now.add(delay);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final reminderId = _deriveReminderId(id);
    await _plugin.zonedSchedule(
      id,
      _text(code, 'taskStartTitle'),
      taskDescription,
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          'İlk görev tetikleme',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          autoCancel: true,
          onlyAlertOnce: false,
          timeoutAfter: _notificationTimeoutMs,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionTaskDone,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionTaskNotNow,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskStart,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': _typeTaskStart,
        'taskTitle': taskDescription,
        'reminderId': '$reminderId',
      }),
    );

    await _scheduleUnansweredTaskUpdateReminder(
      taskTitle: taskDescription,
      type: _typeTaskStart,
      reminderId: reminderId,
      triggerAt: fireAt.add(_unansweredReminderDelay),
    );
  }

  static Future<void> scheduleDailyBreathReminder({
    required String sleepTime,
  }) async {
    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final parts = sleepTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 21;
    final minute = int.tryParse(parts[1]) ?? 0;
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
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
          _breathReminderChannelId,
          'Nefes testi hatırlatıcı',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': _typeBreath}),
    );
  }

  static Future<void> scheduleTaskFollowUpReminder({
    required String taskTitle,
    Duration delay = const Duration(minutes: 30),
  }) async {
    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);
    var fireAt = now.add(delay);
    final isDriving = await _isLikelyDrivingNow();
    if (isDriving) {
      fireAt = fireAt.add(const Duration(minutes: 20));
    }

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      2147483647,
    );
    final reminderId = _deriveReminderId(notificationId);

    await _plugin.zonedSchedule(
      notificationId,
      _text(code, 'taskFollowUpTitlePush'),
      isDriving
          ? _text(code, 'taskFollowUpQuestionDriving')
          : '${_text(code, 'taskFollowUpQuestion')}\n$taskTitle',
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskFollowUpChannelId,
          'Görev takip hatırlatıcı',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          autoCancel: true,
          onlyAlertOnce: false,
          timeoutAfter: _notificationTimeoutMs,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionSmokedYes,
              _text(code, 'taskFollowUpActionYes'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionSmokedNo,
              _text(code, 'taskFollowUpActionNo'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskFollowUp,
          presentSound: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': _typeTaskFollowUp,
        'taskTitle': taskTitle,
        'reminderId': '$reminderId',
      }),
    );

    await _scheduleUnansweredTaskUpdateReminder(
      taskTitle: taskTitle,
      type: _typeTaskFollowUp,
      reminderId: reminderId,
      triggerAt: fireAt.add(_unansweredReminderDelay),
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
          _taskStartChannelId,
          'Task timer start',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
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
      'yes': 'Evet',
      'no': 'Hayır',
      'taskActionDone': 'Tamam',
      'taskActionNotNow': 'Şimdi Uygun Değil',
      'taskActionDoneLabel': 'Tamam',
      'taskActionNotNowLabel': 'Simdi uygun degil',
      'taskFollowUpActionYes': 'Evet',
      'taskFollowUpActionNo': 'Hayir',
      'taskStartTitle': 'Gorev Hatirlatmasi',
      'breathReminderTitle': 'Nefes Testi',
      'breathReminderBody': 'Günlük nefes testi zamanı geldi.',
      'breathReminderDriving':
          'Sürüşte güvenliğiniz için hatırlatma kısa süre ertelendi.',
      'taskFollowUpTitlePush': 'Görev Takibi',
      'taskFollowUpQuestion': 'Gorevi basariyla tamamladiniz mi?',
      'taskFollowUpQuestionDriving':
          'Surus sonrasi cevaplayin: Gorevi basariyla tamamladiniz mi?',
      'taskTimerStartedTitle': 'İlk Görev',
      'taskTimerStartedBody': 'Görev başladı:',
      'taskEscalationTitle': 'Gorev guncellendi',
      'taskEscalationBodyPrefix':
          '10 saniye icinde yanit alinmadi. 10 dakika sonra guncel gorev hatirlatmasi:',
      'taskTimerDuration': 'Sayaç',
      'minutesShort': 'dakika',
    };

    const en = <String, String>{
      'yes': 'Yes',
      'no': 'No',
      'taskActionDone': 'Complete',
      'taskActionNotNow': 'Not now',
      'taskActionDoneLabel': 'Complete',
      'taskActionNotNowLabel': 'Not now',
      'taskFollowUpActionYes': 'Yes',
      'taskFollowUpActionNo': 'No',
      'taskStartTitle': 'Task Reminder',
      'breathReminderTitle': 'Breath Test',
      'breathReminderBody': 'Time for your daily breath test.',
      'breathReminderDriving': 'Reminder delayed briefly for driving safety.',
      'taskFollowUpTitlePush': 'Task Follow-up',
      'taskFollowUpQuestion': 'Did you complete the task successfully?',
      'taskFollowUpQuestionDriving':
          'Answer after driving: Did you complete the task successfully?',
      'taskTimerStartedTitle': 'First Task',
      'taskTimerStartedBody': 'Task started:',
      'taskEscalationTitle': 'Task updated',
      'taskEscalationBodyPrefix':
          'No response in 10 seconds. Updated task reminder after 10 minutes:',
      'taskTimerDuration': 'Timer',
      'minutesShort': 'minutes',
    };

    final map = code == 'tr' ? tr : en;
    return map[key] ?? en[key] ?? key;
  }
}
