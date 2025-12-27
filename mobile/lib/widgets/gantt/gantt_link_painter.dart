import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/task.dart';
import '../../models/task_link.dart';

class GanttLinkPainter extends CustomPainter {
  final List<Task> tasks;
  final List<TaskLink> links;
  final DateTime startDate;
  final double dayWidth;
  final double rowHeight;

  // Link type colors
  static const Map<String, Color> linkTypeColors = {
    '0': Color(0xFF4CAF50), // FS - Green
    '1': Color(0xFF2196F3), // SS - Blue
    '2': Color(0xFFFF9800), // FF - Orange
    '3': Color(0xFF9C27B0), // SF - Purple
  };

  static Color getLinkColor(String type) {
    return linkTypeColors[type] ?? Colors.grey;
  }

  GanttLinkPainter({
    required this.tasks,
    required this.links,
    required this.startDate,
    required this.dayWidth,
    required this.rowHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw existing links with type-specific colors
    for (final link in links) {
      final sourceTask = tasks.firstWhere(
        (t) => t.id == link.source,
        orElse: () => Task(id: -1, title: ''),
      );
      final targetTask = tasks.firstWhere(
        (t) => t.id == link.target,
        orElse: () => Task(id: -1, title: ''),
      );

      if (sourceTask.id == -1 || targetTask.id == -1) continue;

      final sourceIndex = tasks.indexOf(sourceTask);
      final targetIndex = tasks.indexOf(targetTask);

      // Get color based on link type
      final color = getLinkColor(link.type);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final arrowPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Calculate positions based on link type
      Offset startPos;
      Offset endPos;

      switch (link.type) {
        case '0': // FS: source end -> target start
          final sourceEnd = sourceTask.endDate != null ? DateTime.parse(sourceTask.endDate!) : null;
          final targetStart = targetTask.startDate != null ? DateTime.parse(targetTask.startDate!) : null;
          if (sourceEnd == null || targetStart == null) continue;
          startPos = Offset((sourceEnd.difference(startDate).inDays + 1) * dayWidth + 2, sourceIndex * rowHeight + rowHeight / 2);
          endPos = Offset(targetStart.difference(startDate).inDays * dayWidth + 2, targetIndex * rowHeight + rowHeight / 2);
          break;
        case '1': // SS: source start -> target start
          final sourceStart = sourceTask.startDate != null ? DateTime.parse(sourceTask.startDate!) : null;
          final targetStart = targetTask.startDate != null ? DateTime.parse(targetTask.startDate!) : null;
          if (sourceStart == null || targetStart == null) continue;
          startPos = Offset(sourceStart.difference(startDate).inDays * dayWidth + 2, sourceIndex * rowHeight + rowHeight / 2);
          endPos = Offset(targetStart.difference(startDate).inDays * dayWidth + 2, targetIndex * rowHeight + rowHeight / 2);
          break;
        case '2': // FF: source end -> target end
          final sourceEnd = sourceTask.endDate != null ? DateTime.parse(sourceTask.endDate!) : null;
          final targetEnd = targetTask.endDate != null ? DateTime.parse(targetTask.endDate!) : null;
          if (sourceEnd == null || targetEnd == null) continue;
          startPos = Offset((sourceEnd.difference(startDate).inDays + 1) * dayWidth + 2, sourceIndex * rowHeight + rowHeight / 2);
          endPos = Offset((targetEnd.difference(startDate).inDays + 1) * dayWidth + 2, targetIndex * rowHeight + rowHeight / 2);
          break;
        case '3': // SF: source start -> target end
          final sourceStart = sourceTask.startDate != null ? DateTime.parse(sourceTask.startDate!) : null;
          final targetEnd = targetTask.endDate != null ? DateTime.parse(targetTask.endDate!) : null;
          if (sourceStart == null || targetEnd == null) continue;
          startPos = Offset(sourceStart.difference(startDate).inDays * dayWidth + 2, sourceIndex * rowHeight + rowHeight / 2);
          endPos = Offset((targetEnd.difference(startDate).inDays + 1) * dayWidth + 2, targetIndex * rowHeight + rowHeight / 2);
          break;
        default:
          continue;
      }

      _drawArrow(canvas, startPos, endPos, paint, arrowPaint);
    }

    // Draw parent-child relationships with dashed lines
    final dashedPaint = Paint()
      ..color = Colors.blue.shade300
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final task in tasks) {
      if (task.parentId == null) continue;
      
      final parentTask = tasks.firstWhere(
        (t) => t.id == task.parentId,
        orElse: () => Task(id: -1, title: ''),
      );
      
      if (parentTask.id == -1) continue;
      
      final parentIndex = tasks.indexOf(parentTask);
      final childIndex = tasks.indexOf(task);
      
      // Get left side positions
      final parentStart = parentTask.startDate != null ? DateTime.parse(parentTask.startDate!) : null;
      final childStart = task.startDate != null ? DateTime.parse(task.startDate!) : null;
      
      if (parentStart == null || childStart == null) continue;
      
      final parentX = parentStart.difference(startDate).inDays * dayWidth;
      final parentY = parentIndex * rowHeight + rowHeight / 2;
      final childX = childStart.difference(startDate).inDays * dayWidth;
      final childY = childIndex * rowHeight + rowHeight / 2;
      
      // Draw dashed line from parent left to child left
      _drawDashedLine(
        canvas,
        Offset(parentX, parentY),
        Offset(childX, childY),
        dashedPaint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final steps = (distance / (dashWidth + dashSpace)).floor();
    
    for (int i = 0; i < steps; i++) {
      final startFraction = (i * (dashWidth + dashSpace)) / distance;
      final endFraction = ((i * (dashWidth + dashSpace)) + dashWidth) / distance;
      
      final dashStart = Offset(
        start.dx + dx * startFraction,
        start.dy + dy * startFraction,
      );
      final dashEnd = Offset(
        start.dx + dx * endFraction.clamp(0, 1),
        start.dy + dy * endFraction.clamp(0, 1),
      );
      
      canvas.drawLine(dashStart, dashEnd, paint);
    }
    
    // Draw small arrow at end
    const arrowSize = 5.0;
    final angle = math.atan2(dy, dx);
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    
    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle - 0.5),
        end.dy - arrowSize * math.sin(angle - 0.5),
      )
      ..lineTo(
        end.dx - arrowSize * math.cos(angle + 0.5),
        end.dy - arrowSize * math.sin(angle + 0.5),
      )
      ..close();
    
    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint linePaint, Paint arrowPaint) {
    // Draw bezier curve
    final midX = (start.dx + end.dx) / 2;
    final controlPoint1 = Offset(midX, start.dy);
    final controlPoint2 = Offset(midX, end.dy);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, end.dx, end.dy);

    canvas.drawPath(path, linePaint);

    // Draw arrowhead
    const arrowSize = 8.0;
    final dx = end.dx - controlPoint2.dx;
    final dy = end.dy - controlPoint2.dy;
    final angle = math.atan2(dy, dx);

    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * 1.5 * math.cos(angle - 0.4),
        end.dy - arrowSize * 1.5 * math.sin(angle - 0.4),
      )
      ..lineTo(
        end.dx - arrowSize * 1.5 * math.cos(angle + 0.4),
        end.dy - arrowSize * 1.5 * math.sin(angle + 0.4),
      )
      ..close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant GanttLinkPainter oldDelegate) {
    return oldDelegate.links != links || oldDelegate.tasks != tasks;
  }
}
