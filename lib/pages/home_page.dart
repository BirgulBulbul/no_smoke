import 'package:flutter/material.dart';

import '../core/app_texts.dart';
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
  String _lastSurveyDateText = '...';
  String _lastBreathText = '...';
  String _breathTrendText = '...';
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

  Future<void> _loadHomeMetrics() async {
    final lastDate = await _storageService.loadLastSurveyDate();
    final latestBreath = await _storageService.loadLatestBreathRecord();
    final metrics = await _storageService.loadBreathMetrics();
    final consecutiveSmokingSummary = await _storageService.loadConsecutiveSmokingSummary();
    final behavior = await _storageService.loadBehaviorDashboard();
    if (!mounted) return;
    setState(() {
      _lastSurveyDateText = lastDate == null
          ? 'noRecordYet'
          : '${lastDate.day}/${lastDate.month}/${lastDate.year}';
      _lastBreathText = latestBreath == null
          ? 'noRecordYet'
          : '${latestBreath.completedAt.day}/${latestBreath.completedAt.month}/${latestBreath.completedAt.year} • ${latestBreath.exhaleTestSeconds}${context.t('secShort')} / ${latestBreath.inhaleTestSeconds}${context.t('secShort')}';
      _dailyAverage = metrics['dailyAverage'] ?? 0;
      _weeklyAverage = metrics['weeklyAverage'] ?? 0;
      _monthlyAverage = metrics['monthlyAverage'] ?? 0;
      _adaptiveRiskScore = behavior.riskScore;
      _riskyTriggers = behavior.riskyTriggers;
      _riskyHours = behavior.riskyHours;
      _breathTrendText = behavior.breathTrend;
      _progressSummaryText = behavior.progressSummary;
      _todaysTasks = behavior.todaysTasks;
      _predictedRiskWindow = behavior.predictedRiskWindow;
      _predictedTrigger = behavior.predictedTrigger;
      _predictionConfidence = behavior.predictionConfidence;
      _weeklyRiskTarget = behavior.plan.weeklyRiskTarget;
      _consecutiveSmokingLatestText = consecutiveSmokingSummary['latest'] ?? context.t('noRecordYet');
      _consecutiveSmokingPreviousText = consecutiveSmokingSummary['previous'] ?? context.t('noRecordYet');
      _consecutiveSmokingTrendText = consecutiveSmokingSummary['trend'] ?? context.t('noRecordYet');
      _consecutiveSmokingStatusText = consecutiveSmokingSummary['status'] ?? context.t('noRecordYet');
    });
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(height: 16),
              _buildBreathTrendCard(),
              const SizedBox(height: 16),
              _buildAdaptiveInsightsCard(),
              const SizedBox(height: 16),
              _buildTodayTaskCard(),
              const SizedBox(height: 16),
              _buildConsecutiveSmokingCard(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: Text(context.t('backToStart')),
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
            ...tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('- $task'),
                )),
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
