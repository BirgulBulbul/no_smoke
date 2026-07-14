class UserProfileSnapshot {
  final String id;
  final DateTime createdAt;
  final int riskScore;
  final String packsPerDay;
  final String firstCigaretteRange;
  final String smokeFreeRange;
  final String consecutiveSmokingHabit;
  final String? consecutiveSmokingCount;
  final List<String> triggers;
  final List<String> healthConditions;
  final String profession;
  final String sleepTime;
  final String wakeTime;
  final int latestExhaleSeconds;
  final int latestInhaleSeconds;

  const UserProfileSnapshot({
    required this.id,
    required this.createdAt,
    required this.riskScore,
    required this.packsPerDay,
    required this.firstCigaretteRange,
    required this.smokeFreeRange,
    required this.consecutiveSmokingHabit,
    this.consecutiveSmokingCount,
    required this.triggers,
    required this.healthConditions,
    required this.profession,
    required this.sleepTime,
    required this.wakeTime,
    required this.latestExhaleSeconds,
    required this.latestInhaleSeconds,
  });
}
