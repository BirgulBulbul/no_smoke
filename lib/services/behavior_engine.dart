import 'dart:math';

import '../models/adaptive_plan.dart';
import '../models/behavior_dashboard.dart';
import '../models/breath_test_record.dart';
import '../models/sensor_usage_event.dart';
import '../models/survey_history.dart';
import '../models/survey_record.dart';
import '../models/task_history.dart';
import '../models/user_behavior_profile.dart';

class BehaviorEngine {
  static final Random _random = Random();

  static const Map<String, int> _baseTriggerScores = {
    'Kahve': 10,
    'Yemek Sonrasi': 10,
    'Arac': 10,
    'Stres': 10,
    'Telefon': 10,
    'Sosyal Ortam': 10,
    'Alkol': 10,
  };

  static const Map<String, int> _consecutiveSmokingScores = {
    'Hayır': 0,
    '2 adet': 5,
    '3 adet': 10,
    '4 adet': 15,
    '5+ adet': 20,
  };

  static const Map<String, int> _packRiskContributions = {
    '1 paketten az': 5,
    '1 paket': 10,
    '2 paket': 20,
    '3 paket': 30,
    '3+ paket': 40,
    '4 paket': 40,
    '5 paket': 40,
    '6 paket': 40,
    '7+ paket': 40,
  };

  static const List<String> _easyTasks = [
    'Ilk sigarayi 20 dakika ertele',
    'Bir bardak su ic',
    '2 dakikalik nefes egzersizi yap',
    'Kisa bir yuruyus yap',
    'Kriz anini not et',
  ];

  static const List<String> _mediumTasks = [
    'Ilk sigarayi 45 dakika ertele',
    'Bugun bir sigarayi atla',
    '3 dakikalik nefes egzersizi yap',
    'Riskli saatte seker sakiz kullan',
    'Kahve sonrasi alternatif rutin uygula',
  ];

  static const List<String> _hardTasks = [
    '2 saat sigarasiz kal',
    'Bugun 2 sigara eksik ic',
    'Riskli tetikleyiciden aktif kacin',
    'Aksam saatinde destek kisisiyle iletisim kur',
    'Meydan okuma: zincir icmeyi tamamen durdur',
  ];

  Map<String, int> calculateTriggerScores(List<SurveyHistory> surveys) {
    final scores = <String, int>{
      for (final entry in _baseTriggerScores.entries) entry.key: entry.value,
    };

    for (final survey in surveys) {
      for (final entry in scores.entries.toList()) {
        final triggerName = entry.key;
        final wasSelected = survey.triggers.any(
          (trigger) => _normalizeTrigger(trigger) == triggerName,
        );
        final delta = wasSelected ? 5 : -1;
        scores[triggerName] = max(0, (scores[triggerName] ?? 10) + delta);
      }
    }

    return scores;
  }

  Map<String, int> calculateTriggerScoresFromSurveyRecords(
    List<SurveyRecord> surveys,
    Map<String, List<String>> triggerByRecordId,
  ) {
    final scores = <String, int>{
      for (final entry in _baseTriggerScores.entries) entry.key: entry.value,
    };

    final sorted = [...surveys]..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    for (final record in sorted) {
      if (record.type != 'initial' && record.type != 'weekly') {
        continue;
      }

      final selectedTriggers = triggerByRecordId[record.id] ?? const <String>[];
      for (final key in scores.keys.toList()) {
        final selected = selectedTriggers.any((item) => _normalizeTrigger(item) == key);
        final nextValue = (scores[key] ?? 10) + (selected ? 5 : -1);
        scores[key] = max(0, nextValue);
      }
    }

    return scores;
  }

  int calculateConsecutiveSmokingScore({String? habit, String? count}) {
    if (habit == null || habit.trim().isEmpty || _normalizeText(habit) == 'Hayir') {
      return 0;
    }
    return _consecutiveSmokingScores[count?.trim() ?? ''] ?? 0;
  }

  String summarizeConsecutiveSmoking({String? habit, String? count}) {
    if (habit == null || habit.trim().isEmpty || _normalizeText(habit) == 'Hayir') {
      return 'Hayır';
    }
    if (count == null || count.trim().isEmpty) {
      return habit;
    }
    return '$habit - ${count.trim()}';
  }

  String evaluateConsecutiveSmokingTrend({
    required String? previousHabit,
    required String? previousCount,
    required String? currentHabit,
    required String? currentCount,
  }) {
    final previousScore = calculateConsecutiveSmokingScore(
      habit: previousHabit,
      count: previousCount,
    );
    final currentScore = calculateConsecutiveSmokingScore(
      habit: currentHabit,
      count: currentCount,
    );

    if (previousScore == currentScore) {
      return 'trendStable';
    }
    if (currentScore < previousScore) {
      return 'trendImproving';
    }
    return 'trendDeclining';
  }

  String evaluateConsecutiveSmokingStatus({String? habit, String? count}) {
    return summarizeConsecutiveSmoking(habit: habit, count: count);
  }

  List<String> calculateRiskyTriggers(Map<String, int> triggerScores) {
    return _selectRiskyTriggers(triggerScores);
  }

  List<String> calculateRiskyHours(List<SurveyHistory> surveys) {
    final frequency = <String, int>{};

    for (final survey in surveys) {
      final label = _groupHour(survey.hardestHour);
      if (label != null) {
        frequency[label] = (frequency[label] ?? 0) + 1;
      }
    }

    if (frequency.isEmpty) {
      return const [];
    }

    final sorted = frequency.entries.toList()
      ..sort((a, b) {
        final byFrequency = b.value.compareTo(a.value);
        if (byFrequency != 0) {
          return byFrequency;
        }
        return a.key.compareTo(b.key);
      });

    return sorted.map((entry) => entry.key).toList();
  }

  List<String> calculateRiskyHoursFromTimestamps({
    required List<DateTime> surveyTimes,
    required List<DateTime> appUsageTimes,
    required List<DateTime> taskFailureTimes,
    required List<DateTime> breathTestTimes,
  }) {
    final frequency = <String, int>{};

    void addTimes(List<DateTime> times, int weight) {
      for (final time in times) {
        final bucket = _groupHalfHourToTwoHourWindow(time.hour, time.minute);
        frequency[bucket] = (frequency[bucket] ?? 0) + weight;
      }
    }

    addTimes(surveyTimes, 3);
    addTimes(appUsageTimes, 2);
    addTimes(taskFailureTimes, 4);
    addTimes(breathTestTimes, 1);

    if (frequency.isEmpty) {
      return const [];
    }

    final sorted = frequency.entries.toList()
      ..sort((a, b) {
        final byWeight = b.value.compareTo(a.value);
        if (byWeight != 0) {
          return byWeight;
        }
        return a.key.compareTo(b.key);
      });

    return sorted.take(3).map((entry) => entry.key).toList();
  }

  List<Map<String, dynamic>> calculateTaskSuccessRates(List<TaskHistory> tasks) {
    final grouped = <String, Map<String, dynamic>>{};

    for (final task in tasks) {
      final entry = grouped.putIfAbsent(task.taskTitle, () => {
        'taskTitle': task.taskTitle,
        'totalCount': 0,
        'successCount': 0,
        'failureCount': 0,
        'successRate': 0.0,
      });

      entry['totalCount'] = (entry['totalCount'] as int) + 1;
      if (task.completed) {
        entry['successCount'] = (entry['successCount'] as int) + 1;
      } else {
        entry['failureCount'] = (entry['failureCount'] as int) + 1;
      }
      entry['successRate'] =
          (entry['successCount'] as num) / (entry['totalCount'] as num);
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) {
        final rateCompare =
            (b['successRate'] as double).compareTo(a['successRate'] as double);
        if (rateCompare != 0) {
          return rateCompare;
        }
        return (a['taskTitle'] as String).compareTo(b['taskTitle'] as String);
      });

    return sorted;
  }

  Map<String, double> calculateTaskSuccessRateMap(List<TaskHistory> tasks) {
    final rates = <String, double>{};
    for (final row in calculateTaskSuccessRates(tasks)) {
      rates[row['taskTitle'] as String] =
          (row['successRate'] as num).toDouble();
    }
    return rates;
  }

  String calculateBreathTrend(List<BreathTestRecord> breathTests) {
    if (breathTests.length < 2) {
      return 'Stable';
    }

    final initialAverage = _averageBreathValue(breathTests.first);
    final latestAverage = _averageBreathValue(breathTests.last);

    if (latestAverage > initialAverage) {
      return 'Improving';
    }
    if (latestAverage < initialAverage) {
      return 'Declining';
    }
    return 'Stable';
  }

  String calculateBreathTrendFromRecords(List<SurveyRecord> records) {
    final breathRecords = records.where((record) => record.type == 'breath_test').toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    if (breathRecords.length < 2) {
      return 'Stable';
    }

    final first =
        (breathRecords.first.exhaleTestSeconds + breathRecords.first.inhaleTestSeconds) / 2;
    final last =
        (breathRecords.last.exhaleTestSeconds + breathRecords.last.inhaleTestSeconds) / 2;

    if (last > first) {
      return 'Improving';
    }
    if (last < first) {
      return 'Declining';
    }
    return 'Stable';
  }

  String calculateSmokingTrend(List<SurveyHistory> surveys) {
    final recentSurveys = surveys.length > 5
        ? surveys.sublist(surveys.length - 5)
        : surveys;

    if (recentSurveys.length < 2) {
      return 'Stable';
    }

    final initialValue = _packLevel(recentSurveys.first.packsPerDay);
    final latestValue = _packLevel(recentSurveys.last.packsPerDay);

    if (latestValue < initialValue) {
      return 'Decreasing';
    }
    if (latestValue > initialValue) {
      return 'Increasing';
    }
    return 'Stable';
  }

  String calculateSmokingTrendFromRecords(List<SurveyRecord> records) {
    final surveys = records
        .where((record) => record.type == 'initial' || record.type == 'weekly')
        .toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    if (surveys.length < 2) {
      return 'Stable';
    }

    final initialValue = _packLevel(surveys.first.packsPerDay);
    final latestValue = _packLevel(surveys.last.packsPerDay);

    if (latestValue < initialValue) {
      return 'Decreasing';
    }
    if (latestValue > initialValue) {
      return 'Increasing';
    }
    return 'Stable';
  }

  int calculatePackRiskContribution(String packsPerDay) {
    return _packRiskContributions[packsPerDay] ?? 5;
  }

  String calculateRiskTrend(List<SurveyHistory> surveys) {
    if (surveys.length < 2) {
      return 'Stable';
    }

    final initialRisk = _effectiveRiskScore(surveys.first);
    final latestRisk = _effectiveRiskScore(surveys.last);
    if (latestRisk < initialRisk) {
      return 'Improving';
    }
    if (latestRisk > initialRisk) {
      return 'Declining';
    }
    return 'Stable';
  }

  String calculateConsecutiveSmokingTrend(List<SurveyHistory> surveys) {
    if (surveys.length < 2) {
      return 'noRecordYet';
    }

    final previousScore =
        calculateChainSmokingRiskContribution(surveys[surveys.length - 2].chainSmokingLevel);
    final currentScore =
        calculateChainSmokingRiskContribution(surveys.last.chainSmokingLevel);

    if (currentScore < previousScore) {
      return 'trendImproving';
    }
    if (currentScore > previousScore) {
      return 'trendDeclining';
    }
    return 'trendStable';
  }

  String evaluateConsecutiveSmokingTrendFromRecords(List<SurveyRecord> records) {
    final relevant = _extractRelevantSurveyRecords(records);
    if (relevant.length < 2) {
      return 'trendStable';
    }

    final previous = relevant[relevant.length - 2];
    final current = relevant.last;
    return evaluateConsecutiveSmokingTrend(
      previousHabit: previous.consecutiveSmokingHabit,
      previousCount: previous.consecutiveSmokingCount,
      currentHabit: current.consecutiveSmokingHabit,
      currentCount: current.consecutiveSmokingCount,
    );
  }

  int calculateDynamicRiskScore({
    required int baseRiskScore,
    required String smokingTrend,
    required String breathTrend,
    required String consecutiveTrend,
    required List<String> riskyTriggers,
    required List<String> riskyHours,
  }) {
    var score = baseRiskScore;

    if (smokingTrend == 'Increasing') {
      score += 8;
    } else if (smokingTrend == 'Decreasing') {
      score -= 6;
    }

    if (breathTrend == 'Declining') {
      score += 6;
    } else if (breathTrend == 'Improving') {
      score -= 5;
    }

    if (consecutiveTrend == 'trendDeclining') {
      score += 7;
    } else if (consecutiveTrend == 'trendImproving') {
      score -= 4;
    }

    score += min(riskyTriggers.length, 3) * 2;
    score += min(riskyHours.length, 2) * 2;

    return score.clamp(0, 100);
  }

  String chooseTaskDifficulty(int riskScore) {
    if (riskScore >= 70) {
      return 'easy';
    }
    if (riskScore >= 40) {
      return 'medium';
    }
    return 'hard';
  }

  List<String> generateAdaptiveTasks({
    required int riskScore,
    required Map<String, double> taskSuccessRates,
    int count = 3,
  }) {
    final difficulty = chooseTaskDifficulty(riskScore);
    final pool = difficulty == 'easy'
        ? _easyTasks
        : difficulty == 'medium'
            ? _mediumTasks
            : _hardTasks;

    final weighted = pool.map((task) {
      final rate = taskSuccessRates[task] ?? 0.5;
      final weight = (0.4 + rate).clamp(0.2, 1.6);
      return MapEntry(task, weight.toDouble());
    }).toList();

    final selected = <String>{};
    while (selected.length < min(count, weighted.length)) {
      final totalWeight = weighted.fold<double>(0, (sum, item) => sum + item.value);
      final roll = _random.nextDouble() * totalWeight;
      var running = 0.0;
      for (final item in weighted) {
        running += item.value;
        if (roll <= running) {
          selected.add(item.key);
          break;
        }
      }
    }
    return selected.toList();
  }

  AdaptivePlan buildAdaptivePlan180({
    required DateTime startDate,
    required int riskScore,
    required String breathTrend,
    required String smokingTrend,
    required List<String> riskyTriggers,
  }) {
    final elapsedWeeks =
        max(1, DateTime.now().difference(startDate).inDays ~/ 7 + 1);
    final weeklyRiskTarget = max(5, (riskScore - elapsedWeeks * 2).clamp(5, 95));

    final focus = <String>[
      if (riskyTriggers.isNotEmpty) 'Tetikleyici yonetimi',
      if (breathTrend != 'Improving') 'Nefes performansi',
      if (smokingTrend != 'Decreasing') 'Paket azaltma',
      if (riskyTriggers.isEmpty) 'Rutin koruma',
    ];

    return AdaptivePlan(
      generatedAt: DateTime.now(),
      targetDays: 180,
      currentWeek: elapsedWeeks,
      weeklyRiskTarget: weeklyRiskTarget,
      difficulty: chooseTaskDifficulty(riskScore),
      focusAreas: focus.take(3).toList(),
    );
  }

  Map<String, dynamic> predictNextRisk({
    required List<String> riskyHours,
    required List<String> riskyTriggers,
    required int riskScore,
    required List<SensorUsageEvent> sensorEvents,
  }) {
    final nextRiskWindow = riskyHours.isNotEmpty ? riskyHours.first : '20:00-22:00';
    final nextRiskTrigger =
        riskyTriggers.isNotEmpty ? riskyTriggers.first : 'Stres';

    var confidence = 45;
    confidence += min(riskyHours.length, 3) * 8;
    confidence += min(riskyTriggers.length, 3) * 7;
    confidence += (riskScore / 10).round();
    confidence += _sensorConfidenceBoost(sensorEvents);

    return {
      'nextRiskWindow': nextRiskWindow,
      'nextRiskTrigger': nextRiskTrigger,
      'dailyRiskScore': riskScore.clamp(0, 100),
      'weeklyRiskScore': (riskScore * 0.95).round().clamp(0, 100),
      'confidence': confidence.clamp(10, 99),
    };
  }

  BehaviorDashboard buildDashboard({
    required int riskScore,
    required List<SurveyRecord> records,
    required List<String> riskyTriggers,
    required List<String> riskyHours,
    required List<String> todaysTasks,
    required Map<String, dynamic> prediction,
    required AdaptivePlan plan,
  }) {
    DateTime? lastSurveyDate;
    DateTime? lastBreathDate;

    for (final record in records) {
      if ((record.type == 'initial' || record.type == 'weekly') &&
          (lastSurveyDate == null || record.completedAt.isAfter(lastSurveyDate))) {
        lastSurveyDate = record.completedAt;
      }
      if (record.type == 'breath_test' &&
          (lastBreathDate == null || record.completedAt.isAfter(lastBreathDate))) {
        lastBreathDate = record.completedAt;
      }
    }

    final breathTrend = calculateBreathTrendFromRecords(records);
    final smokingTrend = calculateSmokingTrendFromRecords(records);
    final consecutiveTrend = evaluateConsecutiveSmokingTrendFromRecords(records);

    final progressSummary = _deriveProgressStatus(
      smokingTrend: smokingTrend,
      breathTrend: breathTrend,
      riskTrend: consecutiveTrend == 'trendDeclining' ? 'Declining' : 'Stable',
    );

    return BehaviorDashboard(
      riskScore: riskScore,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      lastSurveyDate: lastSurveyDate,
      lastBreathDate: lastBreathDate,
      breathTrend: breathTrend,
      progressSummary: progressSummary,
      todaysTasks: todaysTasks,
      predictedRiskWindow: prediction['nextRiskWindow'] as String,
      predictionConfidence: prediction['confidence'] as int,
      predictedTrigger: prediction['nextRiskTrigger'] as String,
      plan: plan,
    );
  }

  UserBehaviorProfile generateBehaviorProfile({
    required List<SurveyHistory> surveys,
    required List<BreathTestRecord> breathTests,
    required List<TaskHistory> taskHistory,
    List<SurveyRecord> surveyRecords = const [],
    String subscriptionType = 'free',
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    bool trialActive = false,
    bool premiumFeaturesEnabled = false,
  }) {
    final triggerScores = calculateTriggerScores(surveys);
    final riskyTriggers = _selectRiskyTriggers(triggerScores);
    final riskyHours = calculateRiskyHours(surveys);
    final taskRates = calculateTaskSuccessRates(taskHistory);
    final breathTrend = calculateBreathTrend(breathTests);
    final smokingTrend = calculateSmokingTrend(surveys);
    final riskTrend = calculateRiskTrend(surveys);
    final consecutiveSmokingTrend = surveyRecords.isNotEmpty
        ? _calculateConsecutiveSmokingTrendFromRecords(surveyRecords)
        : calculateConsecutiveSmokingTrend(surveys);
    final consecutiveSmokingStatus = surveyRecords.isNotEmpty
        ? _calculateConsecutiveSmokingStatusFromRecords(surveyRecords)
        : _calculateConsecutiveSmokingStatusFromSurveys(surveys);

    final latestSurvey = surveys.isEmpty ? null : surveys.last;
    final riskScore = latestSurvey == null ? 0 : _effectiveRiskScore(latestSurvey);

    final successfulTasks = <String, Map<String, dynamic>>{};
    final failedTasks = <String, Map<String, dynamic>>{};
    for (final task in taskRates) {
      final title = task['taskTitle'] as String;
      if ((task['successRate'] as double) >= 0.5) {
        successfulTasks[title] = task;
      } else {
        failedTasks[title] = task;
      }
    }

    return UserBehaviorProfile(
      riskScore: riskScore,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      successfulTasks: successfulTasks,
      failedTasks: failedTasks,
      breathTrend: breathTrend,
      smokingTrend: smokingTrend,
      riskTrend: riskTrend,
      consecutiveSmokingTrend: consecutiveSmokingTrend,
      consecutiveSmokingStatus: consecutiveSmokingStatus,
      progressStatus: _deriveProgressStatus(
        smokingTrend: smokingTrend,
        breathTrend: breathTrend,
        riskTrend: riskTrend,
      ),
      suggestedTasks: _generateSuggestedTasks(
        riskyTriggers: riskyTriggers,
        riskyHours: riskyHours,
        breathTrend: breathTrend,
        smokingTrend: smokingTrend,
        riskTrend: riskTrend,
        consecutiveSmokingTrend: consecutiveSmokingTrend,
        consecutiveSmokingStatus: consecutiveSmokingStatus,
      ),
      lastSurveyDate: latestSurvey?.surveyDate,
      subscriptionType: subscriptionType,
      subscriptionStartDate: subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate,
      trialActive: trialActive,
      premiumFeaturesEnabled: premiumFeaturesEnabled,
    );
  }

  String calculateProgressStatus({
    required String smokingTrend,
    required String breathTrend,
    required String riskTrend,
  }) {
    return _deriveProgressStatus(
      smokingTrend: smokingTrend,
      breathTrend: breathTrend,
      riskTrend: riskTrend,
    );
  }

  String _deriveProgressStatus({
    required String smokingTrend,
    required String breathTrend,
    required String riskTrend,
  }) {
    if (smokingTrend == 'Increasing' ||
        breathTrend == 'Declining' ||
        riskTrend == 'Declining') {
      return 'Declining';
    }
    if (smokingTrend == 'Decreasing' ||
        breathTrend == 'Improving' ||
        riskTrend == 'Improving') {
      return 'Improving';
    }
    return 'Stable';
  }

  List<String> _selectRiskyTriggers(Map<String, int> triggerScores) {
    if (triggerScores.isEmpty) {
      return const [];
    }
    final maxScore = triggerScores.values.reduce(max);
    if (maxScore <= 0) {
      return const [];
    }
    final risky = triggerScores.entries
        .where((entry) => entry.value == maxScore)
        .map((entry) => entry.key)
        .toList()
      ..sort();
    return risky;
  }

  String _normalizeTrigger(String trigger) {
    final normalized = _normalizeText(trigger);
    for (final key in _baseTriggerScores.keys) {
      if (_normalizeText(key) == normalized) {
        return key;
      }
    }
    return trigger;
  }

  String _normalizeText(String value) {
    return value
        .trim()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'I')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C');
  }

  String? _groupHour(String? hardestHour) {
    if (hardestHour == null || hardestHour.isEmpty) {
      return null;
    }

    final parts = hardestHour.split(':');
    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts.first);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return _groupHalfHourToTwoHourWindow(hour, minute);
  }

  String _groupHalfHourToTwoHourWindow(int hour, int minute) {
    final normalizedHour = minute >= 30 ? (hour + 1) % 24 : hour;
    final startHour = (normalizedHour ~/ 2) * 2;
    final endHour = (startHour + 2) % 24;
    return '${startHour.toString().padLeft(2, '0')}:00-${endHour.toString().padLeft(2, '0')}:00';
  }

  String _calculateConsecutiveSmokingTrendFromRecords(List<SurveyRecord> records) {
    final relevantRecords = _extractRelevantSurveyRecords(records);
    if (relevantRecords.length < 2) {
      return 'noRecordYet';
    }

    final previous = relevantRecords[relevantRecords.length - 2];
    final current = relevantRecords.last;
    return evaluateConsecutiveSmokingTrend(
      previousHabit: previous.consecutiveSmokingHabit,
      previousCount: previous.consecutiveSmokingCount,
      currentHabit: current.consecutiveSmokingHabit,
      currentCount: current.consecutiveSmokingCount,
    );
  }

  String _calculateConsecutiveSmokingStatusFromRecords(List<SurveyRecord> records) {
    final relevantRecords = _extractRelevantSurveyRecords(records);
    if (relevantRecords.isEmpty) {
      return 'noRecordYet';
    }
    final current = relevantRecords.last;
    return evaluateConsecutiveSmokingStatus(
      habit: current.consecutiveSmokingHabit,
      count: current.consecutiveSmokingCount,
    );
  }

  String _calculateConsecutiveSmokingStatusFromSurveys(List<SurveyHistory> surveys) {
    if (surveys.isEmpty) {
      return 'noRecordYet';
    }
    return surveys.last.chainSmokingLevel;
  }

  List<String> _generateSuggestedTasks({
    required List<String> riskyTriggers,
    required List<String> riskyHours,
    required String breathTrend,
    required String smokingTrend,
    required String riskTrend,
    required String consecutiveSmokingTrend,
    required String consecutiveSmokingStatus,
  }) {
    final suggestions = <String>{
      if (riskTrend == 'Declining' || riskyTriggers.isNotEmpty)
        'Riskli tetikleyicileri 1 hafta boyunca not et',
      if (riskyHours.isNotEmpty) 'Riskli saatlerde alternatif bir rutin uygula',
      if (breathTrend == 'Declining') 'Nefes testini gunluk tekrarla',
      if (smokingTrend == 'Increasing') 'Gunluk paket miktarini bir kademe azalt',
      if (consecutiveSmokingTrend == 'trendDeclining')
        'Arka arkaya sigara dongusunu erteleme ile kir',
      if (consecutiveSmokingStatus.contains('5+ adet') ||
          consecutiveSmokingStatus.contains('4 adet'))
        'Arka arkaya icme adedini bir basamak dusur',
      if (riskTrend == 'Improving') 'Kazandigin ilerlemeyi rutine sabitle',
    };

    if (suggestions.isEmpty) {
      suggestions.add('Mevcut rutini surdur ve haftalik veriyi takip et');
    }

    return suggestions.take(3).toList();
  }

  Map<String, dynamic> buildHomeSummary(UserBehaviorProfile profile) {
    return {
      'riskScore': profile.riskScore,
      'riskTrend': profile.riskTrend,
      'smokingTrend': profile.smokingTrend,
      'breathTrend': profile.breathTrend,
      'consecutiveSmokingTrend': profile.consecutiveSmokingTrend,
      'consecutiveSmokingStatus': profile.consecutiveSmokingStatus,
      'progressStatus': profile.progressStatus,
      'riskyTriggers': profile.riskyTriggers,
      'riskyHours': profile.riskyHours,
      'suggestedTasks': profile.suggestedTasks,
      'lastSurveyDate': profile.lastSurveyDate,
    };
  }

  List<SurveyRecord> _extractRelevantSurveyRecords(List<SurveyRecord> records) {
    return records
        .where((record) => record.type == 'initial' || record.type == 'weekly')
        .toList();
  }

  double _averageBreathValue(BreathTestRecord record) {
    return (record.exhaleSeconds + record.inhaleSeconds) / 2;
  }

  int _packLevel(String packsPerDay) {
    switch (packsPerDay) {
      case '1 paketten az':
        return 0;
      case '1 paket':
        return 1;
      case '2 paket':
        return 2;
      case '3 paket':
        return 3;
      case '3+ paket':
      case '4 paket':
        return 4;
      case '5 paket':
        return 5;
      case '6 paket':
        return 6;
      case '7+ paket':
        return 7;
      default:
        return 0;
    }
  }

  int calculateChainSmokingRiskContribution(String chainSmokingLevel) {
    switch (chainSmokingLevel) {
      case 'Hayır':
      case 'Hayir':
        return 0;
      case '2 adet':
        return 5;
      case '3 adet':
        return 10;
      case '4 adet':
        return 15;
      case '5+ adet':
        return 20;
      default:
        return 0;
    }
  }

  int _effectiveRiskScore(SurveyHistory survey) {
    final total = survey.riskScore +
        calculatePackRiskContribution(survey.packsPerDay) +
        calculateChainSmokingRiskContribution(survey.chainSmokingLevel);
    return total.clamp(0, 100);
  }

  int _sensorConfidenceBoost(List<SensorUsageEvent> events) {
    if (events.isEmpty) {
      return 0;
    }

    final recent = events.length > 20 ? events.sublist(events.length - 20) : events;
    final activeCount = recent.where((item) => item.activityState != 'idle').length;
    final activityRatio = activeCount / recent.length;
    return (activityRatio * 12).round();
  }
}