import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TeamLearningScreen extends StatefulWidget {
  final int teamId;
  const TeamLearningScreen({super.key, required this.teamId});

  @override
  State<TeamLearningScreen> createState() => _TeamLearningScreenState();
}

class _TeamLearningScreenState extends State<TeamLearningScreen> {
  List<dynamic> _feed = [];
  List<dynamic> _members = [];
  bool _isLoading = true;
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final feedRes = await ApiService.instance.get('/learning/team/${widget.teamId}');
      final membersRes = await ApiService.instance.get('/teams/${widget.teamId}/members');
      if (mounted) {
        setState(() {
          _feed = feedRes.data ?? [];
          _members = membersRes.data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学习进度')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildInputSection(),
                Expanded(child: _buildFeedList()),
              ],
            ),
    );
  }

  // 继续...

  Widget _buildInputSection() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('记录今日学习', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: '今天学了什么...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _submitLearning,
                child: const Text('发布'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 继续2...

  Widget _buildFeedList() {
    if (_feed.isEmpty) {
      return const Center(child: Text('暂无学习记录'));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _feed.length,
        itemBuilder: (context, index) {
          final item = _feed[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                child: Text((item['nickname'] ?? 'U')[0].toUpperCase()),
              ),
              title: Text(item['nickname'] ?? '用户'),
              subtitle: Text(item['content'] ?? ''),
              trailing: Text(
                item['created_at']?.toString().substring(0, 10) ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          );
        },
      ),
    );
  }

  // 继续3...

  Future<void> _submitLearning() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入学习内容')),
      );
      return;
    }
    try {
      await ApiService.instance.post('/learning', data: {
        'team_id': widget.teamId,
        'content': _contentController.text,
      });
      _contentController.clear();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发布成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发布失败')),
        );
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
