import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'webview_screen.dart';
import 'favorite_screen.dart';
import 'my_post_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  User? _userProfile;
  bool _isLoading = true;
  String _version = '加载中...';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('加载版本信息失败: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _api.getMyProfile();
      if (mounted && profile != null) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
        // 更新 AuthProvider 中的用户信息
        context.read<AuthProvider>().setUser(profile);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('加载用户资料失败: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = _userProfile ?? auth.user;
        return RefreshIndicator(
          onRefresh: _loadUserProfile,
          child: ListView(
            children: [
              _buildUserHeader(context, user),
              const SizedBox(height: 16),
              _buildStatsCard(context, user),
              const SizedBox(height: 16),
              _buildMenuSection(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserHeader(BuildContext context, User? user) {
    final avatar = user?.avatar ?? '';
    final nickname = user?.nickname ?? '用户';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 头像
            if (avatar.isNotEmpty)
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatar,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildDefaultAvatar(nickname),
                  errorWidget: (_, __, ___) => _buildDefaultAvatar(nickname),
                ),
              )
            else
              _buildDefaultAvatar(nickname),
            const SizedBox(height: 12),
            Text(
              nickname,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (user?.id != null && user!.id > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'UID: ${user.id}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            if (user?.signature != null && user!.signature!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  user.signature!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (user?.isVip ?? false) _buildBadge('VIP', Colors.amber),
                if (user?.isPurple ?? false) _buildBadge('紫名', Colors.purple),
                if (user?.isMerchant ?? false) _buildBadge('商家', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.white,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 32,
          color: Color(0xFF6B4EFF),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, User? user) {
    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('主题', '${user?.postCount ?? 0}'),
            _buildStatItem('帖子', '${user?.replyCount ?? 0}'),
            _buildStatItem('收藏', '${user?.favoriteCount ?? 0}'),
            _buildStatItem('关注', '${user?.followCount ?? 0}'),
            _buildStatItem('粉丝', '${user?.fanCount ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        _buildMenuItem(
          context,
          icon: Icons.article,
          title: '我的帖子',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MyPostScreen(),
              ),
            );
          },
        ),
        _buildMenuItem(
          context,
          icon: Icons.bookmark,
          title: '我的收藏',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FavoriteScreen(),
              ),
            );
          },
        ),
        _buildMenuItem(
          context,
          icon: Icons.history,
          title: '浏览历史',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HistoryScreen(),
              ),
            );
          },
        ),
        const Divider(),
        _buildMenuItem(
          context,
          icon: Icons.dark_mode,
          title: '深色模式',
          trailing: Consumer<ThemeProvider>(
            builder: (context, theme, _) {
              return Switch(
                value: theme.themeMode == ThemeMode.dark,
                onChanged: (value) => theme.toggleTheme(),
              );
            },
          ),
        ),
        _buildMenuItem(
          context,
          icon: Icons.language,
          title: '网页版',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WebViewScreen(
                  url: 'https://dalao.net',
                  title: '大佬论坛',
                ),
              ),
            );
          },
        ),
        _buildMenuItem(
          context,
          icon: Icons.settings,
          title: '设置',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            );
          },
        ),
        _buildMenuItem(
          context,
          icon: Icons.info,
          title: '关于',
          onTap: () => _showAboutDialog(context),
        ),
        const Divider(),
        _buildMenuItem(
          context,
          icon: Icons.logout,
          title: '退出登录',
          textColor: Colors.red,
          onTap: () => _confirmLogout(context),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo/图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 应用名称
              const Text(
                '大佬论坛',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // 版本号
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v$_version',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 描述
              Text(
                '站长论坛，互联网站长综合交流平台',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // 信息列表
              _buildInfoRow(
                context,
                Icons.language,
                '官网',
                'dalao.net',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.telegram,
                '电报群',
                '@dalaonet',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.code,
                '开源协议',
                'MIT License',
              ),
              const SizedBox(height: 24),

              // 按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
