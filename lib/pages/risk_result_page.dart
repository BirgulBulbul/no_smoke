import 'package:flutter/material.dart';

import '../models/survey_record.dart';
import '../services/storage_service.dart';
import 'survey_review_page.dart';

class RiskResultPage extends StatelessWidget {
  final String name;
  final int riskScore;
  final String riskLevel;
  final int dailyCigarettes;
  final int exhaleTestSeconds;
  final int inhaleTestSeconds;

  const RiskResultPage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
    this.dailyCigarettes = 0,
    this.exhaleTestSeconds = 0,
    this.inhaleTestSeconds = 0,
  });

  Color getRiskColor() {
    switch (riskLevel) {
      case 'KRİTİK':
        return Colors.red;
      case 'YÜKSEK':
        return Colors.orange;
      case 'ORTA':
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }

  int getTaskCount() {
    if (riskScore >= 80) return 5;
    if (riskScore >= 60) return 4;
    if (riskScore >= 40) return 3;
    if (riskScore >= 20) return 2;
    return 1;
  }

  String getRiskDescription() {
    if (riskScore >= 80) {
      return 'Yoğun bağımlılık riski tespit edildi. Program daha sık görev üretecek.';
    }

    if (riskScore >= 60) {
      return 'Yüksek bağımlılık riski tespit edildi.';
    }

    if (riskScore >= 40) {
      return 'Orta seviye bağımlılık riski tespit edildi.';
    }

    return 'Düşük risk seviyesi tespit edildi.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Analizi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Merhaba $name',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: getRiskColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    riskLevel,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$riskScore / 100',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Text(
              getRiskDescription(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 25),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Bugünkü Görev Sayısı',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${getTaskCount()} Görev',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Lütfen ücretsiz deneme süresi boyunca günlük sigara kullanımınızı takip edin. Sistem iki hafta sonunda gelişiminizi değerlendirecektir.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  final storage = StorageService();
                  final currentRecord = SurveyRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    completedAt: DateTime.now(),
                    name: name,
                    dailyCigarettes: dailyCigarettes,
                    exhaleTestSeconds: exhaleTestSeconds,
                    inhaleTestSeconds: inhaleTestSeconds,
                    riskScore: riskScore,
                    riskLevel: riskLevel,
                  );
                  final previousRecords = await storage.loadSurveyHistory();
                  await storage.saveSurveyRecord(currentRecord);
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SurveyReviewPage(
                        currentRecord: currentRecord,
                        previousRecord: previousRecords.isEmpty ? null : previousRecords.last,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Devam Et',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
