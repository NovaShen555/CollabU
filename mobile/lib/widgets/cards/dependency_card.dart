import 'package:flutter/material.dart';
import '../../models/task_link.dart';

class DependencyCard extends StatelessWidget {
  final TaskLink link;
  final String sourceName;
  final String targetName;
  final VoidCallback? onDelete;

  const DependencyCard({
    super.key,
    required this.link,
    required this.sourceName,
    required this.targetName,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTaskRow('前置', sourceName),
                  const SizedBox(height: 4),
                  _buildArrow(),
                  const SizedBox(height: 4),
                  _buildTaskRow('后续', targetName),
                ],
              ),
            ),
            Column(
              children: [
                _buildTypeBadge(),
                if (onDelete != null) ...[
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskRow(String label, String name) {
    return Row(
      children: [
        Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Expanded(
          child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildArrow() {
    return Row(
      children: [
        const SizedBox(width: 24),
        Icon(Icons.arrow_downward, size: 16, color: _getTypeColor()),
      ],
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getTypeColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getTypeColor()),
      ),
      child: Text(link.typeShort, style: TextStyle(color: _getTypeColor(), fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Color _getTypeColor() {
    switch (link.type) {
      case '0': return Colors.blue;
      case '1': return Colors.green;
      case '2': return Colors.red;
      case '3': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
