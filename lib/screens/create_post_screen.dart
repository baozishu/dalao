import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import 'post_detail_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      _showError('请输入标题');
      _titleFocus.requestFocus();
      return;
    }

    if (title.length > 40) {
      _showError('标题不能超过40个字符');
      _titleFocus.requestFocus();
      return;
    }

    if (content.isEmpty) {
      _showError('请输入内容');
      _contentFocus.requestFocus();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _api.createPost(
        subject: title,
        message: content,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('发帖成功'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        // 获取帖子ID并跳转到详情页
        final tid = result['tid'];
        if (tid != null) {
          final postId = int.tryParse(tid.toString()) ?? 0;
          if (postId > 0) {
            // 创建临时 Post 对象用于跳转
            final post = Post(
              id: postId,
              title: title,
              content: content,
              authorName: '',
              authorAvatar: '',
              authorId: 0,
              createdAt: DateTime.now(),
              viewCount: 0,
              replyCount: 0,
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(post: post),
              ),
            );
            return;
          }
        }
        Navigator.pop(context, true);
      } else {
        _showError(result['message'] ?? '发帖失败');
      }
    } catch (e) {
      _showError('发帖失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发表主题'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isSubmitting
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('发布'),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              focusNode: _titleFocus,
              maxLength: 40,
              decoration: InputDecoration(
                hintText: '请输入标题',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _contentFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              focusNode: _contentFocus,
              maxLines: 15,
              minLines: 8,
              decoration: InputDecoration(
                hintText: '请输入内容...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请遵守当地法律法规以及本社区规范！',
                      style: TextStyle(color: Colors.orange[800], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
