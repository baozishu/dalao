import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'post_list_screen.dart';
import 'merchant_screen.dart';
import 'message_screen.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import '../providers/message_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const PostListScreen(),
    const MerchantScreen(),
    const MessageScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 开始检查未读消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessageProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    context.read<MessageProvider>().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大佬论坛'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Consumer<MessageProvider>(
        builder: (context, messageProvider, _) {
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              // 如果切换到消息页面，标记为已读
              if (index == 2) {
                messageProvider.markAsRead();
              }
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              const NavigationDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store),
                label: '商家',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('${messageProvider.unreadCount}'),
                  isLabelVisible: messageProvider.unreadCount > 0,
                  child: const Icon(Icons.message_outlined),
                ),
                selectedIcon: Badge(
                  label: Text('${messageProvider.unreadCount}'),
                  isLabelVisible: messageProvider.unreadCount > 0,
                  child: const Icon(Icons.message),
                ),
                label: '消息',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          );
        },
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _createPost(context),
              tooltip: '发帖',
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: PostSearchDelegate(),
    );
  }

  void _createPost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
  }
}

class PostSearchDelegate extends SearchDelegate<String> {
  final ApiService _api = ApiService();
  int _searchRange = 1; // 1=标题, 0=内容, 3=用户

  @override
  String get searchFieldLabel => '搜索帖子...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      // X 按钮 - 关闭搜索
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => close(context, ''),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('请输入搜索关键词'));
    }

    return FutureBuilder<List<Post>>(
      future: _api.search(query, range: _searchRange),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text('搜索失败: ${snapshot.error}'),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('未找到相关结果'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(
              post: post,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: post),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '搜索范围',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildRangeChip('标题', 1, setState, context),
                  const SizedBox(width: 8),
                  _buildRangeChip('内容', 0, setState, context),
                  const SizedBox(width: 8),
                  _buildRangeChip('用户', 3, setState, context),
                ],
              ),
              const SizedBox(height: 24),
              if (query.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => showResults(context),
                    icon: const Icon(Icons.search),
                    label: Text('搜索 "$query"'),
                  ),
                ),
              if (query.isEmpty)
                Text(
                  '输入关键词后点击搜索',
                  style: TextStyle(color: Colors.grey[500]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRangeChip(
      String label, int value, StateSetter setState, BuildContext context) {
    final selected = _searchRange == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _searchRange = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).primaryColor : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
