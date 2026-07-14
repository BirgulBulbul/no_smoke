class AdaptivePlan {
  final DateTime generatedAt;
  final int targetDays;
  final int currentWeek;
  final int currentDay;
  final int daysRemaining;
  final int weeklyRiskTarget;
  final String difficulty;
  final String cadenceLevel;
  final List<String> focusAreas;

  const AdaptivePlan({
    required this.generatedAt,
    required this.targetDays,
    required this.currentWeek,
    required this.currentDay,
    required this.daysRemaining,
    required this.weeklyRiskTarget,
    required this.difficulty,
    required this.cadenceLevel,
    required this.focusAreas,
  });
}
