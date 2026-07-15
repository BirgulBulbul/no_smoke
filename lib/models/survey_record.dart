class SurveyRecord {
  final String id;
  final DateTime completedAt;
  final String type;
  final String title;
  final String name;
  final String packsPerDay;
  final int exhaleTestSeconds;
  final int inhaleTestSeconds;
  final int riskScore;
  final String riskLevel;
  final String? taskTitle;
  final String? taskResult;
  final String? consecutiveSmokingHabit;
  final String? consecutiveSmokingCount;
  final DateTime? quitDate; // Sigara bırakma başlangıç tarihi (ilk anketten)

  const SurveyRecord({
    required this.id,
    required this.completedAt,
    required this.type,
    required this.title,
    required this.name,
    required this.packsPerDay,
    required this.exhaleTestSeconds,
    required this.inhaleTestSeconds,
    required this.riskScore,
    required this.riskLevel,
    this.taskTitle,
    this.taskResult,
    this.consecutiveSmokingHabit,
    this.consecutiveSmokingCount,
    this.quitDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'completedAt': completedAt.toIso8601String(),
      'type': type,
      'title': title,
      'name': name,
      'packsPerDay': packsPerDay,
      'dailyCigarettes': _packsToLegacyCigarettes(packsPerDay),
      'exhaleTestSeconds': exhaleTestSeconds,
      'inhaleTestSeconds': inhaleTestSeconds,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'taskTitle': taskTitle,
      'taskResult': taskResult,
      'consecutiveSmokingHabit': consecutiveSmokingHabit,
      'consecutiveSmokingCount': consecutiveSmokingCount,
      'quitDate': quitDate?.toIso8601String(),
    };
  }

  factory SurveyRecord.fromJson(Map<String, dynamic> json) {
    return SurveyRecord(
      id: json['id'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      type: json['type'] as String? ?? 'initial',
      title: json['title'] as String? ?? 'Anket',
      name: json['name'] as String? ?? '',
      packsPerDay: (json['packsPerDay'] as String?) ??
          _legacyCigarettesToPacks((json['dailyCigarettes'] as num?)?.toInt()),
      exhaleTestSeconds: (json['exhaleTestSeconds'] as num?)?.toInt() ?? 0,
      inhaleTestSeconds: (json['inhaleTestSeconds'] as num?)?.toInt() ?? 0,
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      riskLevel: json['riskLevel'] as String? ?? 'BİLİNMEYEN',
      taskTitle: json['taskTitle'] as String?,
      taskResult: json['taskResult'] as String?,
      consecutiveSmokingHabit: json['consecutiveSmokingHabit'] as String?,
      consecutiveSmokingCount: json['consecutiveSmokingCount'] as String?,
      quitDate: json['quitDate'] != null ? DateTime.parse(json['quitDate'] as String) : null,
    );
  }

  static int packLevel(String packsPerDay) {
    switch (packsPerDay) {
      case '1 paketten az':
        return 0;
      case '1 paket':
        return 1;
      case '2 paket':
        return 2;
      case '3 paket':
        return 3;
      case '4 paket':
        return 4;
      case '5 paket':
        return 5;
      case '6 paket':
        return 6;
      case '7+ paket':
        return 7;
      case '3+ paket':
        return 4;
      default:
        return 0;
    }
  }

  static int _packsToLegacyCigarettes(String packsPerDay) {
    switch (packsPerDay) {
      case '1 paketten az':
        return 10;
      case '1 paket':
        return 20;
      case '2 paket':
        return 40;
      case '3 paket':
        return 60;
      case '4 paket':
        return 80;
      case '5 paket':
        return 100;
      case '6 paket':
        return 120;
      case '7+ paket':
        return 140;
      case '3+ paket':
        return 80;
      default:
        return 10;
    }
  }

  static String _legacyCigarettesToPacks(int? cigarettesPerDay) {
    final value = cigarettesPerDay ?? 0;
    if (value <= 19) {
      return '1 paketten az';
    }
    if (value <= 20) {
      return '1 paket';
    }
    if (value <= 40) {
      return '2 paket';
    }
    if (value <= 60) {
      return '3 paket';
    }
    if (value <= 80) {
      return '4 paket';
    }
    if (value <= 100) {
      return '5 paket';
    }
    if (value <= 120) {
      return '6 paket';
    }
    return '7+ paket';
  }
}
