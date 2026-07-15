/// Belirli bir tarihte ölçülen sağlık metriği
class HealthMetricSnapshot {
  final String id;
  final DateTime recordedAt;
  final int exhaleSeconds; // Nefes verme süresi (saniye)
  final int inhaleSeconds; // Nefes alma süresi (saniye)
  final int riskScore; // 0-100
  final String riskLevel; // LOW, MEDIUM, HIGH, CRITICAL
  final double? stressLevel; // 1-10 (opsiyonel)
  final double? sleepQuality; // 1-10 (opsiyonel)
  final List<String>? withdrawalSymptoms; // Nikotin çekilme semptomları

  const HealthMetricSnapshot({
    required this.id,
    required this.recordedAt,
    required this.exhaleSeconds,
    required this.inhaleSeconds,
    required this.riskScore,
    required this.riskLevel,
    this.stressLevel,
    this.sleepQuality,
    this.withdrawalSymptoms,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recordedAt': recordedAt.toIso8601String(),
      'exhaleSeconds': exhaleSeconds,
      'inhaleSeconds': inhaleSeconds,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'stressLevel': stressLevel,
      'sleepQuality': sleepQuality,
      'withdrawalSymptoms': withdrawalSymptoms,
    };
  }

  factory HealthMetricSnapshot.fromJson(Map<String, dynamic> json) {
    return HealthMetricSnapshot(
      id: json['id'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      exhaleSeconds: (json['exhaleSeconds'] as num?)?.toInt() ?? 0,
      inhaleSeconds: (json['inhaleSeconds'] as num?)?.toInt() ?? 0,
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      riskLevel: json['riskLevel'] as String? ?? 'UNKNOWN',
      stressLevel: (json['stressLevel'] as num?)?.toDouble(),
      sleepQuality: (json['sleepQuality'] as num?)?.toDouble(),
      withdrawalSymptoms: (json['withdrawalSymptoms'] as List<dynamic>?)
          ?.cast<String>(),
    );
  }
}
