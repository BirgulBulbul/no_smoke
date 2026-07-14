import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../pages/task_follow_up_page.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/no_smoke_logo.dart';

class HomePage extends StatefulWidget {
  final String name;
  final int riskScore;
  final String riskLevel;

  const HomePage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StorageService _storageService = StorageService();
  final Map<String, String> _taskStates = {};
  final Map<String, Timer> _taskFollowUpTimers = {};
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
  String _progressSummaryText = '...';
  String _predictedRiskWindow = '...';
  String _predictedTrigger = '...';
  int _predictionConfidence = 0;
  int _adaptiveRiskScore = 0;
  int _weeklyRiskTarget = 0;
  List<String> _riskyTriggers = const [];
  List<String> _riskyHours = const [];
  List<String> _todaysTasks = const [];
  String _consecutiveSmokingLatestText = '...';
  String _consecutiveSmokingPreviousText = '...';
  String _consecutiveSmokingTrendText = '...';
  String _consecutiveSmokingStatusText = '...';
  double _weeklyAverage = 0;
  double _monthlyAverage = 0;
  double _dailyAverage = 0;

  @override
  void initState() {
    super.initState();
    _loadHomeMetrics();
  }

  @override
  void dispose() {
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

  Future<void> _loadHomeMetrics() async {
    final registrationCompleted = await _storageService.loadInitialRegistrationCompleted();
    final lastDate = await _storageService.loadLastSurveyDate();
    final latestBreath = await _storageService.loadLatestBreathRecord();
    final metrics = await _storageService.loadBreathMetrics();
    final consecutiveSmokingSummary = await _storageService.loadConsecutiveSmokingSummary();
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
        final doneToday = latestBreath != null &&
          latestBreath.completedAt.year == now.year &&
          latestBreath.completedAt.month == now.month &&
          latestBreath.completedAt.day == now.day;
        _dailyBreathStatus = doneToday ? 'breathTestDoneToday' : 'breathTestPendingToday';
      _dailyAverage = metrics['dailyAverage'] ?? 0;
      _weeklyAverage = metrics['weeklyAverage'] ?? 0;
      _monthlyAverage = metrics['monthlyAverage'] ?? 0;
        _weeklyImprovementText = _calculateImprovementLabel(_weeklyAverage, _monthlyAverage);
        _monthlyImprovementText = _calculateImprovementLabel(_monthlyAverage, _dailyAverage);
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
      _consecutiveSmokingLatestText = consecutiveSmokingSummary['latest'] ?? context.t('noRecordYet');
      _consecutiveSmokingPreviousText = consecutiveSmokingSummary['previous'] ?? context.t('noRecordYet');
      _consecutiveSmokingTrendText = consecutiveSmokingSummary['trend'] ?? context.t('noRecordYet');
      _consecutiveSmokingStatusText = consecutiveSmokingSummary['status'] ?? context.t('noRecordYet');
      for (final task in _todaysTasks) {
        _taskStates.putIfAbsent(task, () => 'new');
      }
      _pendingFollowUps = pendingFollowUps;
    });
  }

  Duration _resolveInitialTaskDelay(String taskTitle) {
    if (taskTitle.contains('60 dakika')) {
      return const Duration(minutes: 60);
    }
    if (taskTitle.contains('15 dakika')) {
      return const Duration(minutes: 15);
    }
    return const Duration(minutes: 30);
  }

  Future<void> _completeRegistration() async {
    if (_isCompletingRegistration || _registrationCompleted) {
      return;
    }

    setState(() {
      _isCompletingRegistration = true;
    });

    try {
      final behavior = await _storageService.loadBehaviorDashboard();
      final firstTask = behavior.todaysTasks.isEmpty ? null : behavior.todaysTasks.first;

      if (firstTask != null) {
        final createdAt = DateTime.now();
        final followUpDelay = _resolveInitialTaskDelay(firstTask);
        final followUpAt = createdAt.add(followUpDelay);

        await _storageService.saveTaskResult(
          taskTitle: firstTask,
          taskResult: 'created',
          completedAt: createdAt,
        );
        await _storageService.saveTaskFollowUp(
          taskTitle: firstTask,
          scheduledAt: followUpAt,
        );
        await NotificationService.scheduleTaskFollowUpReminder(
          taskTitle: firstTask,
          delay: followUpDelay,
        );
        _scheduleLocalFollowUp(firstTask, followUpAt);
      }

      await _storageService.saveInitialRegistrationCompleted(true);
      await _loadHomeMetrics();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('registrationCompleted'))),
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
                        MaterialPageRoute(builder: (_) => const TaskFollowUpPage()),
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
                    onPressed: _isCompletingRegistration ? null : _completeRegistration,
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
    final triggers = _riskyTriggers.isEmpty ? context.t('noRecordYet') : _riskyTriggers.join(', ');
    final hours = _riskyHours.isEmpty ? context.t('noRecordYet') : _riskyHours.join(', ');
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
            Text('${context.t('predictionConfidence')}: %$_predictionConfidence'),
            const SizedBox(height: 6),
            Text('${context.t('weeklyRiskTarget')}: $_weeklyRiskTarget / 100'),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTaskCard() {
    final tasks = _todaysTasks.isEmpty ? <String>[context.t('noTaskToday')] : _todaysTasks;
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
                child: Text('${context.t('taskFollowUpPendingCount')}: ${_pendingFollowUps.length}'),
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
                    Text(
                      translatedState,
                      style: const TextStyle(fontSize: 12),
                    ),
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
    final maxValue = [_dailyAverage, _weeklyAverage, _monthlyAverage].reduce((a, b) => a > b ? a : b).clamp(1, 100).toDouble();
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
                _buildTrendBar(context.t('monthly'), values[2], _monthlyAverage),
              ],
            ),
            const SizedBox(height: 10),
            Text('${context.t('weeklyImprovement')}: ${_translateTrend(_weeklyImprovementText)}'),
            const SizedBox(height: 6),
            Text('${context.t('monthlyImprovement')}: ${_translateTrend(_monthlyImprovementText)}'),
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
                    color: ratio >= 0.7 ? Colors.green : ratio >= 0.4 ? Colors.orange : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
            Text('${value.toStringAsFixed(1)}${context.t('secShort')}', style: const TextStyle(fontSize: 11)),
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
