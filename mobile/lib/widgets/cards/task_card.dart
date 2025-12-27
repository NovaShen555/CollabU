import 'package:flutter/material.dart';
import '../../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(
        left: 12.0 + (task.level * 12.0),
        right: 12.0,
        top: 4.0,
        bottom: 4.0,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildPriorityBadge(),
                ],
              ),
              const SizedBox(height: 8),
              // 进度条
              _buildProgressBar(),
              const SizedBox(height: 8),
              // 底部信息
              Row(
                children: [
                  _buildStatusChip(),
                  const Spacer(),
                  if (task.endDate != null) _buildDateInfo(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge() {
    Color color;
    String label;
    switch (task.priority) {
      case 'high':
        color = Colors.red;
        label = '高';
        break;
      case 'low':
        color = Colors.green;
        label = '低';
        break;
      default:
        color = Colors.orange;
        label = '中';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (task.progress ?? 0) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '进度',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            Text(
              '${task.progress ?? 0}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 1.0 ? Colors.green : Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;
    switch (task.status) {
      case 'in_progress':
        color = Colors.blue;
        label = '进行中';
        break;
      case 'completed':
        color = Colors.green;
        label = '已完成';
        break;
      default:
        color = Colors.grey;
        label = '未开始';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }

  Widget _buildDateInfo() {
    return Row(
      children: [
        Icon(Icons.event, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          task.endDate!.substring(0, 10),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
