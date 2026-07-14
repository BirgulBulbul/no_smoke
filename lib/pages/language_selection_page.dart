import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../main.dart';
import '../models/survey_record.dart';
import '../services/language_service.dart';
import '../services/storage_service.dart';
import '../widgets/no_smoke_logo.dart';
import 'breath_test_page.dart';
import 'survey_page.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String _selectedCode = 'tr';

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
      if (record.type == 'breath_test' || record.type == 'weekly' || record.type == 'initial') {
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

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final code = await LanguageService.loadSelectedLanguageCode();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedCode = code;
    });
  }

  Future<void> _continue(BuildContext context, String languageCode) async {
    await LanguageService.saveSelectedLanguageCode(languageCode);
    if (!context.mounted) {
      return;
    }
    NoSmokeApp.setLocale(context, LanguageService.supportedLanguages[languageCode] ?? const Locale('tr'));

    final storage = StorageService();
    final records = await storage.loadSurveyHistory();
    final hasInitialSetup = records.any((record) => record.type == 'initial');

    if (!context.mounted) {
      return;
    }

    if (!hasInitialSetup) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SurveyPage()),
      );
      return;
    }

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

  Widget _buildLanguageButton({
    required String code,
    required String label,
    required bool primary,
  }) {
    final selected = _selectedCode == code;
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        label,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );

    if (primary) {
      return FilledButton(
        onPressed: () => _continue(context, code),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: selected ? const BorderSide(color: Colors.white, width: 1.5) : null,
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: () => _continue(context, code),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(
          color: selected ? Colors.white : Colors.white70,
          width: selected ? 2 : 1.2,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const NoSmokeLogo(size: 156, showLabel: true),
                  const SizedBox(height: 28),
                  Text(
                    context.t('selectLanguage'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildLanguageButton(code: 'tr', label: '🇹🇷 Türkçe', primary: true),
                  const SizedBox(height: 12),
                  _buildLanguageButton(code: 'en', label: '🇬🇧 English', primary: false),
                  const SizedBox(height: 12),
                  _buildLanguageButton(code: 'de', label: '🇩🇪 Deutsch', primary: false),
                  const SizedBox(height: 12),
                  _buildLanguageButton(code: 'ar', label: '🇸🇦 العربية', primary: false),
                  const SizedBox(height: 12),
                  _buildLanguageButton(code: 'fr', label: '🇫🇷 Français', primary: false),
                  const SizedBox(height: 12),
                  _buildLanguageButton(code: 'es', label: '🇪🇸 Español', primary: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}