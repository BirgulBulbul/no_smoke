class TaskHistory {
  final String taskId;
  final String taskTitle;
  final bool completed;
  final DateTime date;

  const TaskHistory({
    required this.taskId,
    required this.taskTitle,
    required this.completed,
    required this.date,
  });
}
