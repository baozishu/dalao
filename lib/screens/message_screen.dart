import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'post_detail_screen.dart';
import 'webview_login_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Tab 顺序: 私信(7), 评论我的(2), 提及我的(156), 系统通知(3)
  static const List<int> _noticeTypes = [7, 2, 156, 3];
  static const List<String> _tabTitles = ['私信', '评论', '提及', '系统'];

  final List<List<Notice>> _notices = [[], [], [], []];
  final List<bool> _isLoading = [false, false, false, false];
  final List<bool> _hasMore = [true, true, true, true];
  final List<int> _pages = [1, 1, 1, 1];
  final List<bool> _hasLoaded = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _loadNotices(1); // 默认加载评论我的
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      if (!_hasLoaded[_tabController.index]) {
        _loadNotices(_tabController.index);
      }
    }
  }

  Future<void> _loadNotices(int tabIndex, {bool refresh = false}) async {
    if (_isLoading[tabIndex]) return;

    final type = _noticeTypes[tabIndex];

    if (refresh) {
      _pages[tabIndex] = 1;
      _hasMore[tabIndex] = true;
    }

    setState(() {
      _isLoading[tabIndex] = true;
    });

    try {
      debugPrint('加载消息: type=$type, page=${_pages[tabIndex]}');
      final notices = await _api.getNotices(type: type, page: _pages[tabIndex]);
      debugPrint('获取到 ${notices.length} 条消息');

      if (mounted) {
        setState(() {
          if (refresh || _pages[tabIndex] == 1) {
            _notices[tabIndex] = notices;
          } else {
            _notices[tabIndex].addAll(notices);
          }
          _hasMore[tabIndex] = notices.length >= 10;
          _isLoading[tabIndex] = false;
          _hasLoaded[tabIndex] = true;
        });
      }
    } catch (e) {
      debugPrint('加载消息失败: $e');
      if (mounted) {
        setState(() {
          _isLoading[tabIndex] = false;
          _hasLoaded[tabIndex] = true;
        });
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '加载失败: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _loadNotices(tabIndex, refresh: true),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadMore(int tabIndex) async {
    if (!_hasMore[tabIndex] || _isLoading[tabIndex]) return;
    _pages[tabIndex]++;
    await _loadNotices(tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: _tabTitles.map((t) => Tab(text: t)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(4, (i) => _buildNoticeList(i)),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeList(int tabIndex) {
    // 检查登录状态
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('请先登录查看消息', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const WebViewLoginScreen()),
                );
                if (result == true && mounted) {
                  _loadNotices(tabIndex, refresh: true);
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('去登录'),
            ),
          ],
        ),
      );
    }

    final notices = _notices[tabIndex];
    final isLoading = _isLoading[tabIndex];

    if (isLoading && notices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notices.isEmpty && _hasLoaded[tabIndex]) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无消息', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _loadNotices(tabIndex, refresh: true),
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotices(tabIndex, refresh: true),
      child: ListView.builder(
        itemCount: notices.length + (_hasMore[tabIndex] ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == notices.length) {
            // 延迟调用避免在 build 过程中 setState
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadMore(tabIndex);
            });
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildNoticeItem(notices[i], tabIndex);
        },
      ),
    );
  }

  Widget _buildNoticeItem(Notice notice, int tabIndex) {
    return ListTile(
      leading: _buildAvatar(notice, tabIndex),
      title: Text(
        notice.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notice.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                notice.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ),
          if (notice.postTitle != null && notice.postTitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '📄 ${notice.postTitle!}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _formatTime(notice.createdAt),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        ],
      ),
      onTap: () => _onNoticeTap(notice, tabIndex),
    );
  }

  Widget _buildAvatar(Notice notice, int tabIndex) {
    if (notice.fromUserAvatar.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: notice.fromUserAvatar,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (context, url) => _defaultAvatar(notice, tabIndex),
          errorWidget: (context, url, error) =>
              _defaultAvatar(notice, tabIndex),
        ),
      );
    }
    return _defaultAvatar(notice, tabIndex);
  }

  Widget _defaultAvatar(Notice notice, int tabIndex) {
    final isSystem = tabIndex == 3; // 系统通知
    final isPrivate = tabIndex == 0; // 私信

    IconData icon;
    Color? bgColor;
    Color? iconColor;

    if (isSystem) {
      icon = Icons.notifications;
      bgColor = Colors.blue[100];
      iconColor = Colors.blue;
    } else if (isPrivate) {
      icon = Icons.mail;
      bgColor = Colors.green[100];
      iconColor = Colors.green;
    } else {
      icon = Icons.person;
      bgColor = Colors.grey[300];
      iconColor = Colors.grey[600];
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: bgColor,
      child: Icon(icon, color: iconColor),
    );
  }

  void _onNoticeTap(Notice notice, int tabIndex) {
    if (notice.postId != null) {
      final post = Post(
        id: notice.postId!,
        title: notice.postTitle ?? '',
        content: '',
        authorName: '',
        createdAt: DateTime.now(),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('MM-dd HH:mm').format(time);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
}
