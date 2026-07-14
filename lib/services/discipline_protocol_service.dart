import 'dart:math';

import '../models/sensor_usage_event.dart';

class DisciplineProtocolService {
  final Random _random;

  DisciplineProtocolService({Random? random}) : _random = random ?? Random();

  double computeSuccessRate({
    required int successCount,
    required int failureCount,
  }) {
    final total = successCount + failureCount;
    if (total <= 0) {
      return 0.0;
    }
    return successCount / total;
  }

  Duration computeAdaptiveTaskDuration({
    required Duration baseDuration,
    required double successRate,
  }) {
    var extraMinutes = 0;
    if (successRate >= 0.85) {
      extraMinutes = 20;
    } else if (successRate >= 0.7) {
      extraMinutes = 12;
    } else if (successRate >= 0.55) {
      extraMinutes = 6;
    }

    return baseDuration + Duration(minutes: extraMinutes);
  }

  Duration computeUnpredictableDelay({
    required Duration baseDelay,
    required double successRate,
    int minMinutes = 3,
  }) {
    final baseMinutes = baseDelay.inMinutes <= 0 ? 1 : baseDelay.inMinutes;

    // Shorten intervals as success rises to keep the protocol demanding.
    final compressionFactor = successRate >= 0.85
        ? 0.55
        : successRate >= 0.7
        ? 0.65
        : successRate >= 0.55
        ? 0.8
        : 1.0;
    final compressed = max(minMinutes, (baseMinutes * compressionFactor).round());

    // Add larger jitter at higher success levels for unpredictability.
    final jitterRange = successRate >= 0.85
        ? 16
        : successRate >= 0.7
        ? 12
        : successRate >= 0.55
        ? 8
        : 5;
    final jitter = _random.nextInt((jitterRange * 2) + 1) - jitterRange;
    final finalMinutes = max(minMinutes, compressed + jitter);

    return Duration(minutes: finalMinutes);
  }

  List<DateTime> generateUnpredictableMoments({
    required DateTime now,
    required DateTime sleepAt,
    required List<String> riskyHours,
    required int minCount,
    required double successRate,
  }) {
    final results = <DateTime>[];
    final seen = <String>{};
    final windows = _resolveCandidateWindows(
      now: now,
      sleepAt: sleepAt,
      riskyHours: riskyHours,
    );

    if (windows.isEmpty) {
      return results;
    }

    final bonus = successRate >= 0.85
        ? 3
        : successRate >= 0.7
        ? 2
        : successRate >= 0.55
        ? 1
        : 0;
    final targetCount = minCount + bonus;

    var guard = 0;
    while (results.length < targetCount && guard < 250) {
      guard += 1;
      final window = windows[_random.nextInt(windows.length)];
      final start = window.$1;
      final end = window.$2;
      if (!end.isAfter(start)) {
        continue;
      }

      final maxMinutes = end.difference(start).inMinutes;
      if (maxMinutes <= 1) {
        continue;
      }
      final minuteOffset = _random.nextInt(maxMinutes);
      final candidate = start.add(Duration(minutes: minuteOffset));
      if (!candidate.isAfter(now) || !candidate.isBefore(sleepAt)) {
        continue;
      }

      final key =
          '${candidate.year}-${candidate.month}-${candidate.day}-${candidate.hour}-${candidate.minute}';
      if (seen.add(key)) {
        results.add(candidate);
      }
    }

    results.sort((a, b) => a.compareTo(b));
    return results;
  }

  bool isSuspiciousDuringTask({
    required List<SensorUsageEvent> events,
    required List<String> riskyHours,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    if (events.isEmpty || !endAt.isAfter(startAt)) {
      return false;
    }

    for (final event in events) {
      if (event.createdAt.isBefore(startAt) || event.createdAt.isAfter(endAt)) {
        continue;
      }

      final riskyWindowActive = _isHourInRiskWindow(event.createdAt.hour, riskyHours);
      final intenseMotion =
          event.accelerometerMagnitude >= 1.8 || event.gyroscopeMagnitude >= 1.8;
      final phoneSpike =
          event.screenUnlockCount >= 12 || event.appUsageMinutes >= 20;
      final nonIdle = event.activityState.toLowerCase().trim() != 'idle';

      if ((intenseMotion || phoneSpike) && (riskyWindowActive || nonIdle)) {
        return true;
      }
    }

    return false;
  }

  List<(DateTime, DateTime)> _resolveCandidateWindows({
    required DateTime now,
    required DateTime sleepAt,
    required List<String> riskyHours,
  }) {
    final windows = <(DateTime, DateTime)>[];

    for (final raw in riskyHours) {
      final range = _parseHourRange(now: now, raw: raw);
      if (range == null) {
        continue;
      }
      var start = range.$1;
      var end = range.$2;

      if (end.isBefore(now)) {
        start = start.add(const Duration(days: 1));
        end = end.add(const Duration(days: 1));
      }

      if (start.isBefore(sleepAt) && end.isAfter(now)) {
        final clampedStart = start.isBefore(now) ? now : start;
        final clampedEnd = end.isAfter(sleepAt) ? sleepAt : end;
        if (clampedEnd.isAfter(clampedStart)) {
          windows.add((clampedStart, clampedEnd));
        }
      }
    }

    if (windows.isEmpty) {
      var cursor = now.add(const Duration(minutes: 8));
      while (cursor.isBefore(sleepAt) && windows.length < 6) {
        final end = cursor.add(const Duration(minutes: 40));
        windows.add((cursor, end.isAfter(sleepAt) ? sleepAt : end));
        cursor = cursor.add(const Duration(minutes: 55));
      }
    }

    return windows;
  }

  (DateTime, DateTime)? _parseHourRange({
    required DateTime now,
    required String raw,
  }) {
    final value = raw.trim();
    final match = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*-\s*(\d{1,2})(?::(\d{2}))?')
        .firstMatch(value);
    if (match == null) {
      return null;
    }

    final startHour = int.tryParse(match.group(1) ?? '');
    final startMinute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final endHour = int.tryParse(match.group(3) ?? '');
    final endMinute = int.tryParse(match.group(4) ?? '0') ?? 0;
    if (startHour == null || endHour == null) {
      return null;
    }

    var start = DateTime(
      now.year,
      now.month,
      now.day,
      startHour.clamp(0, 23),
      startMinute.clamp(0, 59),
    );
    var end = DateTime(
      now.year,
      now.month,
      now.day,
      endHour.clamp(0, 23),
      endMinute.clamp(0, 59),
    );

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return (start, end);
  }

  bool _isHourInRiskWindow(int hour, List<String> riskyHours) {
    for (final raw in riskyHours) {
      final match = RegExp(r'(\d{1,2})(?::\d{2})?\s*-\s*(\d{1,2})(?::\d{2})?')
          .firstMatch(raw.trim());
      if (match == null) {
        continue;
      }

      final start = int.tryParse(match.group(1) ?? '');
      final end = int.tryParse(match.group(2) ?? '');
      if (start == null || end == null) {
        continue;
      }

      if (start <= end) {
        if (hour >= start && hour < end) {
          return true;
        }
      } else {
        if (hour >= start || hour < end) {
          return true;
        }
      }
    }
    return false;
  }
}