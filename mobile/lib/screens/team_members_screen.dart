import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TeamMembersScreen extends StatefulWidget {
  final int teamId;
  const TeamMembersScreen({super.key, required this.teamId});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  List<dynamic> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final res = await ApiService.instance.get('/teams/${widget.teamId}/members');
      if (mounted) setState(() { _members = res.data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_members.isEmpty) return const Center(child: Text('暂无成员'));

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView.builder(
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text((member['nickname'] ?? member['username'] ?? 'U')[0].toUpperCase()),
            ),
            title: Text(member['nickname'] ?? member['username'] ?? '未知'),
            subtitle: Text(member['role'] == 'creator' ? '创建者' : '成员'),
            trailing: member['role'] == 'creator'
                ? const Icon(Icons.star, color: Colors.amber)
                : null,
          );
        },
      ),
    );
  }
}
