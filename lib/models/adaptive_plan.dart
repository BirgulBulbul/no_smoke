class AdaptivePlan {
  final DateTime generatedAt;
  final int targetDays;
  final int currentWeek;
  final int weeklyRiskTarget;
  final String difficulty;
  final List<String> focusAreas;

  const AdaptivePlan({
    required this.generatedAt,
    required this.targetDays,
    required this.currentWeek,
    required this.weeklyRiskTarget,
    required this.difficulty,
    required this.focusAreas,
  });
}
