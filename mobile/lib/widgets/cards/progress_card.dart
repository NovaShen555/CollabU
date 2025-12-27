import 'package:flutter/material.dart';
import '../../models/task.dart';

class ProgressCard extends StatelessWidget {
  final Task task;
  final Function(int)? onProgressChange;

  const ProgressCard({
    super.key,
    required this.task,
    this.onProgressChange,
  });

  @override
  Widget build(BuildContext context) {
    final progress = task.progress ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$progress%',
                  style: TextStyle(
                    color: _getProgressColor(progress),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: progress.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: _getProgressColor(progress),
                onChanged: (value) {
                  onProgressChange?.call(value.round());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(int progress) {
    if (progress >= 100) return Colors.green;
    if (progress >= 50) return Colors.blue;
    if (progress >= 25) return Colors.orange;
    return Colors.grey;
  }
}
