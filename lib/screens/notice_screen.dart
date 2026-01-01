import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/notice.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import 'post_detail_screen.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  final List<List<Notice>> _notices = [[], [], []]; // 系统、回复、@我
  final List<bool> _isLoading = [true, true, true];
  final List<bool> _hasMore = [true, true, true];
  final List<int> _pages = [1, 1, 1];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _loadNotices(1); // 默认加载回复
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final type = _tabController.index + 1;
        if (_notices[_tabController.index].isEmpty) {
          _loadNotices(type);
        }
      }
    });
  }

  Future<void> _loadNotices(int type, {bool refresh = false}) async {
    final index = type - 1;
    if (refresh) {
      _pages[index] = 1;
      _hasMore[index] = true;
    }

    setState(() {
      _isLoading[index] = true;
    });

    try {
      final notices = await _api.getNotices(type: type, page: _pages[index]);
      setState(() {
        if (refresh || _pages[index] == 1) {
          _notices[index] = notices;
        } else {
          _notices[index].addAll(notices);
        }
        _hasMore[index] = notices.length >= 10;
        _isLoading[index] = false;
      });
    } catch (e) {
      setState(() {
        _isLoading[index] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _loadMore(int type) async {
    final index = type - 1;
    if (!_hasMore[index] || _isLoading[index]) return;
    _pages[index]++;
    await _loadNotices(type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '系统'),
            Tab(text: '回复'),
            Tab(text: '@我'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNoticeList(1),
          _buildNoticeList(2),
          _buildNoticeList(3),
        ],
      ),
    );
  }

  Widget _buildNoticeList(int type) {
    final index = type - 1;
    final notices = _notices[index];
    final isLoading = _isLoading[index];

    if (isLoading && notices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无消息', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _loadNotices(type, refresh: true),
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotices(type, refresh: true),
      child: ListView.builder(
        itemCount: notices.length + (_hasMore[index] ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == notices.length) {
            _loadMore(type);
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildNoticeItem(notices[i]);
        },
      ),
    );
  }

  Widget _buildNoticeItem(Notice notice) {
    return ListTile(
      leading: _buildAvatar(notice),
      title: Text(
        notice.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notice.postTitle != null && notice.postTitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                notice.postTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
      onTap: () => _onNoticeTap(notice),
    );
  }

  Widget _buildAvatar(Notice notice) {
    if (notice.fromUserAvatar.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: notice.fromUserAvatar,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (context, url) => _defaultAvatar(notice),
          errorWidget: (context, url, error) => _defaultAvatar(notice),
        ),
      );
    }
    return _defaultAvatar(notice);
  }

  Widget _defaultAvatar(Notice notice) {
    return CircleAvatar(
      radius: 20,
      backgroundColor:
          notice.type == 'system' ? Colors.blue[100] : Colors.grey[300],
      child: Icon(
        notice.type == 'system' ? Icons.notifications : Icons.person,
        color: notice.type == 'system' ? Colors.blue : Colors.grey[600],
      ),
    );
  }

  void _onNoticeTap(Notice notice) async {
    if (notice.postId != null) {
      // 跳转到帖子详情
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
    _tabController.dispose();
    super.dispose();
  }
}
