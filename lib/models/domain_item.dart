/// 域名市场项目模型
class DomainItem {
  final int id;
  final String domain; // 域名
  final String suffix; // 后缀 (如 .com, .net)
  final int length; // 前缀长度
  final double? price; // 价格 (null 表示询价)
  final bool isInquiry; // 是否询价
  final String? description; // 描述
  final String publisherName; // 发布人名称
  final int publisherId; // 发布人ID
  final String publisherAvatar; // 发布人头像
  final bool isVerified; // 是否已验证
  final DateTime? verifiedAt; // 验证时间
  final DateTime createdAt; // 发布时间

  DomainItem({
    required this.id,
    required this.domain,
    required this.suffix,
    required this.length,
    this.price,
    this.isInquiry = false,
    this.description,
    required this.publisherName,
    required this.publisherId,
    this.publisherAvatar = '',
    this.isVerified = false,
    this.verifiedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 获取格式化的价格显示
  String get priceDisplay {
    if (isInquiry || price == null) return '询价';
    return '￥${price!.toStringAsFixed(0)}';
  }

  /// 获取域名前缀
  String get prefix {
    final dotIndex = domain.indexOf('.');
    return dotIndex > 0 ? domain.substring(0, dotIndex) : domain;
  }
}
