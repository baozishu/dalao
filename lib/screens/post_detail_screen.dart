import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final ApiService _api = ApiService();
  final FocusNode _commentFocusNode = FocusNode();

  late Post _post;
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMoreComments = true;
  bool _isSubmitting = false;
  Comment? _replyToComment;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    // 添加浏览历史
    HistoryService.addHistory(_post);
    _loadPostDetail();
  }

  Future<void> _loadPostDetail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final postDetail = await _api.getPostDetail(_post.id);
      if (postDetail != null) _post = postDetail;
      final comments = await _api.getComments(_post.id, page: 1);
      debugPrint('加载到 ${comments.length} 条评论');
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
          _hasMoreComments = comments.length >= 10;
        });
      }
    } catch (e) {
      debugPrint('加载帖子详情失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (!_hasMoreComments) return;
    _currentPage++;
    try {
      final more = await _api.getComments(_post.id, page: _currentPage);
      setState(() {
        _comments.addAll(more);
        _hasMoreComments = more.length >= 10;
      });
    } catch (e) {
      debugPrint('加载更多评论失败: $e');
    }
  }

  void _copyContent(String text) {
    final plainText = text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    Clipboard.setData(ClipboardData(text: plainText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('代码已复制'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('帖子详情'),
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadPostDetail),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'copy',
                  child: Row(children: [
                    Icon(Icons.copy, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    const Text('复制内容')
                  ])),
              PopupMenuItem(
                  value: 'share',
                  child: Row(children: [
                    Icon(Icons.share, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    const Text('分享')
                  ])),
              PopupMenuItem(
                  value: 'report',
                  child: Row(children: [
                    Icon(Icons.flag, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    const Text('举报')
                  ])),
            ],
            onSelected: (v) {
              if (v == 'copy')
                _copyContent(_post.content);
              else if (v == 'share') _sharePost();
            },
          ),
        ],
      ),
      body: _hasError
          ? _buildErrorView()
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadPostDetail,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverToBoxAdapter(child: _buildPostCard(isDark)),
                        SliverToBoxAdapter(child: _buildCommentHeader()),
                        _buildCommentList(),
                      ],
                    ),
                  ),
                ),
                _buildCommentInput(),
              ],
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('加载失败', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(_errorMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPostDetail,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[50],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_post.isPinned)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Colors.orange[400]!, Colors.orange[600]!]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('置顶',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                Text(_post.title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.3)),
              ],
            ),
          ),
          // 作者信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildAvatar(_post.authorAvatar, _post.authorName, 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_post.authorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                          DateFormat('yyyy-MM-dd HH:mm')
                              .format(_post.createdAt),
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                _buildStatChip(Icons.visibility_outlined, '${_post.viewCount}'),
                const SizedBox(width: 8),
                _buildStatChip(
                    Icons.chat_bubble_outline, '${_post.replyCount}'),
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容区域
          _buildContentArea(isDark),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildContentArea(bool isDark) {
    if (_isLoading && _post.content.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Html(
        data: _post.content.isNotEmpty ? _post.content : '<p>内容加载中...</p>',
        style: {
          'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontSize: FontSize(15),
              lineHeight: LineHeight(1.6)),
          'p': Style(margin: Margins.only(bottom: 12)),
          'img': Style(margin: Margins.symmetric(vertical: 8)),
          'a': Style(
              color: Colors.blue[700], textDecoration: TextDecoration.none),
          'blockquote': Style(
            margin: Margins.symmetric(vertical: 8),
            padding: HtmlPaddings.only(left: 12),
            border:
                Border(left: BorderSide(color: Colors.grey[300]!, width: 3)),
            color: Colors.grey[600],
          ),
        },
        extensions: [
          TagExtension(
            tagsToExtend: {'pre', 'code'},
            builder: (context) => _buildCodeBlock(context, isDark),
          ),
        ],
        onLinkTap: (url, _, __) => _openUrl(url),
      ),
    );
  }

  Widget _buildCodeBlock(ExtensionContext context, bool isDark) {
    final code = context.element?.text ?? '';
    final lang =
        context.element?.attributes['class']?.replaceAll('language-', '') ?? '';
    if (code.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 代码头部
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Icon(Icons.code, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(lang.isNotEmpty ? lang.toUpperCase() : 'CODE',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                InkWell(
                  onTap: () => _copyCode(code),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('复制',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 代码内容
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(7)),
            child: HighlightView(
              code.trim(),
              language: lang.isNotEmpty ? lang : 'plaintext',
              theme: isDark ? monokaiSublimeTheme : githubTheme,
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(
                  fontFamily: 'monospace', fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('评论',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('${_comments.length}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator())));
    }
    if (_comments.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('暂无评论',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15)),
              const SizedBox(height: 4),
              Text('快来抢沙发吧~',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _comments.length) {
            return _hasMoreComments
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                        child: TextButton(
                            onPressed: _loadMoreComments,
                            child: const Text('加载更多'))))
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: Text('没有更多了',
                            style: TextStyle(color: Colors.grey))));
          }
          return _buildCommentItem(_comments[index], index);
        },
        childCount: _comments.length + 1,
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(comment.authorAvatar, comment.authorName, 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(comment.authorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        if (comment.isPinned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4)),
                            child: const Text('楼主',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    Text(_formatTime(comment.createdAt),
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ),
              Text('#${index + 1}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          if (comment.replyToName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4)),
              child: Text('回复 @${comment.replyToName}',
                  style: TextStyle(color: Colors.blue[700], fontSize: 12)),
            ),
          Html(
            data: comment.content,
            style: {
              'body': Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(14),
                  lineHeight: LineHeight(1.5)),
            },
            extensions: [
              TagExtension(
                  tagsToExtend: {'pre', 'code'},
                  builder: (ctx) => _buildCodeBlock(ctx, isDark))
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildActionButton(Icons.thumb_up_outlined, '赞', () {}),
              const SizedBox(width: 16),
              _buildActionButton(Icons.reply, '回复', () => _setReplyTo(comment)),
              const Spacer(),
              _buildActionButton(
                  Icons.copy, '复制', () => _copyContent(comment.content)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToComment != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text('回复 @${_replyToComment!.authorName}',
                            style: TextStyle(
                                color: Colors.blue[700], fontSize: 13))),
                    GestureDetector(
                        onTap: _cancelReply,
                        child: Icon(Icons.close,
                            size: 18, color: Colors.blue[700])),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      decoration: InputDecoration(
                        hintText: _replyToComment != null
                            ? '回复 @${_replyToComment!.authorName}...'
                            : '写下你的评论...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      maxLines: null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _isSubmitting ? null : _submitComment,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send,
                              color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String url, String name, double size) {
    if (url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _defaultAvatar(name, size),
          errorWidget: (_, __, ___) => _defaultAvatar(name, size),
        ),
      );
    }
    return _defaultAvatar(name, size);
  }

  Widget _defaultAvatar(String name, double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.primaries[name.hashCode % Colors.primaries.length]
          .withOpacity(0.2),
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color:
                  Colors.primaries[name.hashCode % Colors.primaries.length])),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }

  void _setReplyTo(Comment comment) {
    setState(() => _replyToComment = comment);
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() => setState(() => _replyToComment = null);

  void _sharePost() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('分享功能开发中')));
  }

  Future<void> _openUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    if (!_api.hasCookies) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请先登录后再评论')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final success = await _api.postComment(
          _post.id, _commentController.text.trim(),
          replyPid: _replyToComment?.id,
          replyUserName: _replyToComment?.authorName);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('评论发送成功'), backgroundColor: Colors.green));
        _commentController.clear();
        _cancelReply();
        _currentPage = 1;
        final comments = await _api.getComments(_post.id, page: 1);
        setState(() {
          _comments = comments;
          _hasMoreComments = comments.length >= 10;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('评论发送失败'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送失败: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
