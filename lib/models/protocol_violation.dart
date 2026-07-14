class ProtocolViolation {
  final String id;
  final String type;
  final String severity;
  final String? taskTitle;
  final String details;
  final DateTime createdAt;
  final bool resolved;

  const ProtocolViolation({
    required this.id,
    required this.type,
    required this.severity,
    required this.taskTitle,
    required this.details,
    required this.createdAt,
    required this.resolved,
  });
}