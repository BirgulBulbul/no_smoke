
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
  String _mood = 'Orta';
  String _packOption = '1 paketten az';
  String? _highPackOption;
  String? _consecutiveSmokingHabit;
  String? _consecutiveSmokingCount;

  String get _resolvedPacksPerDay {
    if (_packOption == '3+ paket') {
      return _highPackOption ?? '4 paket';
    }
    return _packOption;
  }

  Future<void> _saveWeeklySurvey() async {
    final now = DateTime.now();
    final recordId = now.millisecondsSinceEpoch.toString();
    final record = SurveyRecord(
      id: recordId,
      completedAt: now,
      type: 'weekly',
      title: context.t('weeklyRecordTitle'),
      name: 'User',
      packsPerDay: _resolvedPacksPerDay,
      exhaleTestSeconds: 0,
      inhaleTestSeconds: 0,
      riskScore: _mood == 'İyi' ? 15 : _mood == 'Orta' ? 35 : 55,
      riskLevel: _mood == 'İyi' ? 'DÜŞÜK' : _mood == 'Orta' ? 'ORTA' : 'YÜKSEK',
      consecutiveSmokingHabit: _consecutiveSmokingHabit,
      consecutiveSmokingCount: _consecutiveSmokingHabit == 'Evet' ? _consecutiveSmokingCount : null,
    );
    await _storageService.saveSurveyRecord(record);

    await _storageService.saveSurveyDetail(
      recordId: recordId,
      triggers: const [],
      healthConditions: const [],
      stressLevel: _mood,
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
                          riskScore: _mood == 'İyi' ? 15 : _mood == 'Orta' ? 35 : 55,
                          riskLevel: _mood == 'İyi' ? 'DÜŞÜK' : _mood == 'Orta' ? 'ORTA' : 'YÜKSEK',
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
