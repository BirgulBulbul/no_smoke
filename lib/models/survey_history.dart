class SurveyHistory {
  final DateTime surveyDate;
  final String packsPerDay;
  final int longestSmokeFreeDuration;
  final String hardestHour;
  final String hardestDay;
  final List<String> triggers;
  final int stressLevel;
  final int riskScore;
  final String chainSmokingLevel;
  final String? consecutiveSmokingHabit;
  final String? consecutiveSmokingCount;

  const SurveyHistory({
    required this.surveyDate,
    required this.packsPerDay,
    required this.longestSmokeFreeDuration,
    required this.hardestHour,
    required this.hardestDay,
    required this.triggers,
    required this.stressLevel,
    required this.riskScore,
    this.chainSmokingLevel = 'Hayır',
    this.consecutiveSmokingHabit,
    this.consecutiveSmokingCount,
  });
}
