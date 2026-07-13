
import 'dart:async';

import 'package:flutter/material.dart';

import 'risk_result_page.dart';

class BreathTestPage extends StatefulWidget {
  const BreathTestPage({super.key});

  @override
  State<BreathTestPage> createState() => _BreathTestPageState();
}

class _BreathTestPageState extends State<BreathTestPage> {
  final Stopwatch _stopwatch = Stopwatch();
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
    _navigateToResult();
  }

  void _navigateToResult() {
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

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RiskResultPage(
          name: 'Kullanıcı',
          riskScore: riskScore,
          riskLevel: riskLevel,
          exhaleTestSeconds: _test1Seconds,
          inhaleTestSeconds: _test2Seconds,
        ),
      ),
    );
  }

  String _getInstruction() {
    if (_currentTest == 1) {
      return 'Test 1: Nefesinizi normal şekilde dışarı verin.\n\nİlk nefes alma ihtiyacı hissettiğinizde butona basın.';
    }

    return 'Test 2: Derin bir nefes alın ve tutmaya çalışın.\n\nİlk nefes alma ihtiyacı hissettiğinizde butona basın.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nefes Testi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'Test $_currentTest / 2',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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
                  child: const Text(
                    'Başla',
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
                  child: const Text(
                    'Nefes Aldım',
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
