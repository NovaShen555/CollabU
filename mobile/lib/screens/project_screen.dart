import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/project_provider.dart';
import '../providers/team_provider.dart';
import '../models/team.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../widgets/empty_state_widget.dart';
import 'package:flutter/services.dart';


class ProjectScreen extends StatefulWidget {
  final int teamId;
  const ProjectScreen({super.key, required this.teamId});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProjectProvider>(context, listen: false).fetchProjects(widget.teamId);
    });
  }

  void _showInviteCode(BuildContext context, Team team) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('邀请码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              team.inviteCode ?? '暂无邀请码',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const Text('分享此代码给他人加入团队'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (team.inviteCode != null) {
                Clipboard.setData(ClipboardData(text: team.inviteCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showMembers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => FutureBuilder<List<User>>(
        future: Provider.of<TeamProvider>(context, listen: false).fetchTeamMembers(widget.teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return const Center(child: Text('暂无成员'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('团队成员', style: Theme.of(context).textTheme.titleLarge),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(member.username[0].toUpperCase()),
                      ),
                      title: Text(member.nickname ?? member.username),
                      subtitle: Text(member.email),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // teamProvider, team logic removed as we don't need title from it anymore
    
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, child) {
        if (projectProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (projectProvider.error != null) {
          return Center(child: Text('Error: ${projectProvider.error}'));
        }

        if (projectProvider.projects.isEmpty) {
          return EmptyStateWidget(
            message: '暂无项目',
            actionLabel: '新建项目',
            onAction: () => _showCreateProjectDialog(context),
          );
        }

        return ListView.builder(
          itemCount: projectProvider.projects.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final project = projectProvider.projects[index];
            return _buildProjectItem(context, project);
          },
        );
      },
    );
  }



  Widget _buildProjectItem(BuildContext context, Project project) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                project.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(project.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                project.status ?? 'unknown',
                style: TextStyle(
                  fontSize: 10,
                  color: _getStatusTextColor(project.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(project.description ?? '暂无描述'),
        ),
        onTap: () {
          context.push('/projects/${project.id}');
        },
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditProjectDialog(context, project);
            } else if (value == 'delete') {
              _confirmDeleteProject(context, project);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('删除项目', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProjectDialog(BuildContext context, Project project) {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description);
    
    const allowedStatuses = {'active', 'completed', 'archived'};
    String status = project.status ?? 'active';
    if (!allowedStatuses.contains(status)) {
      status = 'active';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑项目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '项目名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: '描述'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: '状态'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('进行中')),
                  DropdownMenuItem(value: 'completed', child: Text('已完成')),
                  DropdownMenuItem(value: 'archived', child: Text('归档')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => status = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final success = await Provider.of<ProjectProvider>(context, listen: false)
                    .updateProject(
                      project.id,
                      name: nameController.text,
                      description: descController.text,
                      status: status,
                    );
                if (mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('更新成功')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('更新失败')),
                    );
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定要删除 "${project.name}" 吗？此操作无法撤销，所有任务将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final success = await Provider.of<ProjectProvider>(context, listen: false)
                  .deleteProject(project.id);
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('项目已删除')),
                  );
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green.shade100;
      case 'completed':
        return Colors.blue.shade100;
      case 'archived':
        return Colors.grey.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green.shade900;
      case 'completed':
        return Colors.blue.shade900;
      case 'archived':
        return Colors.grey.shade900;
      default:
        return Colors.grey.shade900;
    }
  }

  void _showCreateProjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建项目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '项目名称'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: '描述'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final success = await Provider.of<ProjectProvider>(context, listen: false)
                  .createProject(widget.teamId, nameController.text, descController.text);
              if (mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(Provider.of<ProjectProvider>(context, listen: false).error ?? '创建失败')),
                  );
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
