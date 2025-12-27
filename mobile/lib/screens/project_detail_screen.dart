import 'package:flutter/material.dart';
import 'task_screen.dart';

class ProjectDetailScreen extends StatelessWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    // 直接使用TaskScreen，它已经有完整的底部导航
    return TaskScreen(projectId: projectId);
  }
}
