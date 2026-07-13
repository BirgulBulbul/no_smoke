class SurveyRecord {
  final String id;
  final DateTime completedAt;
  final String name;
  final int dailyCigarettes;
  final int exhaleTestSeconds;
  final int inhaleTestSeconds;
  final int riskScore;
  final String riskLevel;

  const SurveyRecord({
    required this.id,
    required this.completedAt,
    required this.name,
    required this.dailyCigarettes,
    required this.exhaleTestSeconds,
    required this.inhaleTestSeconds,
    required this.riskScore,
    required this.riskLevel,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'completedAt': completedAt.toIso8601String(),
      'name': name,
      'dailyCigarettes': dailyCigarettes,
      'exhaleTestSeconds': exhaleTestSeconds,
      'inhaleTestSeconds': inhaleTestSeconds,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
    };
  }

  factory SurveyRecord.fromJson(Map<String, dynamic> json) {
    return SurveyRecord(
      id: json['id'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      name: json['name'] as String,
      dailyCigarettes: json['dailyCigarettes'] as int,
      exhaleTestSeconds: json['exhaleTestSeconds'] as int,
      inhaleTestSeconds: json['inhaleTestSeconds'] as int,
      riskScore: json['riskScore'] as int,
      riskLevel: json['riskLevel'] as String,
    );
  }
}
