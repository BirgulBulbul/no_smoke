
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
  final List<int> _attemptSeconds = <int>[];
  bool _isResting = false;
  int _restSecondsLeft = 0;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCurrentTest() {
    if (_isResting) {
      return;
    }
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

    final seconds = _stopwatch.elapsed.inSeconds;
    _attemptSeconds.add(seconds);

    if (_attemptSeconds.length >= 3) {
      unawaited(_navigateToResult());
      return;
    }

    _startRestInterval();
  }

  void _startRestInterval() {
    _timer?.cancel();
    setState(() {
      _isResting = true;
      _restSecondsLeft = 20;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _restSecondsLeft -= 1;
      });

      if (_restSecondsLeft <= 0) {
        timer.cancel();
        if (!mounted) {
          return;
        }
        setState(() {
          _isResting = false;
          _currentTest = _attemptSeconds.length + 1;
        });
      }
    });
  }

  Future<void> _navigateToResult() async {
    final sorted = [..._attemptSeconds]..sort((a, b) => b.compareTo(a));
    final bestSeconds = sorted.first;
    final averageSeconds =
        (_attemptSeconds.reduce((a, b) => a + b) / _attemptSeconds.length)
            .round();
    final consistencyGap = sorted.length >= 2 ? (sorted[0] - sorted[1]) : 0;
    late int riskScore;
    late final String riskLevel;

    if (bestSeconds <= 5) {
      riskScore = 85;
      riskLevel = 'KRİTİK';
    } else if (bestSeconds <= 9) {
      riskScore = 65;
      riskLevel = 'YÜKSEK';
    } else if (bestSeconds <= 14) {
      riskScore = 45;
      riskLevel = 'ORTA';
    } else {
      riskScore = 20;
      riskLevel = 'DÜŞÜK';
    }

    if (consistencyGap >= 4) {
      // Low repeatability means measurements may be unstable, keep risk cautious.
      riskScore = (riskScore + 6).clamp(0, 100);
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
          exhaleTestSeconds: bestSeconds,
          inhaleTestSeconds: averageSeconds,
        ),
      ),
    );
  }

  Future<void> _saveBreathResultAndOpenHome(int baseRiskScore) async {
    final sorted = [..._attemptSeconds]..sort((a, b) => b.compareTo(a));
    final bestSeconds = sorted.first;
    final averageSeconds =
        (_attemptSeconds.reduce((a, b) => a + b) / _attemptSeconds.length)
            .round();

    final adjustedRiskScore = await _storageService.calculateAdjustedRiskScore(
      baseScore: baseRiskScore,
      exhaleSeconds: bestSeconds,
      inhaleSeconds: averageSeconds,
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
      exhaleTestSeconds: bestSeconds,
      inhaleTestSeconds: averageSeconds,
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
        latestExhaleSeconds: bestSeconds,
        latestInhaleSeconds: averageSeconds,
      ),
    );

    if (!mounted) {
      return;
    }

    late final String baseRiskLevel;
    if (baseRiskScore >= 80) {
      baseRiskLevel = 'KRİTİK';
    } else if (baseRiskScore >= 60) {
      baseRiskLevel = 'YÜKSEK';
    } else if (baseRiskScore >= 40) {
      baseRiskLevel = 'ORTA';
    } else {
      baseRiskLevel = 'DÜŞÜK';
    }

    if (widget.askWeeklySurveyOnComplete) {
      final wantsWeeklySurvey = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(context.t('weeklySurvey')),
            content: Text(context.t('weeklySurveyPromptAsk')),
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RiskResultPage(
            name: widget.name,
            riskScore: baseRiskScore,
            riskLevel: baseRiskLevel,
            packsPerDay: widget.packsPerDay,
            exhaleTestSeconds: bestSeconds,
            inhaleTestSeconds: averageSeconds,
          ),
        ),
      );
      return;
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
    if (_isResting) {
      return 'Kisa dinlenme: normal nefes al. Sonraki denemeye hazirlan.';
    }
    return 'Dik otur, burundan derin nefes al, 2 saniye tut ve tek seferde kontrollu ver. 3 deneme yapilacak, en iyi skor kaydedilir.';
  }

  String _getCurrentTestName() {
    return 'Nefes dayanimi denemesi';
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
              '${context.t('test')} $_currentTest / 3',
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
              _isResting
                  ? '$_restSecondsLeft'
                  : '${_stopwatch.elapsed.inSeconds}',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_attemptSeconds.isNotEmpty)
              Text(
                'Denemeler: ${_attemptSeconds.join('s | ')}s',
                textAlign: TextAlign.center,
              ),
            const Spacer(),
            if (!_isRunning && !_isResting)
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
            else if (_isResting)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: null,
                  child: Text(
                    'Dinlenme: $_restSecondsLeft sn',
                    style: const TextStyle(fontSize: 20),
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
