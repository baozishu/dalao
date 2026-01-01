import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

class MyPostScreen extends StatefulWidget {
  const MyPostScreen({super.key});

  @override
  State<MyPostScreen> createState() => _MyPostScreenState();
}

class _MyPostScreenState extends State<MyPostScreen> {
  final ApiService _apiService = ApiService();
  List<Post> _posts = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
  }

  Future<void> _loadMyPosts() async {
    if (!_hasMore) return;
    if (_isLoading && _posts.isNotEmpty) return;

    setState(() => _isLoading = true);

    try {
      final posts = await _apiService.getMyPosts(page: _currentPage);
      debugPrint('MyPostScreen: 获取到 ${posts.length} 个帖子，当前页=$_currentPage');

      if (mounted) {
        setState(() {
          if (posts.isEmpty) {
            _hasMore = false;
          } else {
            _posts.addAll(posts);
            _currentPage++;
          }
          _isLoading = false;
        });
      }

      debugPrint('MyPostScreen: 总共 ${_posts.length} 个帖子，hasMore=$_hasMore');
    } catch (e) {
      debugPrint('MyPostScreen: 加载失败 $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    await _loadMyPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的帖子'),
        elevation: 0,
      ),
      body: _isLoading && _posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '还没有发布任何帖子',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        if (!_isLoading) {
                          Future.microtask(() => _loadMyPosts());
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final post = _posts[index];
                      return PostCard(
                        post: post,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PostDetailScreen(post: post),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
