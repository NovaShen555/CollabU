import 'package:flutter/material.dart';

class GanttHeader extends StatelessWidget {
  final DateTime startDate;
  final int totalDays;
  final double dayWidth;

  const GanttHeader({
    super.key,
    required this.startDate,
    required this.totalDays,
    required this.dayWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: List.generate(totalDays, (index) {
          final date = startDate.add(Duration(days: index));
          final isWeekend = date.weekday == DateTime.saturday ||
                           date.weekday == DateTime.sunday;
          final isToday = _isToday(date);

          return Container(
            width: dayWidth,
            decoration: BoxDecoration(
              color: isToday
                  ? Colors.blue.withValues(alpha: 0.1)
                  : isWeekend
                      ? Colors.grey.shade200
                      : null,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.blue : Colors.black87,
                  ),
                ),
                Text(
                  _getWeekdayShort(date.weekday),
                  style: TextStyle(
                    fontSize: 10,
                    color: isWeekend ? Colors.red.shade300 : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  String _getWeekdayShort(int weekday) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return days[weekday - 1];
  }
}
