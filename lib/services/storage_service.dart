import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/survey_record.dart';

class StorageService {
  static const _surveyKey = 'survey_history';
  static const _lastSurveyDateKey = 'last_survey_date';

  Future<List<SurveyRecord>> loadSurveyHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_surveyKey) ?? <String>[];

    return raw
        .map((item) => SurveyRecord.fromJson(jsonDecode(item)))
        .toList();
  }

  Future<void> saveSurveyHistory(List<SurveyRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = records.map((record) => jsonEncode(record.toJson())).toList();
    await prefs.setStringList(_surveyKey, payload);
  }

  Future<void> saveSurveyRecord(SurveyRecord record) async {
    final records = await loadSurveyHistory();
    records.add(record);
    await saveSurveyHistory(records);
    await updateLastSurveyDate(record.completedAt);
  }

  Future<void> updateLastSurveyDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSurveyDateKey, date.toIso8601String());
  }

  Future<DateTime?> loadLastSurveyDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSurveyDateKey);
    if (raw == null) {
      return null;
    }
    return DateTime.parse(raw);
  }
}
