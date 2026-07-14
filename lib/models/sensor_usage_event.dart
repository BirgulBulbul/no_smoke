class SensorUsageEvent {
  final String id;
  final DateTime createdAt;
  final String activityState;
  final double accelerometerMagnitude;
  final double gyroscopeMagnitude;
  final int screenUnlockCount;
  final int appUsageMinutes;
  final int idleMinutes;
  final bool charging;

  const SensorUsageEvent({
    required this.id,
    required this.createdAt,
    required this.activityState,
    required this.accelerometerMagnitude,
    required this.gyroscopeMagnitude,
    required this.screenUnlockCount,
    required this.appUsageMinutes,
    required this.idleMinutes,
    required this.charging,
  });
}
