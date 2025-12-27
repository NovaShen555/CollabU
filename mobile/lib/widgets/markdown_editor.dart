import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class MarkdownEditor extends StatefulWidget {
  final String? initialContent;
  final Function(String content, List<Map<String, String>> attachments)? onSave;
  final Function(String)? onChanged;
  final String? title;

  const MarkdownEditor({
    super.key,
    this.initialContent,
    this.onSave,
    this.onChanged,
    this.title,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _controller;
  bool _isPreview = false;
  bool _isUploading = false;
  List<Map<String, String>> _attachments = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(child: _isPreview ? _buildPreview() : _buildEditor()),
        if (_attachments.isNotEmpty) _buildAttachmentList(),
      ],
    );
  }

  // 继续...

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _toolButton(Icons.format_bold, () => _insertText('**', '**')),
          _toolButton(Icons.format_italic, () => _insertText('*', '*')),
          _toolButton(Icons.format_list_bulleted, () => _insertText('\n- ', '')),
          _toolButton(Icons.format_list_numbered, () => _insertText('\n1. ', '')),
          _toolButton(Icons.code, () => _insertText('`', '`')),
          _toolButton(Icons.link, _insertLink),
          const VerticalDivider(width: 16),
          _toolButton(Icons.image, _pickImage),
          _toolButton(Icons.attach_file, _pickFile),
          const Spacer(),
          TextButton.icon(
            icon: Icon(_isPreview ? Icons.edit : Icons.preview),
            label: Text(_isPreview ? '编辑' : '预览'),
            onPressed: () => setState(() => _isPreview = !_isPreview),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  // 继续2...

  Widget _buildEditor() {
    return TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        hintText: '输入Markdown内容...',
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(12),
      ),
      style: const TextStyle(fontFamily: 'monospace'),
      onChanged: (value) => widget.onChanged?.call(value),
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: MarkdownBody(
        data: _controller.text,
        selectable: true,
      ),
    );
  }

  // 继续3...

  Widget _buildAttachmentList() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('附件', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _attachments.map((a) => Chip(
              label: Text(a['name'] ?? '', overflow: TextOverflow.ellipsis),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _attachments.remove(a)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // 继续4...

  void _insertText(String prefix, String suffix) {
    final text = _controller.text;
    final selection = _controller.selection;
    final selectedText = selection.textInside(text);
    final newText = '$prefix$selectedText$suffix';

    _controller.text = text.replaceRange(selection.start, selection.end, newText);
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + prefix.length + selectedText.length,
    );
  }

  void _insertLink() {
    showDialog(
      context: context,
      builder: (ctx) {
        final urlCtrl = TextEditingController();
        final textCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('插入链接'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: textCtrl, decoration: const InputDecoration(labelText: '链接文字')),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _insertText('[${textCtrl.text}](', '${urlCtrl.text})');
              },
              child: const Text('插入'),
            ),
          ],
        );
      },
    );
  }

  // 继续5...

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await _uploadFile(File(image.path), image.name);
      if (url != null) {
        _insertText('![${image.name}](', '$url)');
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // 继续6...

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await _uploadFile(File(file.path!), file.name);
      if (url != null) {
        _attachments.add({'name': file.name, 'url': url});
        _insertText('[${file.name}](', '$url)');
        setState(() {});
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // 继续7...

  Future<String?> _uploadFile(File file, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: filename),
      });
      final res = await ApiService.instance.dio.post('/files/upload', data: formData);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return res.data['url'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传失败')),
        );
      }
    }
    return null;
  }

  String get content => _controller.text;
  List<Map<String, String>> get attachments => _attachments;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
