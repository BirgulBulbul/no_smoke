import 'package:flutter/material.dart';

import '../models/survey_record.dart';
import 'home_page.dart';
import 'survey_history_page.dart';

class SurveyReviewPage extends StatelessWidget {
  final SurveyRecord currentRecord;
  final SurveyRecord? previousRecord;

  const SurveyReviewPage({
    super.key,
    required this.currentRecord,
    required this.previousRecord,
  });

  @override
  Widget build(BuildContext context) {
    final dailyCigarettesDelta = previousRecord == null
        ? null
        : currentRecord.dailyCigarettes - previousRecord!.dailyCigarettes;
    final exhaleDelta = previousRecord == null
        ? null
        : currentRecord.exhaleTestSeconds - previousRecord!.exhaleTestSeconds;
    final inhaleDelta = previousRecord == null
        ? null
        : currentRecord.inhaleTestSeconds - previousRecord!.inhaleTestSeconds;
    final riskDelta = previousRecord == null
        ? null
        : currentRecord.riskScore - previousRecord!.riskScore;

    final hasImprovement = (dailyCigarettesDelta ?? 0) < 0 ||
        (exhaleDelta ?? 0) < 0 ||
        (inhaleDelta ?? 0) < 0 ||
        (riskDelta ?? 0) < 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Değerlendirme'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasImprovement ? 'İlerleme var, iyi gidiyorsunuz.' : 'İlerleme görünmüyor; kendinizi destekleyin.',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasImprovement
                  ? 'Gelişim gösteren alanlar olumlu rapor olarak kaydedildi.'
                  : 'Bir önceki değerlendirmeye göre gerileme veya değişim yok. Devam edin.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            _buildMetric('Günlük sigara değişimi', dailyCigarettesDelta, 'adet'),
            _buildMetric('Nefes verme testi değişimi', exhaleDelta, 'sn'),
            _buildMetric('Nefes tutma testi değişimi', inhaleDelta, 'sn'),
            _buildMetric('Risk puanı değişimi', riskDelta, 'puan'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SurveyHistoryPage()),
                  );
                },
                child: const Text('Tüm geçmiş anketleri gör'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePage(
                        name: currentRecord.name,
                        riskScore: currentRecord.riskScore,
                        riskLevel: currentRecord.riskLevel,
                      ),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Ana sayfaya dön'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String title, int? delta, String unit) {
    final display = delta == null ? 'İlk değerlendirme' : '${delta > 0 ? '+' : ''}$delta $unit';
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(display),
      ),
    );
  }
}
