import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TeamCalendarScreen extends StatefulWidget {
  final int teamId;
  const TeamCalendarScreen({super.key, required this.teamId});

  @override
  State<TeamCalendarScreen> createState() => _TeamCalendarScreenState();
}

class _TeamCalendarScreenState extends State<TeamCalendarScreen> {
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.get(
        '/teams/${widget.teamId}/tasks',
      );
      if (mounted) {
        setState(() {
          _tasks = res.data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildCalendarHeader(),
              _buildWeekDays(),
              Expanded(child: _buildCalendarGrid()),
              if (_selectedDate != null) _buildTaskList(),
            ],
          );
  }

  // 继续...

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            }),
          ),
          Text(
            '${_focusedMonth.year}年${_focusedMonth.month}月',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
            }),
          ),
        ],
      ),
    );
  }

  // 继续2...

  Widget _buildWeekDays() {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: days.map((d) => Expanded(
        child: Center(
          child: Text(d, style: TextStyle(
            fontWeight: FontWeight.bold,
            color: d == '六' || d == '日' ? Colors.red.shade300 : Colors.grey,
          )),
        ),
      )).toList(),
    );
  }

  // 继续3...

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final dayOffset = index - startWeekday + 1;
        if (dayOffset < 1 || dayOffset > daysInMonth) {
          return const SizedBox();
        }
        final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayOffset);
        final tasksOnDay = _getTasksForDate(date);
        final isSelected = _selectedDate?.day == dayOffset &&
            _selectedDate?.month == _focusedMonth.month;
        final isToday = _isToday(date);

        return _buildDayCell(dayOffset, tasksOnDay, isSelected, isToday, date);
      },
    );
  }

  // 继续4...



  // Override tasks list rendering in cell to prevent overflow and show dots for more? 
  // Actually, for a proper "continuous bar" effect in a GridView cell:
  // We need to render the bar at absolute offsets.
  // The above simple implementation stacks them.
  // To make them "continuous" visually, they must be at the SAME vertical offset in every cell.
  
  // Revised _buildDayCell implementation utilizing a Stack constraint for better alignment
  Widget _buildDayCell(int day, List tasks, bool isSelected, bool isToday, DateTime date) {
    // Sort tasks by ID to ensure stable vertical ordering
    tasks.sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));

    return InkWell(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        margin: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : (isToday ? Colors.blue.withOpacity(0.05) : null),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Text('$day', style: TextStyle(
                color: isSelected ? Colors.blue : null,
                fontWeight: isToday ? FontWeight.bold : null,
                fontSize: 12,
              )),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column( // Use Column instead of Stack for simpler flow, but need consistent heights
                children: tasks.take(4).map((task) {
                   return Container(
                     height: 4,
                     margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0), // No horizontal margin for continuity
                     width: double.infinity,
                     color: _getPriorityColor(task['priority']),
                   );
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 继续5...

  Widget _buildTaskList() {
    final tasks = _getTasksForDate(_selectedDate!);
    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: tasks.isEmpty
          ? const Center(child: Text('当天无任务'))
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (ctx, i) {
                final t = tasks[i];
                return ListTile(
                  leading: Icon(Icons.task_alt, color: _getPriorityColor(t['priority'])),
                  title: Text(t['title'] ?? ''),
                  subtitle: Text(t['status'] ?? ''),
                );
              },
            ),
    );
  }

  // 继续6...

  List _getTasksForDate(DateTime date) {
    final dateStr = date.toIso8601String().substring(0, 10);
    return _tasks.where((t) {
      final start = t['start_date']?.toString().substring(0, 10);
      final end = t['end_date']?.toString().substring(0, 10);
      if (start == null || end == null) return false;
      return dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0;
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high': return Colors.red;
      case 'low': return Colors.green;
      default: return Colors.orange;
    }
  }
}
