import 'adaptive_plan.dart';

class BehaviorDashboard {
  final int riskScore;
  final List<String> riskyTriggers;
  final List<String> riskyHours;
  final DateTime? lastSurveyDate;
  final DateTime? lastBreathDate;
  final String breathTrend;
  final String progressSummary;
  final List<String> todaysTasks;
  final List<String> coachCommands;
  final String predictedRiskWindow;
  final int predictionConfidence;
  final String predictedTrigger;
  final AdaptivePlan plan;

  const BehaviorDashboard({
    required this.riskScore,
    required this.riskyTriggers,
    required this.riskyHours,
    this.lastSurveyDate,
    this.lastBreathDate,
    required this.breathTrend,
    required this.progressSummary,
    required this.todaysTasks,
    required this.coachCommands,
    required this.predictedRiskWindow,
    required this.predictionConfidence,
    required this.predictedTrigger,
    required this.plan,
  });
}
