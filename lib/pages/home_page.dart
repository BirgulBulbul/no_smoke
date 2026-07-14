import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import '../pages/task_follow_up_page.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/no_smoke_logo.dart';

class HomePage extends StatefulWidget {
  final String name;
  final int riskScore;
  final String riskLevel;
  final bool autoCompleteRegistrationOnLoad;

  const HomePage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
    this.autoCompleteRegistrationOnLoad = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StorageService _storageService = StorageService();
  final Map<String, String> _taskStates = {};
  final Map<String, Timer> _taskFollowUpTimers = {};
  final Set<String> _notifiedTaskTitles = <String>{};
  StreamSubscription<Map<String, String>>? _taskActionSubscription;
  List<Map<String, dynamic>> _pendingFollowUps = const [];
  bool _registrationCompleted = false;
  bool _isCompletingRegistration = false;
  String _lastSurveyDateText = '...';
  String _lastBreathText = '...';
  String _dailyBreathStatus = '...';
  int _latestExhaleSeconds = 0;
  int _latestInhaleSeconds = 0;
  String _breathTrendText = '...';
  String _weeklyImprovementText = '...';
  String _monthlyImprovementText = '...';
  String _breathPreviousReportText = '...';
  String _breathAverageReportText = '...';
  String _progressSummaryText = '...';
  String _predictedRiskWindow = '...';
  String _predictedTrigger = '...';
  int _predictionConfidence = 0;
  int _adaptiveRiskScore = 0;
  int _weeklyRiskTarget = 0;
  int _planCurrentDay = 1;
  int _planTargetDays = 180;
  int _planDaysRemaining = 179;
  String _planCadenceLevel = 'one_day';
  List<String> _riskyTriggers = const [];
  List<String> _riskyHours = const [];
  List<String> _todaysTasks = const [];
  String _consecutiveSmokingLatestText = '...';
  String _consecutiveSmokingPreviousText = '...';
  String _consecutiveSmokingTrendText = '...';
  String _consecutiveSmokingStatusText = '...';
  int _successfulTaskCount = 0;
  int _failedTaskCount = 0;
  double _weeklyAverage = 0;
  double _monthlyAverage = 0;
  double _dailyAverage = 0;

  @override
  void initState() {
    super.initState();
    _taskActionSubscription = NotificationService.taskActionStream.listen(
      _handleTaskNotificationAction,
    );
    _loadHomeMetrics();
  }

  @override
  void dispose() {
    _taskActionSubscription?.cancel();
    for (final timer in _taskFollowUpTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _scheduleLocalFollowUp(String taskTitle, DateTime scheduledAt) {
    final remaining = scheduledAt.difference(DateTime.now());
    final delay = remaining.isNegative ? Duration.zero : remaining;
    _taskFollowUpTimers[taskTitle]?.cancel();
    _taskFollowUpTimers[taskTitle] = Timer(delay, () {
      if (!mounted) {
        return;
      }
      _askTaskOutcome(taskTitle);
    });
  }

  Future<void> _restorePendingFollowUps() async {
    final pending = await _storageService.loadPendingTaskFollowUps();
    if (!mounted) {
      return;
    }

    setState(() {
      _pendingFollowUps = pending;
    });

    for (final row in pending) {
      final taskTitle = row['taskTitle'] as String;
      final scheduledAt = row['scheduledAt'] as DateTime;
      _scheduleLocalFollowUp(taskTitle, scheduledAt);
      _taskStates[taskTitle] = 'deferred';
    }
  }

  String _calculateImprovementLabel(double current, double baseline) {
    if (current > baseline + 0.2) {
      return 'trendImproving';
    }
    if (current < baseline - 0.2) {
      return 'trendDeclining';
    }
    return 'trendStable';
  }

  String _translateTrend(String trendKey) {
    if (trendKey == 'trendImproving') {
      return context.t('trendImproving');
    }
    if (trendKey == 'trendDeclining') {
      return context.t('trendDeclining');
    }
    if (trendKey == 'trendStable') {
      return context.t('trendStable');
    }
    return trendKey;
  }

  Future<void> _askTaskOutcome(String taskTitle) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.t('taskOutcomeQuestion')),
          content: Text(taskTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.t('taskOutcomeNo')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.t('taskOutcomeYes')),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    await _storageService.saveTaskResult(
      taskTitle: taskTitle,
      taskResult: result ? 'success' : 'failed',
      completedAt: DateTime.now(),
    );
    await _storageService.resolveTaskFollowUpByTitle(taskTitle);
    _taskFollowUpTimers[taskTitle]?.cancel();
    _taskFollowUpTimers.remove(taskTitle);

    if (!mounted) {
      return;
    }

    setState(() {
      _taskStates[taskTitle] = result ? 'completed' : 'failed';
    });

    await _loadHomeMetrics();
    await _restorePendingFollowUps();
  }

  Future<void> _handleTaskNotificationAction(Map<String, String> event) async {
    final taskTitle = event['taskTitle']?.trim() ?? '';
    final actionId = event['actionId']?.trim() ?? '';
    if (taskTitle.isEmpty || actionId.isEmpty) {
      return;
    }

    if (actionId == 'task_done') {
      final now = DateTime.now();
      final delay = _resolveInitialTaskDelay(taskTitle);
      final followUpAt = now.add(delay);
      await _storageService.saveTaskResult(
        taskTitle: taskTitle,
        taskResult: 'started',
        completedAt: now,
      );
      await _storageService.saveTaskFollowUp(
        taskTitle: taskTitle,
        scheduledAt: followUpAt,
      );
      await NotificationService.showTaskTimerStartedNotification(
        taskTitle: taskTitle,
        duration: delay,
      );
      await NotificationService.scheduleTaskFollowUpReminder(
        taskTitle: taskTitle,
        delay: delay,
      );
      _scheduleLocalFollowUp(taskTitle, followUpAt);
      if (!mounted) {
        return;
      }
      setState(() {
        _taskStates[taskTitle] = 'deferred';
      });
      return;
    }

    if (actionId == 'task_not_now') {
      final delay = const Duration(minutes: 10);
      final followUpAt = DateTime.now().add(delay);
      await _storageService.saveTaskFollowUp(
        taskTitle: taskTitle,
        scheduledAt: followUpAt,
      );
      await NotificationService.scheduleFirstTaskTriggerNotification(
        taskDescription: taskTitle,
        delay: delay,
      );
      _scheduleLocalFollowUp(taskTitle, followUpAt);
      return;
    }

    if (actionId == 'smoked_yes' || actionId == 'smoked_no') {
      final success = actionId == 'smoked_yes';
      await _storageService.saveTaskResult(
        taskTitle: taskTitle,
        taskResult: success ? 'success' : 'failed',
        completedAt: DateTime.now(),
      );
      await _storageService.resolveTaskFollowUpByTitle(taskTitle);
      _taskFollowUpTimers[taskTitle]?.cancel();
      _taskFollowUpTimers.remove(taskTitle);
      if (!mounted) {
        return;
      }
      setState(() {
        _taskStates[taskTitle] = success ? 'completed' : 'failed';
      });
      await _loadHomeMetrics();
      await _restorePendingFollowUps();
    }
  }

  Future<void> _loadHomeMetrics() async {
    final registrationCompleted = await _storageService
        .loadInitialRegistrationCompleted();
    final lastDate = await _storageService.loadLastSurveyDate();
    final latestBreath = await _storageService.loadLatestBreathRecord();
    final metrics = await _storageService.loadBreathMetrics();
    final breathProgress = await _storageService.loadBreathProgressReport();
    final consecutiveSmokingSummary = await _storageService
        .loadConsecutiveSmokingSummary();
    final taskOutcomeSummary = await _storageService.loadTaskOutcomeSummary();
    final behavior = registrationCompleted
        ? await _storageService.loadBehaviorDashboard()
        : await _storageService.loadLatestBehaviorSnapshot();
    final pendingFollowUps = await _storageService.loadPendingTaskFollowUps();
    if (!mounted) return;
    setState(() {
      _registrationCompleted = registrationCompleted;
      _lastSurveyDateText = lastDate == null
          ? 'noRecordYet'
          : '${lastDate.day}/${lastDate.month}/${lastDate.year}';
      _lastBreathText = latestBreath == null
          ? 'noRecordYet'
          : '${latestBreath.completedAt.day}/${latestBreath.completedAt.month}/${latestBreath.completedAt.year} • ${latestBreath.exhaleTestSeconds}${context.t('secShort')} / ${latestBreath.inhaleTestSeconds}${context.t('secShort')}';
      _latestExhaleSeconds = latestBreath?.exhaleTestSeconds ?? 0;
      _latestInhaleSeconds = latestBreath?.inhaleTestSeconds ?? 0;
      final now = DateTime.now();
      final doneToday =
          latestBreath != null &&
          latestBreath.completedAt.year == now.year &&
          latestBreath.completedAt.month == now.month &&
          latestBreath.completedAt.day == now.day;
      _dailyBreathStatus = doneToday
          ? 'breathTestDoneToday'
          : 'breathTestPendingToday';
      _dailyAverage = metrics['dailyAverage'] ?? 0;
      _weeklyAverage = metrics['weeklyAverage'] ?? 0;
      _monthlyAverage = metrics['monthlyAverage'] ?? 0;
      _weeklyImprovementText = _calculateImprovementLabel(
        _weeklyAverage,
        _monthlyAverage,
      );
      _monthlyImprovementText = _calculateImprovementLabel(
        _monthlyAverage,
        _dailyAverage,
      );
      _breathPreviousReportText = _buildBreathDeltaText(
        delta: (breathProgress['deltaFromPrevious'] as num?)?.toDouble() ?? 0,
        hasReference: breathProgress['hasPrevious'] == true,
        comparisonMode: 'previous',
      );
      _breathAverageReportText = _buildBreathDeltaText(
        delta:
            (breathProgress['deltaFromMonthlyAverage'] as num?)?.toDouble() ??
            0,
        hasReference: true,
        comparisonMode: 'average',
      );
      _adaptiveRiskScore = behavior?.riskScore ?? 0;
      _riskyTriggers = behavior?.riskyTriggers ?? const [];
      _riskyHours = behavior?.riskyHours ?? const [];
      _breathTrendText = behavior?.breathTrend ?? 'Stable';
      _progressSummaryText = behavior?.progressSummary ?? 'Stable';
      _todaysTasks = behavior?.todaysTasks ?? const [];
      _predictedRiskWindow = behavior?.predictedRiskWindow ?? '...';
      _predictedTrigger = behavior?.predictedTrigger ?? '...';
      _predictionConfidence = behavior?.predictionConfidence ?? 0;
      _weeklyRiskTarget = behavior?.plan.weeklyRiskTarget ?? 0;
      _planCurrentDay = behavior?.plan.currentDay ?? 1;
      _planTargetDays = behavior?.plan.targetDays ?? 180;
      _planDaysRemaining = behavior?.plan.daysRemaining ?? 179;
      _planCadenceLevel = behavior?.plan.cadenceLevel ?? 'one_day';
      _consecutiveSmokingLatestText =
          consecutiveSmokingSummary['latest'] ?? context.t('noRecordYet');
      _consecutiveSmokingPreviousText =
          consecutiveSmokingSummary['previous'] ?? context.t('noRecordYet');
      _consecutiveSmokingTrendText =
          consecutiveSmokingSummary['trend'] ?? context.t('noRecordYet');
      _consecutiveSmokingStatusText =
          consecutiveSmokingSummary['status'] ?? context.t('noRecordYet');
      _successfulTaskCount = taskOutcomeSummary['successCount'] ?? 0;
      _failedTaskCount = taskOutcomeSummary['failureCount'] ?? 0;
      for (final task in _todaysTasks) {
        _taskStates.putIfAbsent(task, () => 'new');
      }
      _pendingFollowUps = pendingFollowUps;
    });

    if (widget.autoCompleteRegistrationOnLoad &&
        !_registrationCompleted &&
        !_isCompletingRegistration) {
      unawaited(_completeRegistration());
    }

    if (_registrationCompleted) {
      unawaited(_notifyNewTasks());
    }
  }

  Future<void> _notifyNewTasks() async {
    if (_todaysTasks.isEmpty) {
      return;
    }
    final timingContext = await _storageService.loadLatestTaskTimingContext();
    var index = 0;
    for (final task in _todaysTasks) {
      if (_notifiedTaskTitles.contains(task)) {
        continue;
      }
      if ((_taskStates[task] ?? 'new') != 'new') {
        continue;
      }
      final delay = _resolveTaskNotificationDelay(
        taskTitle: task,
        index: index,
        timingContext: timingContext,
      );
      await NotificationService.scheduleFirstTaskTriggerNotification(
        taskDescription: task,
        delay: delay,
      );

      _notifiedTaskTitles.add(task);
      index += 1;
    }
  }

  Duration _resolveInitialTaskDelay(String taskTitle) {
    final minuteMatch = RegExp(
      r'(\d+)\s*dakika',
      caseSensitive: false,
    ).firstMatch(taskTitle);
    if (minuteMatch != null) {
      final minutes = int.tryParse(minuteMatch.group(1) ?? '');
      if (minutes != null && minutes > 0) {
        return Duration(minutes: minutes);
      }
    }

    final hourMatch = RegExp(
      r'(\d+)\s*saat',
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

  Duration _resolveTaskNotificationDelay({
    required String taskTitle,
    required int index,
    required Map<String, dynamic> timingContext,
  }) {
    final riskScore = _adaptiveRiskScore == 0
        ? widget.riskScore
        : _adaptiveRiskScore;
    final baseMinutes = riskScore >= 80
        ? 10
        : riskScore >= 60
        ? 20
        : riskScore >= 40
        ? 35
        : riskScore >= 20
        ? 50
        : 75;
    final gapMinutes = riskScore >= 80
        ? 12
        : riskScore >= 60
        ? 20
        : riskScore >= 40
        ? 30
        : riskScore >= 20
        ? 45
        : 60;

    var minutes = baseMinutes + (index * gapMinutes);
    final isDriving = timingContext['isDriving'] == true;
    final isSleepWindow = timingContext['isSleepWindow'] == true;
    final isActiveDuringSleep = timingContext['isActiveDuringSleep'] == true;
    final isWorkWindow = timingContext['isWorkWindow'] == true;
    final isPhoneBusy = timingContext['isPhoneBusy'] == true;
    final isLongIdle = timingContext['isLongIdle'] == true;
    final workplaceSmokingRule =
        (timingContext['workplaceSmokingRule'] as String?) ?? '';
    final minutesUntilWake =
        (timingContext['minutesUntilWake'] as num?)?.toInt() ?? 0;
    final minutesUntilWorkEnd =
        (timingContext['minutesUntilWorkEnd'] as num?)?.toInt() ?? 0;

    if (isDriving) {
      minutes += 20;
    }

    if (isSleepWindow) {
      if (isActiveDuringSleep) {
        minutes = 3 + (index * 3);
      } else {
        minutes = minutesUntilWake + 5 + (index * 5);
      }
    }

    if (isWorkWindow) {
      if (workplaceSmokingRule == 'Hayır') {
        minutes = minutesUntilWorkEnd + 10 + (index * 5);
      } else if (workplaceSmokingRule == 'Sadece molalarda') {
        minutes = minutes < 30 ? 30 : minutes;
      }
    }

    if (isPhoneBusy && !isSleepWindow && !isDriving) {
      minutes += 15;
    }

    if (isLongIdle && !isSleepWindow && !isDriving) {
      minutes = minutes > 5 ? 5 + (index * 5) : minutes;
    }

    if (taskTitle.contains('120 dakika') || taskTitle.contains('2 saat')) {
      minutes += 20;
    } else if (taskTitle.contains('90 dakika')) {
      minutes += 10;
    }

    return Duration(minutes: minutes < 3 ? 3 : minutes);
  }

  String _buildBreathDeltaText({
    required double delta,
    required bool hasReference,
    required String comparisonMode,
  }) {
    if (!hasReference) {
      return context.t('breathNoReferenceYet');
    }

    final amount = delta.abs().toStringAsFixed(1);
    if (delta > 0.2) {
      return comparisonMode == 'previous'
          ? '${context.t('breathComparedPreviousImproved')} $amount${context.t('secShort')}'
          : '${context.t('breathComparedAverageImproved')} $amount${context.t('secShort')}';
    }
    if (delta < -0.2) {
      return comparisonMode == 'previous'
          ? '${context.t('breathComparedPreviousDeclined')} $amount${context.t('secShort')}'
          : '${context.t('breathComparedAverageDeclined')} $amount${context.t('secShort')}';
    }
    return comparisonMode == 'previous'
        ? context.t('breathComparedPreviousStable')
        : context.t('breathComparedAverageStable');
  }

  void _showRegistrationError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _validateRegistrationInputs() async {
    final records = await _storageService.loadSurveyHistory();
    final hasInitialSurvey = records.any((record) => record.type == 'initial');
    final hasBreathTest = records.any((record) => record.type == 'breath_test');
    return hasInitialSurvey && hasBreathTest;
  }

  Future<void> _createInitialProfileSnapshot() async {
    final records = await _storageService.loadSurveyHistory();
    final triggerMap = await _storageService.loadTriggerMapByRecordId();
    final contextMap = await _storageService.loadSurveyContextByRecordId();

    SurveyRecord? latestSurvey;
    SurveyRecord? latestBreath;
    for (final record in records.reversed) {
      if (latestSurvey == null &&
          (record.type == 'initial' || record.type == 'weekly')) {
        latestSurvey = record;
      }
      if (latestBreath == null && record.type == 'breath_test') {
        latestBreath = record;
      }
      if (latestSurvey != null && latestBreath != null) {
        break;
      }
    }

    if (latestSurvey == null) {
      throw StateError(
        'Initial/weekly survey record not found while creating profile snapshot.',
      );
    }
    if (latestBreath == null) {
      throw StateError(
        'Breath test record not found while creating profile snapshot.',
      );
    }

    final latestContext = contextMap[latestSurvey.id];
    final healthConditions =
        (latestContext?['healthConditions'] as List<String>?) ??
        const <String>[];
    final triggers = triggerMap[latestSurvey.id] ?? const <String>[];

    await _storageService.saveUserProfileSnapshot(
      UserProfileSnapshot(
        id: 'profile_init_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        riskScore: latestSurvey.riskScore,
        packsPerDay: latestSurvey.packsPerDay,
        firstCigaretteRange: 'unknown',
        smokeFreeRange: 'unknown',
        consecutiveSmokingHabit:
            latestSurvey.consecutiveSmokingHabit ?? 'Hayır',
        consecutiveSmokingCount: latestSurvey.consecutiveSmokingCount,
        triggers: triggers,
        healthConditions: healthConditions,
        profession: (latestContext?['profession'] as String?) ?? 'Belirtilmedi',
        sleepTime: (latestContext?['sleepTime'] as String?) ?? '21:00',
        wakeTime: (latestContext?['wakeTime'] as String?) ?? '07:00',
        latestExhaleSeconds: latestBreath.exhaleTestSeconds,
        latestInhaleSeconds: latestBreath.inhaleTestSeconds,
      ),
    );
  }

  Future<void> _completeRegistration() async {
    if (_isCompletingRegistration || _registrationCompleted) {
      return;
    }

    setState(() {
      _isCompletingRegistration = true;
    });

    try {
      debugPrint('[CompleteRegistration] Started');
      final isValid = await _validateRegistrationInputs();
      if (!isValid) {
        debugPrint('[CompleteRegistration] Validation failed');
        _showRegistrationError('Lütfen eksik alanları doldurun.');
        return;
      }

      try {
        debugPrint(
          '[CompleteRegistration] Running _createInitialProfileSnapshot',
        );
        await _createInitialProfileSnapshot();
      } catch (error, stackTrace) {
        debugPrint('[CompleteRegistration] Profile creation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _showRegistrationError('Profil oluşturulamadı. Lütfen tekrar deneyin.');
        return;
      }

      debugPrint('[CompleteRegistration] Running loadBehaviorDashboard');
      try {
        await _storageService.loadBehaviorDashboard();
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] loadBehaviorDashboard failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        _showRegistrationError(
          'Risk analizi oluşturulamadı. Lütfen tekrar deneyin.',
        );
        return;
      }
      if (!mounted) {
        return;
      }
      final firstTask = context.t('firstTaskNoSmoke15');

      debugPrint('[CompleteRegistration] Creating first task: $firstTask');
      final createdAt = DateTime.now();
      const followUpDelay = Duration(minutes: 10);

      try {
        await _storageService.saveTaskResult(
          taskTitle: firstTask,
          taskResult: 'created',
          completedAt: createdAt,
        );
        debugPrint('[CompleteRegistration] saveTaskResult(created) ok');
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] saveTaskResult(created) failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      try {
        await NotificationService.scheduleFirstTaskTriggerNotification(
          taskDescription: firstTask,
          delay: followUpDelay,
        );
        debugPrint(
          '[CompleteRegistration] first task notification scheduled (10m)',
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] first task notification scheduling failed (non-blocking): $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      debugPrint('[CompleteRegistration] Saving completion flag');
      try {
        await _storageService.saveInitialRegistrationCompleted(true);
        await _storageService.saveIsProfileCompleted(true);
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] save registration flags failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        _showRegistrationError(
          'Kayıt bayrağı kaydedilemedi. Lütfen tekrar deneyin.',
        );
        return;
      }
      debugPrint('[CompleteRegistration] Refreshing Home metrics');
      await _loadHomeMetrics();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('registrationCompleted'))),
      );
      debugPrint('[CompleteRegistration] Completed successfully');
    } catch (error, stackTrace) {
      debugPrint('[CompleteRegistration] Failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showRegistrationError(
        'Kaydı tamamlanırken bir hata oluştu. Lütfen tekrar deneyin.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCompletingRegistration = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NoSmokeLogo(size: 28),
            const SizedBox(width: 10),
            Text(context.t('home')),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                '${context.t('welcome')}, ${widget.name}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${context.t('riskLevel')}: ${widget.riskLevel}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '${context.t('riskScore')}: ${_adaptiveRiskScore == 0 ? widget.riskScore : _adaptiveRiskScore} / 100',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                '${context.t('lastSurveyDate')}: ${_lastSurveyDateText == 'noRecordYet' ? context.t('noRecordYet') : _lastSurveyDateText}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                '${context.t('lastBreathTest')}: ${_lastBreathText == 'noRecordYet' ? context.t('noRecordYet') : _lastBreathText}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${context.t('dailyBreathStatus')}: ${context.t(_dailyBreathStatus)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${context.t('lastExhale')}: $_latestExhaleSeconds${context.t('secShort')} • ${context.t('lastInhale')}: $_latestInhaleSeconds${context.t('secShort')}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildBreathTrendCard(),
              const SizedBox(height: 16),
              _buildAdaptiveInsightsCard(),
              const SizedBox(height: 16),
              _buildTodayTaskCard(),
              const SizedBox(height: 12),
              if (_pendingFollowUps.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TaskFollowUpPage(),
                        ),
                      );
                      if (!mounted) {
                        return;
                      }
                      await _loadHomeMetrics();
                      await _restorePendingFollowUps();
                    },
                    child: Text(context.t('openTaskFollowUpScreen')),
                  ),
                ),
              const SizedBox(height: 16),
              _buildConsecutiveSmokingCard(),
              const SizedBox(height: 24),
              if (!_registrationCompleted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCompletingRegistration
                        ? null
                        : _completeRegistration,
                    child: Text(context.t('completeRegistration')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveInsightsCard() {
    final triggers = _riskyTriggers.isEmpty
        ? context.t('noRecordYet')
        : _riskyTriggers.join(', ');
    final hours = _riskyHours.isEmpty
        ? context.t('noRecordYet')
        : _riskyHours.join(', ');
    final breathTrend = _breathTrendText == 'Improving'
        ? context.t('trendImproving')
        : _breathTrendText == 'Declining'
        ? context.t('trendDeclining')
        : _breathTrendText == 'Stable'
        ? context.t('trendStable')
        : _breathTrendText;
    final progress = _progressSummaryText == 'Improving'
        ? context.t('trendImproving')
        : _progressSummaryText == 'Declining'
        ? context.t('trendDeclining')
        : _progressSummaryText == 'Stable'
        ? context.t('trendStable')
        : _progressSummaryText;
    final cadenceLabel = _planCadenceLevel == 'week'
        ? context.t('goal180CadenceWeek')
        : _planCadenceLevel == 'two_days'
        ? context.t('goal180CadenceTwoDays')
        : context.t('goal180CadenceOneDay');
    final guideText = _planCurrentDay >= 120
        ? (_failedTaskCount > _successfulTaskCount
              ? context.t('goal180GuideLateHard')
              : context.t('goal180GuideLate'))
        : _planCurrentDay >= 60
        ? (_failedTaskCount > _successfulTaskCount
              ? context.t('goal180GuideMidHard')
              : context.t('goal180GuideMid'))
        : context.t('goal180GuideEarly');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('adaptiveSummary'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('${context.t('riskyTriggers')}: $triggers'),
            const SizedBox(height: 6),
            Text('${context.t('riskyHours')}: $hours'),
            const SizedBox(height: 6),
            Text('${context.t('breathImprovementSummary')}: $breathTrend'),
            const SizedBox(height: 6),
            Text('${context.t('progressSummary')}: $progress'),
            const SizedBox(height: 6),
            Text('${context.t('predictedRiskTime')}: $_predictedRiskWindow'),
            const SizedBox(height: 6),
            Text('${context.t('predictedTrigger')}: $_predictedTrigger'),
            const SizedBox(height: 6),
            Text(
              '${context.t('predictionConfidence')}: %$_predictionConfidence',
            ),
            const SizedBox(height: 6),
            Text('${context.t('weeklyRiskTarget')}: $_weeklyRiskTarget / 100'),
            const SizedBox(height: 6),
            Text(
              '${context.t('goal180ProgressLabel')}: $_planCurrentDay / $_planTargetDays ${context.t('days')}',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('goal180RemainingLabel')}: $_planDaysRemaining ${context.t('days')}',
            ),
            const SizedBox(height: 6),
            Text('${context.t('goal180CadenceLabel')}: $cadenceLabel'),
            const SizedBox(height: 6),
            Text(guideText),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTaskCard() {
    final tasks = _todaysTasks.isEmpty
        ? <String>[context.t('noTaskToday')]
        : _todaysTasks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('todaysTasks'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_pendingFollowUps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${context.t('taskFollowUpPendingCount')}: ${_pendingFollowUps.length}',
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${context.t('successfulTaskCount')}: $_successfulTaskCount • ${context.t('failedTaskCount')}: $_failedTaskCount',
              ),
            ),
            ...tasks.map((task) {
              if (_todaysTasks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('- $task'),
                );
              }
              final state = _taskStates[task] ?? 'new';
              final translatedState = state == 'completed'
                  ? context.t('taskStateCompleted')
                  : state == 'failed'
                  ? context.t('taskStateFailed')
                  : state == 'deferred'
                  ? context.t('taskStateDeferred')
                  : context.t('taskStateNew');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('- $task'),
                    const SizedBox(height: 6),
                    Text(translatedState, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBreathTrendCard() {
    final maxValue = [
      _dailyAverage,
      _weeklyAverage,
      _monthlyAverage,
    ].reduce((a, b) => a > b ? a : b).clamp(1, 100).toDouble();
    final values = [
      (_dailyAverage / maxValue).clamp(0.0, 1.0),
      (_weeklyAverage / maxValue).clamp(0.0, 1.0),
      (_monthlyAverage / maxValue).clamp(0.0, 1.0),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('breathTrend'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTrendBar(context.t('daily'), values[0], _dailyAverage),
                _buildTrendBar(context.t('weekly'), values[1], _weeklyAverage),
                _buildTrendBar(
                  context.t('monthly'),
                  values[2],
                  _monthlyAverage,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${context.t('weeklyImprovement')}: ${_translateTrend(_weeklyImprovementText)}',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('monthlyImprovement')}: ${_translateTrend(_monthlyImprovementText)}',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('breathPreviousComparison')}: $_breathPreviousReportText',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('breathAverageComparison')}: $_breathAverageReportText',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendBar(String label, double ratio, double value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              height: 90,
              width: double.infinity,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FractionallySizedBox(
                heightFactor: ratio == 0 ? 0.02 : ratio,
                widthFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: ratio >= 0.7
                        ? Colors.green
                        : ratio >= 0.4
                        ? Colors.orange
                        : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '${value.toStringAsFixed(1)}${context.t('secShort')}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsecutiveSmokingCard() {
    final latest = _consecutiveSmokingLatestText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _consecutiveSmokingLatestText;
    final status = _consecutiveSmokingStatusText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _consecutiveSmokingStatusText;
    final trend = _consecutiveSmokingTrendText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _consecutiveSmokingTrendText == 'trendStable'
        ? context.t('trendStable')
        : _consecutiveSmokingTrendText == 'trendImproving'
        ? context.t('trendImproving')
        : _consecutiveSmokingTrendText == 'trendDeclining'
        ? context.t('trendDeclining')
        : _consecutiveSmokingTrendText;
    final previous = _consecutiveSmokingPreviousText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _consecutiveSmokingPreviousText == 'firstEvaluation'
        ? context.t('firstEvaluation')
        : _consecutiveSmokingPreviousText;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('chainSmokingTrend'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('${context.t('chainSmokingLatest')}: $latest'),
            const SizedBox(height: 6),
            Text('${context.t('status')}: $status'),
            const SizedBox(height: 6),
            Text('${context.t('progressRegression')}: $trend'),
            const SizedBox(height: 6),
            Text('${context.t('previousRecord')}: $previous'),
          ],
        ),
      ),
    );
  }
}
