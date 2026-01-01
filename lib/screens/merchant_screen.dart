import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/merchant.dart';
import '../services/api_service.dart';

class MerchantScreen extends StatefulWidget {
  const MerchantScreen({super.key});

  @override
  State<MerchantScreen> createState() => _MerchantScreenState();
}

class _MerchantScreenState extends State<MerchantScreen> {
  final ApiService _api = ApiService();
  List<Merchant> _merchants = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMerchants();
  }

  Future<void> _loadMerchants() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final merchants = await _api.getMerchants();
      if (mounted) {
        setState(() {
          _merchants = merchants;
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_merchants.isEmpty && _hasLoaded) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _loadMerchants,
      child: CustomScrollView(
        slivers: [
          // 头部
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFedcb78).withOpacity(0.3),
                    const Color(0xFFf7e4b2).withOpacity(0.2),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '大佬论坛商家中心',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4e3618),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${_merchants.length} 家认证商家',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 商家网格
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildMerchantCard(_merchants[index]),
                childCount: _merchants.length,
              ),
            ),
          ),
          // 底部提示
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '交易有风险，请自行甄别商家信誉',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(Merchant merchant) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showMerchantDetail(merchant),
        child: Column(
          children: [
            // Logo 区域
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: merchant.logo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: merchant.logo,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => _buildLogoPlaceholder(merchant),
                        errorWidget: (_, __, ___) =>
                            _buildLogoPlaceholder(merchant),
                      )
                    : _buildLogoPlaceholder(merchant),
              ),
            ),
            // 名称区域
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFedcb78),
                    const Color(0xFFf7e4b2),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    merchant.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF333333),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (merchant.description != null &&
                      merchant.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${merchant.description}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder(Merchant merchant) {
    return Center(
      child: Text(
        merchant.name.isNotEmpty ? merchant.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  void _showMerchantDetail(Merchant merchant) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示器
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Logo
            if (merchant.logo.isNotEmpty)
              Container(
                width: 120,
                height: 60,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CachedNetworkImage(
                  imageUrl: merchant.logo,
                  fit: BoxFit.contain,
                ),
              ),
            const SizedBox(height: 16),
            // 名称
            Text(
              merchant.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (merchant.description != null &&
                merchant.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '@${merchant.description}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            // 按钮
            Row(
              children: [
                if (merchant.website != null && merchant.website!.isNotEmpty)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openUrl(merchant.website!);
                      },
                      icon: const Icon(Icons.language, size: 18),
                      label: const Text('访问官网'),
                    ),
                  ),
                if (merchant.website != null && merchant.website!.isNotEmpty)
                  const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openUrl('https://www.dalao.net/user-${merchant.id}.htm');
                    },
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text('查看主页'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('加载失败', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadMerchants,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无商家', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadMerchants,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开: $e')),
        );
      }
    }
  }
}
