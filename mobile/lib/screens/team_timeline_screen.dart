import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../widgets/markdown_editor.dart';
import '../providers/auth_provider.dart';

class TeamTimelineScreen extends StatefulWidget {
  final int teamId;
  const TeamTimelineScreen({super.key, required this.teamId});

  @override
  State<TeamTimelineScreen> createState() => _TeamTimelineScreenState();
}

class _TeamTimelineScreenState extends State<TeamTimelineScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String _viewMode = 'list'; // list, detail, edit
  dynamic _selectedItem;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.get('/timeline/team/${widget.teamId}');
      if (mounted) {
        setState(() {
          _items = (res.data ?? []).map((item) {
            // Pre-process content to fix HTML images
            if (item['description'] != null && item['description'] is String) {
              item['description'] = _fixHtmlImages(item['description']);
            }
            return item;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fixHtmlImages(String content) {
    final RegExp imgTag = RegExp(r'<img[^>]+src="([^">]+)"[^>]*>');
    return content.replaceAllMapped(imgTag, (match) {
      final src = match.group(1);
      return '![]($src)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _viewMode == 'list' ? FloatingActionButton(
        onPressed: () => setState(() { _viewMode = 'edit'; _selectedItem = null; }),
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  AppBar _buildAppBar() {
    String title = '成果记录';
    if (_viewMode == 'detail') title = _selectedItem?['title'] ?? '详情';
    if (_viewMode == 'edit') title = _selectedItem == null ? '新建成果' : '编辑成果';

    return AppBar(
      title: Text(title),
      leading: _viewMode != 'list' ? IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => setState(() { _viewMode = 'list'; _selectedItem = null; }),
      ) : null,
      actions: _viewMode == 'detail' ? [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => setState(() => _viewMode = 'edit'),
        ),
      ] : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    switch (_viewMode) {
      case 'detail': return _buildDetailView();
      case 'edit': return _buildEditView();
      default: return _buildListView();
    }
  }

  Widget _buildListView() {
    if (_items.isEmpty) {
      return const Center(child: Text('暂无成果记录，点击右下角添加'));
    }
    return RefreshIndicator(
      onRefresh: _loadTimeline,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _buildTimelineItem(item, index == _items.length - 1);
        },
      ),
    );
  }

  Widget _buildTimelineItem(dynamic item, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
            ),
            if (!isLast) Container(width: 2, height: 100, color: Theme.of(context).dividerColor),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => setState(() { _viewMode = 'detail'; _selectedItem = item; }),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20),
                          onPressed: () => _confirmDelete(item['id']),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['event_date']?.toString().substring(0, 10) ?? '',
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                    ),
                    if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _getPreviewText(item['description']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getPreviewText(String markdown) {
    // Strip markdown syntax for preview
    return markdown
        .replaceAll(RegExp(r'[#*_`\[\]!\(\)]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
  }

  Widget _buildDetailView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedItem?['title'] ?? '',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
              const SizedBox(width: 4),
              Text(
                _selectedItem?['event_date']?.toString().substring(0, 10) ?? '',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              const SizedBox(width: 16),
              Icon(Icons.person, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
              const SizedBox(width: 4),
              Text(
                _selectedItem?['creator_name'] ?? '',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            ],
          ),
          const Divider(height: 24),
          MarkdownBody(
            data: _selectedItem?['description'] ?? '',
            selectable: true,
            onTapLink: (text, href, title) async {
              if (href != null) {
                String fullUrl = href;
                if (!href.startsWith('http')) {
                  String baseUrl = ApiService.baseUrl;
                  if (href.startsWith('/api/') && baseUrl.endsWith('/api')) {
                    fullUrl = '${baseUrl.substring(0, baseUrl.length - 4)}$href';
                  } else {
                    fullUrl = '$baseUrl${href.startsWith('/') ? '' : '/'}$href';
                  }
                }
                
                if (fullUrl.contains('/api/files/')) {
                  await _downloadAndOpenFile(fullUrl, text);
                } else {
                  final Uri uri = Uri.parse(fullUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              }
            },
            imageBuilder: (uri, title, alt) {
              String imageUrl = uri.toString();
              if (uri.scheme.isEmpty) {
                String baseUrl = ApiService.baseUrl;
                if (imageUrl.startsWith('/api/') && baseUrl.endsWith('/api')) {
                  imageUrl = '${baseUrl.substring(0, baseUrl.length - 4)}$imageUrl';
                } else {
                  imageUrl = '$baseUrl${imageUrl.startsWith('/') ? '' : '/'}$imageUrl';
                }
              }
              
              final token = Provider.of<AuthProvider>(context, listen: false).token;
              
              return Image.network(
                imageUrl,
                headers: token != null ? {'Authorization': 'Bearer $token'} : null,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 50, color: Theme.of(context).disabledColor),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              );
            },
          ),
          // Show attached files if any
          if (_selectedItem?['files'] != null && (_selectedItem['files'] as List).isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const Text('附件', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...(_selectedItem['files'] as List).map((file) => ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(file['filename'] ?? ''),
              onTap: () {
                String url = file['url'] ?? '';
                if (!url.startsWith('http')) {
                  String baseUrl = ApiService.baseUrl;
                  if (url.startsWith('/api/') && baseUrl.endsWith('/api')) {
                    url = '${baseUrl.substring(0, baseUrl.length - 4)}$url';
                  } else {
                    url = '$baseUrl$url';
                  }
                }
                _downloadAndOpenFile(url, file['filename']);
              },
            )),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadAndOpenFile(String url, String filename) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下载中...')));
      
      String saveName = filename;
      if (saveName.isEmpty || saveName.contains('/')) {
        saveName = url.split('/').last;
        if (saveName.contains('?')) saveName = saveName.split('?').first;
      }

      if (kIsWeb) {
        final response = await ApiService.instance.dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final blob = html.Blob([response.data]);
        final urlObj = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: urlObj)
          ..setAttribute("download", saveName)
          ..click();
        html.Url.revokeObjectUrl(urlObj);
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下载已开始')));
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final savePath = '${dir.path}/$saveName';
        
        await ApiService.instance.dio.download(url, savePath);
        
        final result = await OpenFilex.open(savePath);
        if (result.type != ResultType.done) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法打开文件: ${result.message}')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载失败: $e')));
    }
  }

  Widget _buildEditView() {
    return _TimelineEditorPage(
      initialTitle: _selectedItem?['title'] ?? '',
      initialContent: _selectedItem?['description'] ?? '',
      initialDate: _selectedItem != null 
          ? DateTime.tryParse(_selectedItem['event_date']?.toString() ?? '') ?? DateTime.now()
          : DateTime.now(),
      onSave: (title, content, date) => _saveTimeline(title, content, date),
    );
  }

  Future<void> _saveTimeline(String title, String content, DateTime date) async {
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    try {
      if (_selectedItem == null) {
        // Create new
        await ApiService.instance.post('/timeline', data: {
          'team_id': widget.teamId,
          'title': title,
          'description': content,
          'event_date': date.toIso8601String().substring(0, 10),
        });
      } else {
        // Update existing
        await ApiService.instance.put('/timeline/${_selectedItem['id']}', data: {
          'title': title,
          'description': content,
          'event_date': date.toIso8601String().substring(0, 10),
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
        setState(() { _viewMode = 'list'; _selectedItem = null; });
        _loadTimeline();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败')));
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个成果记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.instance.delete('/timeline/$id');
                _loadTimeline();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除成功')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
              }
            },
            child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class _TimelineEditorPage extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final DateTime initialDate;
  final Function(String, String, DateTime) onSave;

  const _TimelineEditorPage({
    required this.initialTitle,
    required this.initialContent,
    required this.initialDate,
    required this.onSave,
  });

  @override
  State<_TimelineEditorPage> createState() => _TimelineEditorPageState();
}

class _TimelineEditorPageState extends State<_TimelineEditorPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _contentCtrl = TextEditingController(text: widget.initialContent);
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 20, color: Theme.of(context).hintColor),
                  const SizedBox(width: 12),
                  Text(
                    '日期: ${_selectedDate.toString().substring(0, 10)}',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: Theme.of(context).hintColor),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: MarkdownEditor(
            initialContent: widget.initialContent,
            onChanged: (content) => _contentCtrl.text = content,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onSave(_titleCtrl.text, _contentCtrl.text, _selectedDate),
              child: const Text('保存'),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }
}
