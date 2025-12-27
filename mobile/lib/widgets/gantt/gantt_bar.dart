import 'package:flutter/material.dart';
import '../../models/task.dart';

class GanttBar extends StatefulWidget {
  final Task task;
  final DateTime startDate;
  final double dayWidth;
  final double rowHeight;
  final VoidCallback? onTap;
  final Function(DateTime newStart, DateTime newEnd)? onDateChange;
  final Function(int newProgress)? onProgressChange;
  final VoidCallback? onLinkPointTap;
  final VoidCallback? onAddSubtask;
  final VoidCallback? onLinkTap;
  final bool isLinkSource;
  final bool isLinkMode;
  final bool hasLinks;

  const GanttBar({
    super.key,
    required this.task,
    required this.startDate,
    required this.dayWidth,
    required this.rowHeight,
    this.onTap,
    this.onDateChange,
    this.onProgressChange,
    this.onLinkPointTap,
    this.onAddSubtask,
    this.onLinkTap,
    this.isLinkSource = false,
    this.isLinkMode = false,
    this.hasLinks = false,
  });

  @override
  State<GanttBar> createState() => _GanttBarState();
}

class _GanttBarState extends State<GanttBar> {
  // Temporary state during dragging
  double? _tempLeft;
  double? _tempWidth;
  double? _tempProgress;
  bool _isDraggingLeft = false;
  bool _isDraggingRight = false;
  bool _isDraggingProgress = false;

  @override
  Widget build(BuildContext context) {
    if (widget.task.startDate == null || widget.task.endDate == null) {
      return SizedBox(height: widget.rowHeight);
    }

    final taskStart = DateTime.parse(widget.task.startDate!);
    final taskEnd = DateTime.parse(widget.task.endDate!);

    final startOffset = taskStart.difference(widget.startDate).inDays;
    final duration = taskEnd.difference(taskStart).inDays + 1;

    final baseLeft = startOffset * widget.dayWidth;
    final baseWidth = duration * widget.dayWidth;

    final left = _tempLeft ?? baseLeft;
    final width = _tempWidth ?? baseWidth;
    final progress = _tempProgress ?? (widget.task.progress?.toDouble() ?? 0);

    return SizedBox(
      height: widget.rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: left + 2,
            top: 8,
            child: _buildBar(width - 4, progress),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double width, double progress) {
    final barHeight = widget.rowHeight - 16;
    
    return SizedBox(
      width: width,
      height: barHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main bar body
          GestureDetector(
            onTap: widget.onTap,
            onLongPress: () => _showContextMenu(context),
            child: Container(
              width: width,
              height: barHeight,
              decoration: BoxDecoration(
                color: _getPriorityColor(widget.task.priority),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Progress fill
                  if (progress > 0)
                    FractionallySizedBox(
                      widthFactor: (progress / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  // Task title
                  if (width > 50)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: Text(
                          widget.task.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Left resize handle (change start date)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragStart: (_) => setState(() => _isDraggingLeft = true),
              onHorizontalDragUpdate: (details) => _handleLeftDrag(details),
              onHorizontalDragEnd: (_) => _finishLeftDrag(),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: Container(
                  width: 8,
                  color: Colors.transparent,
                  child: _isDraggingLeft
                      ? Container(
                          width: 4,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
          
          // Right resize handle (change end date)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragStart: (_) => setState(() => _isDraggingRight = true),
              onHorizontalDragUpdate: (details) => _handleRightDrag(details),
              onHorizontalDragEnd: (_) => _finishRightDrag(),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: Container(
                  width: 8,
                  color: Colors.transparent,
                  child: _isDraggingRight
                      ? Container(
                          width: 4,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
          
          // Progress drag handle (bottom center)
          Positioned(
            left: (progress / 100 * width).clamp(8.0, width - 8),
            bottom: -4,
            child: GestureDetector(
              onHorizontalDragStart: (_) => setState(() => _isDraggingProgress = true),
              onHorizontalDragUpdate: (details) => _handleProgressDrag(details, width),
              onHorizontalDragEnd: (_) => _finishProgressDrag(),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isDraggingProgress ? Colors.amber : Colors.amber.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Dependency connection point (right side) - click to link
          Positioned(
            right: -8,
            top: barHeight / 2 - 8,
            child: GestureDetector(
              onTap: widget.onLinkPointTap,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: widget.isLinkSource 
                        ? Colors.orange
                        : widget.isLinkMode 
                            ? Colors.green.shade400
                            : Colors.green.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isLinkSource ? Colors.orange.shade800 : Colors.white, 
                      width: widget.isLinkSource ? 3 : 2,
                    ),
                    boxShadow: widget.isLinkSource ? [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: widget.isLinkMode && !widget.isLinkSource
                      ? const Icon(Icons.add, size: 10, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ),

          // Link indicator (shows when task has links, tap to manage)
          if (widget.hasLinks)
            Positioned(
              left: -6,
              top: barHeight / 2 - 6,
              child: GestureDetector(
                onTap: widget.onLinkTap,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.link, size: 8, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleLeftDrag(DragUpdateDetails details) {
    final taskStart = DateTime.parse(widget.task.startDate!);
    final taskEnd = DateTime.parse(widget.task.endDate!);
    final baseLeft = taskStart.difference(widget.startDate).inDays * widget.dayWidth;
    final baseWidth = (taskEnd.difference(taskStart).inDays + 1) * widget.dayWidth;
    
    final newLeft = (_tempLeft ?? baseLeft) + details.delta.dx;
    final newWidth = (_tempWidth ?? baseWidth) - details.delta.dx;
    
    if (newWidth >= widget.dayWidth) { // Minimum 1 day
      setState(() {
        _tempLeft = newLeft;
        _tempWidth = newWidth;
      });
    }
  }

  void _finishLeftDrag() {
    if (_tempLeft != null && _tempWidth != null) {
      final newStartOffset = (_tempLeft! / widget.dayWidth).round();
      final newDuration = (_tempWidth! / widget.dayWidth).round();
      
      final newStart = widget.startDate.add(Duration(days: newStartOffset));
      final newEnd = newStart.add(Duration(days: newDuration - 1));
      
      widget.onDateChange?.call(newStart, newEnd);
    }
    setState(() {
      _tempLeft = null;
      _tempWidth = null;
      _isDraggingLeft = false;
    });
  }

  void _handleRightDrag(DragUpdateDetails details) {
    final taskStart = DateTime.parse(widget.task.startDate!);
    final taskEnd = DateTime.parse(widget.task.endDate!);
    final baseWidth = (taskEnd.difference(taskStart).inDays + 1) * widget.dayWidth;
    
    final newWidth = (_tempWidth ?? baseWidth) + details.delta.dx;
    
    if (newWidth >= widget.dayWidth) { // Minimum 1 day
      setState(() {
        _tempWidth = newWidth;
      });
    }
  }

  void _finishRightDrag() {
    if (_tempWidth != null) {
      final taskStart = DateTime.parse(widget.task.startDate!);
      final newDuration = (_tempWidth! / widget.dayWidth).round();
      final newEnd = taskStart.add(Duration(days: newDuration - 1));
      
      widget.onDateChange?.call(taskStart, newEnd);
    }
    setState(() {
      _tempWidth = null;
      _isDraggingRight = false;
    });
  }

  void _handleProgressDrag(DragUpdateDetails details, double barWidth) {
    final currentProgress = _tempProgress ?? (widget.task.progress?.toDouble() ?? 0);
    final deltaPercent = (details.delta.dx / barWidth) * 100;
    final newProgress = (currentProgress + deltaPercent).clamp(0.0, 100.0);
    
    setState(() {
      _tempProgress = newProgress;
    });
  }

  void _finishProgressDrag() {
    if (_tempProgress != null) {
      widget.onProgressChange?.call(_tempProgress!.round());
    }
    setState(() {
      _tempProgress = null;
      _isDraggingProgress = false;
    });
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return Colors.red.shade400;
      case 'low':
        return Colors.grey.shade500;
      default:
        return Colors.blue.shade400;
    }
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_task, color: Colors.blue),
              title: const Text('添加子任务'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onAddSubtask?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              title: Text('任务: ${widget.task.title}'),
              subtitle: Text('进度: ${widget.task.progress ?? 0}%'),
            ),
          ],
        ),
      ),
    );
  }
}
