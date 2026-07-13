import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/survey_record.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves and loads survey history', () async {
    SharedPreferences.setMockInitialValues({});

    final storage = StorageService();
    final record = SurveyRecord(
      id: '1',
      completedAt: DateTime(2024, 1, 1),
      name: 'Ada',
      dailyCigarettes: 10,
      exhaleTestSeconds: 6,
      inhaleTestSeconds: 8,
      riskScore: 40,
      riskLevel: 'ORTA',
    );

    await storage.saveSurveyRecord(record);
    final history = await storage.loadSurveyHistory();

    expect(history, hasLength(1));
    expect(history.first.name, 'Ada');
    expect(history.first.riskLevel, 'ORTA');
  });
}
