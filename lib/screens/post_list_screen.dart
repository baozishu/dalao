import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post.dart';
import '../models/moyu_item.dart';
import '../models/domain_item.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  final ApiService _api = ApiService();

  // 分类配置: name, path, isMoyu, isMarket
  final List<Map<String, dynamic>> _tabs = [
    {'name': '新评论', 'path': '/index.htm', 'isMoyu': false, 'isMarket': false},
    {
      'name': '新帖子',
      'path': '/index-1-5.htm',
      'isMoyu': false,
      'isMarket': false
    },
    {
      'name': '推荐帖',
      'path': '/index-1-1.htm',
      'isMoyu': false,
      'isMarket': false
    },
    {'name': '摸鱼', 'path': '/index-1-2.htm', 'isMoyu': true, 'isMarket': false},
    {
      'name': '市场',
      'path': '/domain-market.htm',
      'isMoyu': false,
      'isMarket': true
    },
  ];

  // 每个 Tab 的数据和状态
  late List<_TabData> _tabDataList;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _pageController = PageController();

    // 初始化每个 Tab 的数据
    _tabDataList = _tabs.map((_) => _TabData()).toList();

    _tabController.addListener(_onTabChanged);

    // 加载第一个 Tab
    _loadData(0);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _pageController.animateToPage(
        _tabController.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // 如果该 Tab 还没加载过，则加载
      if (_tabDataList[_tabController.index].posts.isEmpty &&
          _tabDataList[_tabController.index].moyuItems.isEmpty &&
          _tabDataList[_tabController.index].domainItems.isEmpty &&
          !_tabDataList[_tabController.index].isLoading) {
        _loadData(_tabController.index);
      }
    }
  }

  Future<void> _loadData(int tabIndex) async {
    final tabData = _tabDataList[tabIndex];
    final tabConfig = _tabs[tabIndex];

    tabData.isLoading = true;
    tabData.hasError = false;
    if (mounted) setState(() {});

    try {
      if (tabConfig['isMarket'] == true) {
        // 域名市场 Tab
        final items = await _api.getDomainMarket(page: 1);
        tabData.domainItems = items;
        tabData.currentPage = 1;
      } else if (tabConfig['isMoyu'] == true) {
        // 摸鱼 Tab - 加载 RSS 聚合
        final items = await _api.getMoyuList(page: 1);
        tabData.moyuItems = items;
        tabData.currentPage = 1;
      } else {
        // 普通帖子 Tab
        final posts = await _api.getPostList(
          page: 1,
          category: tabConfig['path'],
        );
        tabData.posts = posts;
        tabData.currentPage = 1;
      }
      tabData.isLoading = false;
    } catch (e) {
      tabData.isLoading = false;
      tabData.hasError = true;
      tabData.errorMessage = e.toString();
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadMore(int tabIndex) async {
    final tabData = _tabDataList[tabIndex];
    final tabConfig = _tabs[tabIndex];

    if (tabData.isLoadingMore) return;
    tabData.isLoadingMore = true;

    try {
      final nextPage = tabData.currentPage + 1;

      if (tabConfig['isMarket'] == true) {
        final items = await _api.getDomainMarket(page: nextPage);
        if (items.isEmpty) {
          tabData.hasMore = false;
        } else {
          tabData.domainItems.addAll(items);
          tabData.currentPage = nextPage;
        }
      } else if (tabConfig['isMoyu'] == true) {
        final items = await _api.getMoyuList(page: nextPage);
        if (items.isEmpty) {
          tabData.hasMore = false;
        } else {
          tabData.moyuItems.addAll(items);
          tabData.currentPage = nextPage;
        }
      } else {
        final posts = await _api.getPostList(
          page: nextPage,
          category: tabConfig['path'],
        );
        if (posts.isEmpty) {
          tabData.hasMore = false;
        } else {
          tabData.posts.addAll(posts);
          tabData.currentPage = nextPage;
        }
      }
    } catch (e) {
      // 静默失败
    }

    tabData.isLoadingMore = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: _tabs.map((tab) => Tab(text: tab['name'])).toList(),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _tabs.length,
            onPageChanged: (index) {
              _tabController.animateTo(index);
              // 懒加载
              if (_tabDataList[index].posts.isEmpty &&
                  _tabDataList[index].moyuItems.isEmpty &&
                  _tabDataList[index].domainItems.isEmpty &&
                  !_tabDataList[index].isLoading) {
                _loadData(index);
              }
            },
            itemBuilder: (context, index) {
              final isMoyu = _tabs[index]['isMoyu'] == true;
              final isMarket = _tabs[index]['isMarket'] == true;
              if (isMarket) {
                return _buildMarketContent(index);
              } else if (isMoyu) {
                return _buildMoyuContent(index);
              } else {
                return _buildPostContent(index);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostContent(int tabIndex) {
    final tabData = _tabDataList[tabIndex];

    if (tabData.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tabData.hasError) {
      return _buildErrorWidget(tabIndex, tabData.errorMessage);
    }

    if (tabData.posts.isEmpty) {
      return _buildEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(tabIndex),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
            _loadMore(tabIndex);
          }
          return false;
        },
        child: ListView.builder(
          itemCount: tabData.posts.length + (tabData.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= tabData.posts.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final post = tabData.posts[index];
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
        ),
      ),
    );
  }

  Widget _buildMoyuContent(int tabIndex) {
    final tabData = _tabDataList[tabIndex];

    if (tabData.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tabData.hasError) {
      return _buildErrorWidget(tabIndex, tabData.errorMessage);
    }

    if (tabData.moyuItems.isEmpty) {
      return _buildEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(tabIndex),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
            _loadMore(tabIndex);
          }
          return false;
        },
        child: ListView.builder(
          itemCount: tabData.moyuItems.length + (tabData.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= tabData.moyuItems.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _buildMoyuItem(tabData.moyuItems[index]);
          },
        ),
      ),
    );
  }

  Widget _buildMoyuItem(MoyuItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _openUrl(item.url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.sourceIcon,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[300],
                    child: const Icon(Icons.rss_feed, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          item.author,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(item.publishedAt),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.source,
                            style: TextStyle(
                                fontSize: 11, color: Colors.blueGrey[700]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}-${time.day}';
  }

  Widget _buildErrorWidget(int tabIndex, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _loadData(tabIndex),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('暂无内容'),
        ],
      ),
    );
  }

  Widget _buildMarketContent(int tabIndex) {
    final tabData = _tabDataList[tabIndex];

    if (tabData.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tabData.hasError) {
      return _buildErrorWidget(tabIndex, tabData.errorMessage);
    }

    if (tabData.domainItems.isEmpty) {
      return _buildEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(tabIndex),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
            _loadMore(tabIndex);
          }
          return false;
        },
        child: ListView.builder(
          itemCount: tabData.domainItems.length + (tabData.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= tabData.domainItems.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _buildDomainItem(tabData.domainItems[index]);
          },
        ),
      ),
    );
  }

  Widget _buildDomainItem(DomainItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _showDomainDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          item.domain,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.isVerified)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    item.priceDisplay,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: item.isInquiry
                          ? Colors.grey[600]
                          : Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip('长度: ${item.length}'),
                  const SizedBox(width: 8),
                  _buildInfoChip('.${item.suffix}'),
                  const Spacer(),
                  Text(
                    item.publisherName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (item.description != null && item.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    item.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
      ),
    );
  }

  void _showDomainDetail(DomainItem domain) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _DomainDetailSheet(domain: domain),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

/// 每个 Tab 的数据状态
class _TabData {
  List<Post> posts = [];
  List<MoyuItem> moyuItems = [];
  List<DomainItem> domainItems = [];
  int currentPage = 1;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool hasError = false;
  String errorMessage = '';
}

/// 域名详情底部弹窗
class _DomainDetailSheet extends StatelessWidget {
  final DomainItem domain;

  const _DomainDetailSheet({required this.domain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  domain.domain,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (domain.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        '已验证',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow('价格', domain.priceDisplay),
          _buildDetailRow('长度', '${domain.length} 位'),
          _buildDetailRow('后缀', '.${domain.suffix}'),
          if (domain.description != null && domain.description!.isNotEmpty)
            _buildDetailRow('描述', domain.description!),
          _buildDetailRow('发布人', domain.publisherName),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: domain.domain));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('域名已复制')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('复制域名'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请在网页端联系卖家')),
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('联系卖家'),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
