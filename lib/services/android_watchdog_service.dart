import 'dart:io';

import 'package:flutter/services.dart';

class AndroidWatchdogService {
  static const MethodChannel _channel = MethodChannel('no_smoke/watchdog');

  static bool get _isAndroid => Platform.isAndroid;

  static Future<void> startWatchdog({
    required String taskTitle,
    required String watchdogId,
    required DateTime dueAt,
  }) async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod('startWatchdog', {
      'taskTitle': taskTitle,
      'watchdogId': watchdogId,
      'dueAtMillis': dueAt.millisecondsSinceEpoch,
    });
  }

  static Future<void> acknowledgeWatchdog(String watchdogId) async {
    if (!_isAndroid || watchdogId.trim().isEmpty) {
      return;
    }
    await _channel.invokeMethod('ackWatchdog', {'watchdogId': watchdogId});
  }

  static Future<List<Map<String, dynamic>>> consumeViolations() async {
    if (!_isAndroid) {
      return const [];
    }

    final raw = await _channel.invokeMethod<List<dynamic>>(
      'consumeWatchdogViolations',
    );
    if (raw == null) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map((entry) => entry.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList();
  }
}
