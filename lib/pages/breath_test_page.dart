
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import '../services/storage_service.dart';
import 'home_page.dart';
import 'risk_result_page.dart';
import 'weekly_survey_page.dart';

class BreathTestPage extends StatefulWidget {
  final String name;
  final String packsPerDay;
  final bool navigateToHomeOnComplete;
  final bool askWeeklySurveyOnComplete;

  const BreathTestPage({
    super.key,
    this.name = 'User',
    this.packsPerDay = '1 paketten az',
    this.navigateToHomeOnComplete = false,
    this.askWeeklySurveyOnComplete = false,
  });

  @override
  State<BreathTestPage> createState() => _BreathTestPageState();
}

class _BreathTestPageState extends State<BreathTestPage> {
  final Stopwatch _stopwatch = Stopwatch();
  final StorageService _storageService = StorageService();
  Timer? _timer;
  int _currentTest = 1;
  int _test1Seconds = 0;
  int _test2Seconds = 0;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCurrentTest() {
    _timer?.cancel();
    _stopwatch.reset();
    _stopwatch.start();
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleBreathPressed() {
    if (!_isRunning) {
      return;
    }

    _stopwatch.stop();
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    if (_currentTest == 1) {
      _test1Seconds = _stopwatch.elapsed.inSeconds;
      setState(() {
        _currentTest = 2;
      });
      return;
    }

    _test2Seconds = _stopwatch.elapsed.inSeconds;
    unawaited(_navigateToResult());
  }

  Future<void> _navigateToResult() async {
    final averageSeconds = ((_test1Seconds + _test2Seconds) / 2).round();
    late final int riskScore;
    late final String riskLevel;

    if (averageSeconds <= 4) {
      riskScore = 85;
      riskLevel = 'KRİTİK';
    } else if (averageSeconds <= 7) {
      riskScore = 65;
      riskLevel = 'YÜKSEK';
    } else if (averageSeconds <= 10) {
      riskScore = 40;
      riskLevel = 'ORTA';
    } else {
      riskScore = 15;
      riskLevel = 'DÜŞÜK';
    }

    if (!mounted) {
      return;
    }

    if (widget.navigateToHomeOnComplete) {
      await _saveBreathResultAndOpenHome(riskScore);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RiskResultPage(
          name: widget.name,
          riskScore: riskScore,
          riskLevel: riskLevel,
          packsPerDay: widget.packsPerDay,
          exhaleTestSeconds: _test1Seconds,
          inhaleTestSeconds: _test2Seconds,
        ),
      ),
    );
  }

  Future<void> _saveBreathResultAndOpenHome(int baseRiskScore) async {
    final adjustedRiskScore = await _storageService.calculateAdjustedRiskScore(
      baseScore: baseRiskScore,
      exhaleSeconds: _test1Seconds,
      inhaleSeconds: _test2Seconds,
    );

    if (!mounted) {
      return;
    }

    final adjustedRiskLevel = adjustedRiskScore >= 80
        ? 'KRİTİK'
        : adjustedRiskScore >= 60
            ? 'YÜKSEK'
            : adjustedRiskScore >= 40
                ? 'ORTA'
                : 'DÜŞÜK';

    final record = SurveyRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      completedAt: DateTime.now(),
      type: 'breath_test',
      title: context.t('breathTestRecordTitle'),
      name: widget.name,
      packsPerDay: widget.packsPerDay,
      exhaleTestSeconds: _test1Seconds,
      inhaleTestSeconds: _test2Seconds,
      riskScore: adjustedRiskScore,
      riskLevel: adjustedRiskLevel,
    );
    await _storageService.saveSurveyRecord(record);
    await _storageService.saveUserProfileSnapshot(
      UserProfileSnapshot(
        id: 'profile_${record.id}',
        createdAt: record.completedAt,
        riskScore: adjustedRiskScore,
        packsPerDay: widget.packsPerDay,
        firstCigaretteRange: 'unknown',
        smokeFreeRange: 'unknown',
        consecutiveSmokingHabit: 'Hayır',
        consecutiveSmokingCount: null,
        triggers: const [],
        healthConditions: const [],
        profession: 'Belirtilmedi',
        sleepTime: '21:00',
        wakeTime: '07:00',
        latestExhaleSeconds: _test1Seconds,
        latestInhaleSeconds: _test2Seconds,
      ),
    );

    if (!mounted) {
      return;
    }

    if (widget.askWeeklySurveyOnComplete) {
      final wantsWeeklySurvey = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(context.t('weeklySurvey')),
            content: const Text('Haftalık anketi şimdi yapmak ister misiniz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.t('no')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.t('yes')),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      if (wantsWeeklySurvey == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WeeklySurveyPage(
              navigateToHomeAfterSave: true,
              nameSeed: widget.name,
            ),
          ),
        );
        return;
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          name: widget.name,
          riskScore: adjustedRiskScore,
          riskLevel: adjustedRiskLevel,
        ),
      ),
    );
  }

  String _getInstruction() {
    if (_currentTest == 1) {
      return context.t('test1Instruction');
    }

    return context.t('test2Instruction');
  }

  String _getCurrentTestName() {
    return _currentTest == 1 ? context.t('test1Name') : context.t('test2Name');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('breathTest')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              '${context.t('test')} $_currentTest / 2',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getCurrentTestName(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Text(
              _getInstruction(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            Text(
              '${_stopwatch.elapsed.inSeconds}',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (!_isRunning)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _startCurrentTest,
                  child: Text(
                    context.t('start'),
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _handleBreathPressed,
                  child: Text(
                    context.t('iBreathed'),
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
