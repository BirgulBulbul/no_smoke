
class UserProfile {
  final String name;
  final int age;
  final String gender;

  final String packsPerDay;
  final int firstCigaretteMinutes;
  final int smokeFreeMinutes;

  final int smokingYears;
  final int quitAttempts;

  final String sleepTime;
  final String wakeTime;

  final String workStartTime;
  final String workEndTime;

  final String workplaceSmokingRule;

  final bool hypertension;
  final bool asthma;
  final bool diabetes;
  final bool copd;
  final bool heartDisease;

  final List<String> triggers;

  final String stressLevel;
  final String quitReason;

  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.packsPerDay,
    required this.firstCigaretteMinutes,
    required this.smokeFreeMinutes,
    required this.smokingYears,
    required this.quitAttempts,
    required this.sleepTime,
    required this.wakeTime,
    required this.workStartTime,
    required this.workEndTime,
    required this.workplaceSmokingRule,
    required this.hypertension,
    required this.asthma,
    required this.diabetes,
    required this.copd,
    required this.heartDisease,
    required this.triggers,
    required this.stressLevel,
    required this.quitReason,
  });
}
