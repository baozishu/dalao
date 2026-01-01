import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'webview_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '加载中...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSection(
            context,
            title: '账号设置',
            items: [
              _SettingItem(
                icon: Icons.lock_outline,
                title: '修改密码',
                subtitle: '修改登录密码',
                onTap: () => _openWebView(
                  context,
                  'https://www.dalao.net/my-password.htm',
                  '修改密码',
                ),
              ),
              _SettingItem(
                icon: Icons.email_outlined,
                title: '邮箱设置',
                subtitle: '绑定或修改邮箱',
                onTap: () => _openWebView(
                  context,
                  'https://www.dalao.net/my-email.htm',
                  '邮箱设置',
                ),
              ),
              _SettingItem(
                icon: Icons.edit_outlined,
                title: '修改用户名',
                subtitle: '修改显示的用户名',
                onTap: () => _openWebView(
                  context,
                  'https://www.dalao.net/my-rename.htm',
                  '修改用户名',
                ),
              ),
              _SettingItem(
                icon: Icons.format_quote,
                title: '个性尾巴',
                subtitle: '设置个性签名',
                onTap: () => _openWebView(
                  context,
                  'https://www.dalao.net/my-signature.htm',
                  '个性尾巴',
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildSection(
            context,
            title: '其他设置',
            items: [
              _SettingItem(
                icon: Icons.info_outline,
                title: '关于',
                subtitle: '版本信息',
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<_SettingItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...items.map((item) => _buildSettingItem(context, item)),
      ],
    );
  }

  Widget _buildSettingItem(BuildContext context, _SettingItem item) {
    return ListTile(
      leading: Icon(item.icon),
      title: Text(item.title),
      subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: item.onTap,
    );
  }

  void _openWebView(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(url: url, title: title),
      ),
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
                      color: Colors.black.withOpacity(0.1),
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
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _SettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
