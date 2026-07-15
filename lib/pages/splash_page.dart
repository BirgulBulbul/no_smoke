import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/survey_record.dart';
import '../services/language_service.dart';
import '../services/storage_service.dart';
import '../widgets/no_smoke_logo.dart';
import 'breath_test_page.dart';
import 'language_selection_page.dart';
import 'trial_info_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _routeFromSplash();
  }

  Future<void> _routeFromSplash() async {
    // Dil seçimi yapılmış mı kontrol et
    final hasSavedLanguage = await LanguageService.hasSavedLanguageSelection();
    if (!mounted) return;

    // Dil seçimi yapılmışsa, normal akışı izle
    if (hasSavedLanguage) {
      final selectedCode = await LanguageService.loadSelectedLanguageCode();
      if (!mounted) return;
      
      NoSmokeApp.setLocale(
        context,
        LanguageService.supportedLanguages[selectedCode] ?? const Locale('en'),
      );

      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;

      _goNext();
      return;
    }

    // Dil seçimi yapılmamışsa, cihaz dilini kontrol et
    final deviceLanguageCode = LanguageService.getDeviceLanguageCode();
    
    if (deviceLanguageCode != null) {
      // Cihaz dili destekleniyor → otomatik seç
      await LanguageService.saveSelectedLanguageCode(deviceLanguageCode);
      if (!mounted) return;
      
      NoSmokeApp.setLocale(
        context,
        LanguageService.supportedLanguages[deviceLanguageCode] ?? const Locale('en'),
      );

      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;

      _goNext();
      return;
    }

    // Cihaz dili desteklenmiyor → dil seçme sayfası açılır
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageSelectionPage()),
      );
    }
  }

  Map<String, dynamic> _resolveHomeSeed(List<SurveyRecord> records) {
    String name = 'User';
    String packsPerDay = '1 paketten az';
    int riskScore = 40;
    String riskLevel = 'ORTA';

    for (final record in records.reversed) {
      if (record.name.toString().trim().isNotEmpty) {
        name = record.name.toString().trim();
        break;
      }
    }

    for (final record in records.reversed) {
      if (record.type == 'breath_test' ||
          record.type == 'weekly' ||
          record.type == 'initial') {
        packsPerDay = record.packsPerDay;
        riskScore = record.riskScore;
        riskLevel = record.riskLevel;
        break;
      }
    }

    return {
      'name': name,
      'packsPerDay': packsPerDay,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
    };
  }

  Future<void> _goNext() async {
    if (!mounted) return;

    final storage = StorageService();
    final records = await storage.loadSurveyHistory();
    final hasInitialSetup = records.any((record) => record.type == 'initial');

    if (!mounted) return;

    // İlk kez kurulum yapılmamışsa TrialInfoPage'e git
    if (!hasInitialSetup) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrialInfoPage()),
      );
      return;
    }

    // Setup yapılmışsa BreathTestPage'e git
    final seed = _resolveHomeSeed(records);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BreathTestPage(
          name: seed['name'] as String,
          packsPerDay: seed['packsPerDay'] as String,
          navigateToHomeOnComplete: true,
          askWeeklySurveyOnComplete: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [const NoSmokeLogo(size: 180, showLabel: true)],
            ),
          ),
        ),
      ),
    );
  }
}
