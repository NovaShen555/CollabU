import 'user.dart';

class Task {
  final int id;
  final String title;
  final String? description;
  final String? status;
  final String? priority;
  final int? progress;
  final String? startDate;
  final String? endDate;
  final int? parentId;
  final int? projectId;
  final List<User>? participants;
  final bool hasSubtasks;
  final int level;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.status,
    this.priority,
    this.progress,
    this.startDate,
    this.endDate,
    this.parentId,
    this.projectId,
    this.participants,
    this.hasSubtasks = false,
    this.level = 0,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'] ?? 'Untitled Task',
      description: json['description'],
      status: json['status'],
      priority: json['priority'],
      progress: json['progress'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      parentId: json['parent_id'],
      projectId: json['project_id'],
      participants: json['participants'] != null
          ? (json['participants'] as List).map((i) => User.fromJson(i)).toList()
          : null,
      hasSubtasks: json['has_subtasks'] ?? false,
      level: json['level'] ?? 0,
    );
  }
}
