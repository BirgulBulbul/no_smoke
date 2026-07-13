
class TaskModel {
  final String title;
  final String description;

  final bool completed;

  const TaskModel({
    required this.title,
    required this.description,
    this.completed = false,
  });
}
