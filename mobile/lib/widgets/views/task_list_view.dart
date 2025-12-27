import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../cards/task_card.dart';

class TaskListView extends StatelessWidget {
  final List<Task> tasks;
  final Function(Task)? onTaskTap;
  final Future<void> Function()? onRefresh;

  const TaskListView({
    super.key,
    required this.tasks,
    this.onTaskTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无任务', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskCard(
            task: task,
            onTap: () => onTaskTap?.call(task),
          );
        },
      ),
    );
  }
}
