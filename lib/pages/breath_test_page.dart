
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
      return 'Kısa dinlenme: Normal nefes alın.\nSonraki denemeye hazırlanın.';
    }
    return 'Dik oturun, burundan derin nefes alın, \n2 saniye tutun ve tek seferde kontrollü verin.\n\n3 deneme yapılacak, en iyi skor kaydedilir.';
  }

  String _getCurrentTestName() {
    return 'Nefes dayanimi denemesi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSeconds = _isResting
        ? _restSecondsLeft
        : _stopwatch.elapsed.inSeconds;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('breathTest')),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Progress Indicator - Visual dots showing test progress
              _buildProgressIndicator(),
              const SizedBox(height: 32),
              
              // Instruction Card with professional styling
              _buildInstructionCard(context),
              const SizedBox(height: 40),
              
              // Professional Timer Display
              _buildTimerDisplay(currentSeconds),
              const SizedBox(height: 24),
              
              // Previous Attempts Display
              if (_attemptSeconds.isNotEmpty)
                _buildAttemptsDisplay(),
              
              const SizedBox(height: 40),
              
              // Action Buttons
              _buildActionButtons(context),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Text(
          'Deneme Ilerlemesi',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final testNumber = index + 1;
            final isCompleted = testNumber < _currentTest;
            final isCurrent = testNumber == _currentTest;
            
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? Colors.green
                            : isCurrent
                                ? Colors.blue
                                : Colors.grey[300],
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 28,
                              )
                            : Text(
                                testNumber.toString(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : Colors.grey[600],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_attemptSeconds.length >= testNumber ? _attemptSeconds[testNumber - 1] : '-'}s',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildInstructionCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.blue[100]!,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isResting ? Icons.psychology : Icons.info,
                  color: Colors.blue[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  _isResting ? 'Dinlenme' : 'Talimatlar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getInstruction(),
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(int seconds) {
    final isResting = _isResting;
    
    return Column(
      children: [
        Text(
          isResting ? 'KALAN SÜRESİ' : 'DAYANIKLILIK',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: isResting ? Colors.orange[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isResting ? Colors.orange[200]! : Colors.blue[200]!,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                seconds.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: isResting ? Colors.orange[700] : Colors.blue[700],
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isResting ? 'Saniye' : 'Saniye',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttemptsDisplay() {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Önceki Denemeler',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_attemptSeconds.length, (index) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    'Deneme ${index + 1}: ${_attemptSeconds[index]}s',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (!_isRunning && !_isResting) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _startCurrentTest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow, size: 24),
              const SizedBox(width: 12),
              Text(
                context.t('start').toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_isResting) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[400],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: null,
          child: Text(
            'Dinlenme - $_restSecondsLeft saniye kaldı',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _handleBreathPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 24),
              const SizedBox(width: 12),
              Text(
                context.t('iBreathed').toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
