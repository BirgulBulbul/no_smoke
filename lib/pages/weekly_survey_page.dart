
import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import 'breath_test_page.dart';
import 'home_page.dart';
import '../services/storage_service.dart';
import '../widgets/consecutive_smoking_section.dart';
import '../widgets/packs_per_day_section.dart';

class WeeklySurveyPage extends StatefulWidget {
  final bool navigateToHomeAfterSave;
  final String? nameSeed;

  const WeeklySurveyPage({
    super.key,
    this.navigateToHomeAfterSave = false,
    this.nameSeed,
  });

  @override
  State<WeeklySurveyPage> createState() => _WeeklySurveyPageState();
}

class _WeeklySurveyPageState extends State<WeeklySurveyPage> {
  final StorageService _storageService = StorageService();
  final TextEditingController _noteController = TextEditingController();
  bool _detailedMode = false;
  bool _autoDetailedByRisk = false;
  String _mood = 'Orta';
  String _packOption = '1 paketten az';
  String? _highPackOption;
  String? _consecutiveSmokingHabit;
  String? _consecutiveSmokingCount;
  String _deltaVsLastWeek = 'same';
  String _medicationUse = 'regular';
  bool _sideEffects = false;
  bool _usedCounselingOrQuitline = false;

  int _avgCigarettesPerDay = 8;
  int _lapseCount = 0;
  int _cravingAvg = 5;
  int _cravingMax = 7;
  int _alcoholDays = 0;
  int _socialSmokingContextDays = 1;

  int _withdrawIrritability = 1;
  int _withdrawAnxiety = 1;
  int _withdrawSleep = 1;
  int _withdrawConcentration = 1;
  int _withdrawAppetite = 1;

  int _triggerCoffeeDays = 4;
  int _triggerMealDays = 4;
  int _triggerDrivingDays = 2;
  int _triggerStressDays = 5;
  int _triggerPhoneDays = 3;
  int _triggerSocialDays = 3;
  int _triggerAlcoholDays = 1;

  int _medicationAdherence = 8;
  int _familySupport = 6;
  int _selfEfficacy = 6;
  int _motivation = 7;
  int _weeklyCompletionRate = 6;
  String _dailyTaskAdherenceLevel = 'orta';
  String _commandBurdenLevel = 'orta';

  String get _resolvedPacksPerDay {
    if (_packOption == '3+ paket') {
      return _highPackOption ?? '4 paket';
    }
    return _packOption;
  }

  @override
  void initState() {
    super.initState();
    _prepareModeFromRecentRisk();
  }

  Future<void> _prepareModeFromRecentRisk() async {
    final records = await _storageService.loadSurveyHistory();
    SurveyRecord? latestWeekly;
    for (final record in records.reversed) {
      if (record.type == 'weekly') {
        latestWeekly = record;
        break;
      }
    }

    final recentRisk = latestWeekly?.riskScore ?? 0;
    if (recentRisk >= 60 && mounted) {
      setState(() {
        _autoDetailedByRisk = true;
        _detailedMode = true;
      });
    }
  }

  Future<void> _saveWeeklySurvey() async {
    final now = DateTime.now();
    final recordId = now.millisecondsSinceEpoch.toString();
    final weeklyPayload = _detailedMode
        ? _buildWeeklyPayload()
        : _buildQuickWeeklyPayload();
    final weeklyRiskScore = _calculateWeeklyRiskScore(weeklyPayload);
    final weeklyRiskLevel = _levelFromScore(weeklyRiskScore);
    final record = SurveyRecord(
      id: recordId,
      completedAt: now,
      type: 'weekly',
      title: context.t('weeklyRecordTitle'),
      name: 'User',
      packsPerDay: _resolvedPacksPerDay,
      exhaleTestSeconds: 0,
      inhaleTestSeconds: 0,
      riskScore: weeklyRiskScore,
      riskLevel: weeklyRiskLevel,
      consecutiveSmokingHabit: _consecutiveSmokingHabit,
      consecutiveSmokingCount: _consecutiveSmokingHabit == 'Evet' ? _consecutiveSmokingCount : null,
    );
    await _storageService.saveSurveyRecord(record);

    await _storageService.saveSurveyDetail(
      recordId: recordId,
      triggers: const [],
      healthConditions: const [],
      stressLevel: _mood,
      weeklyPayload: weeklyPayload,
    );

    await _storageService.saveUserProfileSnapshot(
      UserProfileSnapshot(
        id: 'profile_$recordId',
        createdAt: now,
        riskScore: record.riskScore,
        packsPerDay: _resolvedPacksPerDay,
        firstCigaretteRange: 'unknown',
        smokeFreeRange: 'unknown',
        consecutiveSmokingHabit: _consecutiveSmokingHabit ?? 'Hayır',
        consecutiveSmokingCount: _consecutiveSmokingHabit == 'Evet' ? _consecutiveSmokingCount : null,
        triggers: const [],
        healthConditions: const [],
        profession: 'Belirtilmedi',
        sleepTime: '21:00',
        wakeTime: '07:00',
        latestExhaleSeconds: 0,
        latestInhaleSeconds: 0,
      ),
    );
  }

  Map<String, dynamic> _buildWeeklyPayload() {
    return {
      'avgCigarettesPerDay': _avgCigarettesPerDay,
      'deltaVsLastWeek': _deltaVsLastWeek,
      'lapseCount': _lapseCount,
      'cravingAvg': _cravingAvg,
      'cravingMax': _cravingMax,
      'withdrawal': {
        'irritability': _withdrawIrritability,
        'anxiety': _withdrawAnxiety,
        'sleepProblem': _withdrawSleep,
        'concentrationProblem': _withdrawConcentration,
        'appetiteIncrease': _withdrawAppetite,
      },
      'triggerExposureDays': {
        'coffee': _triggerCoffeeDays,
        'meal': _triggerMealDays,
        'driving': _triggerDrivingDays,
        'stress': _triggerStressDays,
        'phone': _triggerPhoneDays,
        'social': _triggerSocialDays,
        'alcohol': _triggerAlcoholDays,
      },
      'alcoholDays': _alcoholDays,
      'socialSmokingContextDays': _socialSmokingContextDays,
      'treatment': {
        'medicationUse': _medicationUse,
        'sideEffects': _sideEffects,
        'adherence': _medicationAdherence,
      },
      'support': {
        'usedCounselingOrQuitline': _usedCounselingOrQuitline,
        'familySupport': _familySupport,
      },
      'selfEfficacy': _selfEfficacy,
      'motivation': _motivation,
      'task': {
        'weeklyCompletionRate': _weeklyCompletionRate,
        'dailyTaskAdherenceLevel': _dailyTaskAdherenceLevel,
        'commandBurdenLevel': _commandBurdenLevel,
        'mostHelpfulCategory': 'breath',
      },
    };
  }

  Map<String, dynamic> _buildQuickWeeklyPayload() {
    final moodLower = _mood.toLowerCase();
    final isGood = moodLower == 'iyi';
    final isBad = moodLower == 'kötü' || moodLower == 'kotu';
    final packAvg = _estimatedDailyCigarettes(_resolvedPacksPerDay);
    final lapseFromConsecutive = _consecutiveSmokingHabit == 'Evet'
        ? int.tryParse(_consecutiveSmokingCount ?? '1') ?? 1
        : 0;

    final motivation = isGood
        ? 8
        : isBad
        ? 4
        : 6;
    final selfEfficacy = isGood
        ? 8
        : isBad
        ? 4
        : 6;
    final stressTriggerDays = isGood
        ? 2
        : isBad
        ? 6
        : 4;
    final cravingAvg = isGood
        ? 3
        : isBad
        ? 7
        : 5;
    final completion = isGood
        ? 8
        : isBad
        ? 4
        : 6;

    return {
      'avgCigarettesPerDay': packAvg,
      'deltaVsLastWeek': isBad
          ? 'increased'
          : isGood
          ? 'decreased'
          : 'same',
      'lapseCount': lapseFromConsecutive,
      'cravingAvg': cravingAvg,
      'cravingMax': (cravingAvg + 2).clamp(0, 10),
      'withdrawal': {
        'irritability': isBad ? 2 : 1,
        'anxiety': isBad ? 2 : 1,
        'sleepProblem': isBad ? 2 : 1,
        'concentrationProblem': isBad ? 2 : 1,
        'appetiteIncrease': isBad ? 2 : 1,
      },
      'triggerExposureDays': {
        'coffee': 3,
        'meal': 3,
        'driving': 2,
        'stress': stressTriggerDays,
        'phone': 3,
        'social': 3,
        'alcohol': isBad ? 2 : 1,
      },
      'alcoholDays': isBad ? 2 : 1,
      'socialSmokingContextDays': isBad ? 4 : 2,
      'treatment': {
        'medicationUse': 'regular',
        'sideEffects': false,
        'adherence': isBad ? 5 : 7,
      },
      'support': {
        'usedCounselingOrQuitline': false,
        'familySupport': isBad ? 5 : 7,
      },
      'selfEfficacy': selfEfficacy,
      'motivation': motivation,
      'task': {
        'weeklyCompletionRate': completion,
        'dailyTaskAdherenceLevel': isGood
            ? 'cok'
            : isBad
            ? 'az'
            : 'orta',
        'commandBurdenLevel': isBad ? 'cok' : 'orta',
        'mostHelpfulCategory': 'breath',
      },
    };
  }

  int _estimatedDailyCigarettes(String packOption) {
    switch (packOption) {
      case '1 paketten az':
        return 8;
      case '1 paket':
        return 20;
      case '1.5 paket':
        return 30;
      case '2 paket':
        return 40;
      case '3 paket':
        return 60;
      case '4 paket':
        return 80;
      case '5+ paket':
        return 100;
      default:
        return 12;
    }
  }

  int _calculateWeeklyRiskScore(Map<String, dynamic> payload) {
    final avgCigs = payload['avgCigarettesPerDay'] as int? ?? 0;
    final delta = payload['deltaVsLastWeek']?.toString() ?? 'same';
    final lapseCount = payload['lapseCount'] as int? ?? 0;
    final cravingMax = payload['cravingMax'] as int? ?? 0;
    final motivation = payload['motivation'] as int? ?? 0;
    final selfEfficacy = payload['selfEfficacy'] as int? ?? 0;
    final alcoholDays = payload['alcoholDays'] as int? ?? 0;
    final socialDays = payload['socialSmokingContextDays'] as int? ?? 0;

    final withdrawal = payload['withdrawal'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final withdrawalSum =
        (withdrawal['irritability'] as int? ?? 0) +
        (withdrawal['anxiety'] as int? ?? 0) +
        (withdrawal['sleepProblem'] as int? ?? 0) +
        (withdrawal['concentrationProblem'] as int? ?? 0) +
        (withdrawal['appetiteIncrease'] as int? ?? 0);

    final trigger = payload['triggerExposureDays'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final triggerSum =
        (trigger['coffee'] as int? ?? 0) +
        (trigger['meal'] as int? ?? 0) +
        (trigger['driving'] as int? ?? 0) +
        (trigger['stress'] as int? ?? 0) +
        (trigger['phone'] as int? ?? 0) +
        (trigger['social'] as int? ?? 0) +
        (trigger['alcohol'] as int? ?? 0);

    final task = payload['task'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final treatment = payload['treatment'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final completion = task['weeklyCompletionRate'] as int? ?? 0;
    final adherence = treatment['adherence'] as int? ?? 0;
    final dailyTaskAdherenceLevel =
      (task['dailyTaskAdherenceLevel']?.toString() ?? 'orta').toLowerCase();

    var c = avgCigs <= 0
        ? 0
        : avgCigs <= 5
        ? 20
        : avgCigs <= 10
        ? 40
        : avgCigs <= 20
        ? 65
        : 85;
    if (delta == 'increased') {
      c += 10;
    } else if (delta == 'decreased') {
      c -= 10;
    }
    c = c.clamp(0, 100);

    final l = (lapseCount * 15).clamp(0, 100);
    final w = ((withdrawalSum / 15) * 100).round().clamp(0, 100);
    var t = ((triggerSum / 49) * 100).round();
    if ((trigger['stress'] as int? ?? 0) >= 5) {
      t += 10;
    }
    if ((trigger['alcohol'] as int? ?? 0) >= 3) {
      t += 10;
    }
    t = t.clamp(0, 100);
    final a = (alcoholDays * 8 + socialDays * 6).clamp(0, 100);
    final m = ((10 - motivation).clamp(0, 10) * 10).clamp(0, 100);
    final s = ((10 - selfEfficacy).clamp(0, 10) * 10).clamp(0, 100);
    final p =
        (100 - ((0.6 * completion * 10) + (0.4 * adherence * 10)))
            .round()
            .clamp(0, 100);

    var score = (0.22 * c +
            0.18 * l +
            0.18 * w +
            0.14 * t +
            0.08 * a +
            0.08 * m +
            0.06 * s +
            0.06 * p)
        .round()
        .clamp(0, 100);
    if (dailyTaskAdherenceLevel == 'az') {
      score = (score + 8).clamp(0, 100);
    } else if (dailyTaskAdherenceLevel == 'cok') {
      score = (score - 6).clamp(0, 100);
    }
    if (lapseCount >= 3 && cravingMax >= 8) {
      score = (score + 12).clamp(0, 100);
    }
    if (lapseCount == 0 && selfEfficacy >= 8 && completion >= 8) {
      score = (score - 8).clamp(0, 100);
    }
    return score;
  }

  String _levelFromScore(int score) {
    if (score >= 75) {
      return 'KRİTİK';
    }
    if (score >= 50) {
      return 'YÜKSEK';
    }
    if (score >= 25) {
      return 'ORTA';
    }
    return 'DÜŞÜK';
  }

  Widget _intSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  Widget _buildSurveyModeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anket modu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Hizli (15 sn)'),
                  selected: !_detailedMode,
                  onSelected: (_) {
                    setState(() {
                      _detailedMode = false;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Detayli'),
                  selected: _detailedMode,
                  onSelected: (_) {
                    setState(() {
                      _detailedMode = true;
                    });
                  },
                ),
              ],
            ),
            if (_autoDetailedByRisk) ...[
              const SizedBox(height: 8),
              const Text(
                'Gecen hafta risk yuksek oldugu icin Detayli mod otomatik acildi.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<String> _resolveLatestUserName() async {
    final records = await _storageService.loadSurveyHistory();
    for (final record in records.reversed) {
      if (record.name.trim().isNotEmpty) {
        return record.name.trim();
      }
    }
    return 'User';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('weeklySurvey')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('weeklySavePrompt'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSurveyModeCard(),
            const SizedBox(height: 12),
            PacksPerDaySection(
              selectedPackOption: _packOption,
              selectedHighPackOption: _highPackOption,
              onPackOptionChanged: (value) {
                setState(() {
                  _packOption = value;
                  if (value != '3+ paket') {
                    _highPackOption = null;
                  } else {
                    _highPackOption ??= PacksPerDaySection.highPackOptions.first;
                  }
                });
              },
              onHighPackOptionChanged: (value) {
                setState(() {
                  _highPackOption = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _mood,
              decoration: InputDecoration(
                labelText: context.t('weeklyMood'),
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'İyi', child: Text(context.t('good'))),
                DropdownMenuItem(value: 'Orta', child: Text(context.t('stressMedium'))),
                DropdownMenuItem(value: 'Kötü', child: Text(context.t('bad'))),
              ],
              onChanged: (value) {
                setState(() {
                  _mood = value ?? 'Orta';
                });
              },
            ),
            if (_detailedMode) ...[
              const SizedBox(height: 12),
              _intSlider(
                label: 'Ortalama gunluk sigara',
                value: _avgCigarettesPerDay,
                min: 0,
                max: 40,
                onChanged: (v) => setState(() => _avgCigarettesPerDay = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: _deltaVsLastWeek,
                decoration: const InputDecoration(
                  labelText: 'Gecen haftaya gore',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'decreased', child: Text('Azaldi')),
                  DropdownMenuItem(value: 'same', child: Text('Ayni')),
                  DropdownMenuItem(value: 'increased', child: Text('Artti')),
                ],
                onChanged: (value) =>
                    setState(() => _deltaVsLastWeek = value ?? 'same'),
              ),
              const SizedBox(height: 12),
              _intSlider(
                label: 'Kayma sayisi (lapse)',
                value: _lapseCount,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _lapseCount = v),
              ),
              _intSlider(
                label: 'Craving ortalama (0-10)',
                value: _cravingAvg,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _cravingAvg = v),
              ),
              _intSlider(
                label: 'Craving maksimum (0-10)',
                value: _cravingMax,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _cravingMax = v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yoksunluk belirtileri (0-3)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _intSlider(
                label: 'Sinirlilik',
                value: _withdrawIrritability,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawIrritability = v),
              ),
              _intSlider(
                label: 'Anksiyete',
                value: _withdrawAnxiety,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawAnxiety = v),
              ),
              _intSlider(
                label: 'Uyku problemi',
                value: _withdrawSleep,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawSleep = v),
              ),
              _intSlider(
                label: 'Konsantrasyon problemi',
                value: _withdrawConcentration,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawConcentration = v),
              ),
              _intSlider(
                label: 'Istah artisi',
                value: _withdrawAppetite,
                min: 0,
                max: 3,
                onChanged: (v) => setState(() => _withdrawAppetite = v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tetikleyici maruziyeti (gun/saat 0-7)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _intSlider(
                label: 'Kahve',
                value: _triggerCoffeeDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerCoffeeDays = v),
              ),
              _intSlider(
                label: 'Yemek sonrasi',
                value: _triggerMealDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerMealDays = v),
              ),
              _intSlider(
                label: 'Arac kullanimi',
                value: _triggerDrivingDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerDrivingDays = v),
              ),
              _intSlider(
                label: 'Stres',
                value: _triggerStressDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerStressDays = v),
              ),
              _intSlider(
                label: 'Telefon',
                value: _triggerPhoneDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerPhoneDays = v),
              ),
              _intSlider(
                label: 'Sosyal ortam',
                value: _triggerSocialDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerSocialDays = v),
              ),
              _intSlider(
                label: 'Alkol tetigi',
                value: _triggerAlcoholDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _triggerAlcoholDays = v),
              ),
              _intSlider(
                label: 'Alkol kullanilan gun',
                value: _alcoholDays,
                min: 0,
                max: 7,
                onChanged: (v) => setState(() => _alcoholDays = v),
              ),
              _intSlider(
                label: 'Sigarali sosyal ortam gunu',
                value: _socialSmokingContextDays,
                min: 0,
                max: 7,
                onChanged: (v) =>
                    setState(() => _socialSmokingContextDays = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _medicationUse,
                decoration: const InputDecoration(
                  labelText: 'Tedavi/NRT kullanimi',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Yok')),
                  DropdownMenuItem(
                    value: 'irregular',
                    child: Text('Duzenli degil'),
                  ),
                  DropdownMenuItem(value: 'regular', child: Text('Duzenli')),
                ],
                onChanged: (value) =>
                    setState(() => _medicationUse = value ?? 'regular'),
              ),
              SwitchListTile(
                title: const Text('Ilac/NRT yan etkisi yasandi'),
                value: _sideEffects,
                onChanged: (v) => setState(() => _sideEffects = v),
              ),
              SwitchListTile(
                title: const Text('Danismanlik/quitline kullanildi'),
                value: _usedCounselingOrQuitline,
                onChanged: (v) =>
                    setState(() => _usedCounselingOrQuitline = v),
              ),
              _intSlider(
                label: 'Tedavi uyumu (0-10)',
                value: _medicationAdherence,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _medicationAdherence = v),
              ),
              _intSlider(
                label: 'Aile/sosyal destek (0-10)',
                value: _familySupport,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _familySupport = v),
              ),
              _intSlider(
                label: 'Oz yeterlilik (0-10)',
                value: _selfEfficacy,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _selfEfficacy = v),
              ),
              _intSlider(
                label: 'Motivasyon (0-10)',
                value: _motivation,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _motivation = v),
              ),
              _intSlider(
                label: 'Haftalik gorev tamamlama (0-10)',
                value: _weeklyCompletionRate,
                min: 0,
                max: 10,
                onChanged: (v) => setState(() => _weeklyCompletionRate = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _dailyTaskAdherenceLevel,
                decoration: const InputDecoration(
                  labelText: 'Gunluk gorevlere ne kadar uydun?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'az', child: Text('Az')),
                  DropdownMenuItem(value: 'orta', child: Text('Orta')),
                  DropdownMenuItem(value: 'cok', child: Text('Cok')),
                ],
                onChanged: (value) => setState(
                  () => _dailyTaskAdherenceLevel = value ?? 'orta',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _commandBurdenLevel,
                decoration: const InputDecoration(
                  labelText: 'Komutlar seni rahatsiz etti mi?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'az', child: Text('Az')),
                  DropdownMenuItem(value: 'orta', child: Text('Orta')),
                  DropdownMenuItem(value: 'cok', child: Text('Cok')),
                ],
                onChanged: (value) =>
                    setState(() => _commandBurdenLevel = value ?? 'orta'),
              ),
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                'Hizli mod secili. Temel sorulara gore risk otomatik hesaplanir. Istersen Detayli moda gecip tum parametreleri duzenleyebilirsin.',
              ),
            ],
            ConsecutiveSmokingSection(
              consecutiveSmokingHabit: _consecutiveSmokingHabit,
              consecutiveSmokingCount: _consecutiveSmokingCount,
              onHabitChanged: (value) {
                setState(() {
                  _consecutiveSmokingHabit = value;
                  if (value != 'Evet') {
                    _consecutiveSmokingCount = null;
                  }
                });
              },
              onCountChanged: (value) {
                setState(() {
                  _consecutiveSmokingCount = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.t('addNote'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  await _saveWeeklySurvey();
                  final latestUserName = await _resolveLatestUserName();
                  if (!mounted) return;
                  if (!context.mounted) return;

                  if (widget.navigateToHomeAfterSave) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomePage(
                          name: widget.nameSeed ?? latestUserName,
                          riskScore: _calculateWeeklyRiskScore(
                            _detailedMode
                                ? _buildWeeklyPayload()
                                : _buildQuickWeeklyPayload(),
                          ),
                          riskLevel: _levelFromScore(
                            _calculateWeeklyRiskScore(
                              _detailedMode
                                  ? _buildWeeklyPayload()
                                  : _buildQuickWeeklyPayload(),
                            ),
                          ),
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BreathTestPage(
                        name: latestUserName,
                        packsPerDay: _resolvedPacksPerDay,
                      ),
                    ),
                  );
                },
                child: Text(context.t('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
