import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late String _status;
  final _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoadingComments = false;

  @override
  void initState() {
    super.initState();
    _status = widget.task.status ?? 'pending';
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoadingComments = true;
    });
    final comments = await Provider.of<TaskProvider>(context, listen: false).fetchComments(widget.task.id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _updateStatus(String? newStatus) async {
    if (newStatus != null && newStatus != _status) {
      final success = await Provider.of<TaskProvider>(context, listen: false)
          .updateTaskStatus(widget.task.id, newStatus);
      if (success) {
        setState(() {
          _status = newStatus;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('状态已更新')),
          );
          // Trigger refresh in parent list if possible? 
          // For now, we rely on the list view refreshing when we go back or pulled.
        }
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isNotEmpty) {
      final success = await Provider.of<TaskProvider>(context, listen: false)
          .addComment(widget.task.id, _commentController.text);
      if (success) {
        _commentController.clear();
        _fetchComments();
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个任务吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await Provider.of<TaskProvider>(context, listen: false)
                  .deleteTask(widget.task.id);
              if (mounted) {
                if (success) {
                  Navigator.pop(context); // Go back to list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('删除失败')),
                  );
                }
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final titleController = TextEditingController(text: widget.task.title);
    final descController = TextEditingController(text: widget.task.description);
    String priority = widget.task.priority ?? 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('编辑任务', style: Theme.of(context).textTheme.titleLarge),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '任务标题'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: '描述'),
                maxLines: 3,
              ),
              DropdownButton<String>(
                value: priority,
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('低')),
                  DropdownMenuItem(value: 'medium', child: Text('中')),
                  DropdownMenuItem(value: 'high', child: Text('高')),
                ],
                onChanged: (v) => setSheetState(() => priority = v!),
              ),
              ElevatedButton(
                onPressed: () async {
                  final success = await Provider.of<TaskProvider>(context, listen: false).updateTask(
                    widget.task.id,
                    title: titleController.text,
                    description: descController.text,
                    priority: priority,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('更新成功')),
                      );
                      Navigator.pop(context); // Go back to list to refresh
                    }
                  }
                },
                child: const Text('保存'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.task.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (widget.task.description != null)
                    Text(
                      widget.task.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text('状态: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _status,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('未开始')),
                          DropdownMenuItem(value: 'in_progress', child: Text('进行中')),
                          DropdownMenuItem(value: 'completed', child: Text('已完成')),
                        ],
                        onChanged: _updateStatus,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('优先级: ${widget.task.priority ?? "medium"}'),
                  const SizedBox(height: 16),
                  if (widget.task.startDate != null)
                    Text('开始时间: ${widget.task.startDate}'),
                  if (widget.task.endDate != null)
                    Text('结束时间: ${widget.task.endDate}'),
                  
                  const SizedBox(height: 32),
                  const Text('评论', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_isLoadingComments)
                    const Center(child: CircularProgressIndicator())
                  else if (_comments.isEmpty)
                    const Text('暂无评论', style: TextStyle(color: Colors.grey))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(comment['nickname'] != null && comment['nickname'].isNotEmpty
                                ? comment['nickname'][0].toUpperCase()
                                : 'U'),
                          ),
                          title: Text(comment['nickname'] ?? comment['username'] ?? 'User'),
                          subtitle: Text(comment['content']),
                          trailing: Text(
                            comment['created_at'].toString().substring(0, 10),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: '添加评论...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
