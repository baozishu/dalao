class User {
  final int id;
  final String username;
  final String nickname;
  final String email;
  final String avatar;
  final String? backgroundImage;
  final String? signature;
  final bool isVip;
  final bool isPurple;
  final bool isMerchant;
  final DateTime? createdAt;
  final int postCount;
  final int replyCount;
  final int favoriteCount;
  final int followCount;
  final int fanCount;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.email,
    required this.avatar,
    this.backgroundImage,
    this.signature,
    this.isVip = false,
    this.isPurple = false,
    this.isMerchant = false,
    this.createdAt,
    this.postCount = 0,
    this.replyCount = 0,
    this.favoriteCount = 0,
    this.followCount = 0,
    this.fanCount = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? json['username'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'] ?? '',
      backgroundImage: json['background_image'] ?? json['backgroundImage'],
      signature: json['signature'],
      isVip: json['is_vip'] ?? json['isVip'] ?? false,
      isPurple: json['is_purple'] ?? json['isPurple'] ?? false,
      isMerchant: json['is_merchant'] ?? json['isMerchant'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      postCount: json['post_count'] ?? json['postCount'] ?? 0,
      replyCount: json['reply_count'] ?? json['replyCount'] ?? 0,
      favoriteCount: json['favorite_count'] ?? json['favoriteCount'] ?? 0,
      followCount: json['follow_count'] ?? json['followCount'] ?? 0,
      fanCount: json['fan_count'] ?? json['fanCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'email': email,
      'avatar': avatar,
      'background_image': backgroundImage,
      'signature': signature,
      'is_vip': isVip,
      'is_purple': isPurple,
      'is_merchant': isMerchant,
      'created_at': createdAt?.toIso8601String(),
      'post_count': postCount,
      'reply_count': replyCount,
      'favorite_count': favoriteCount,
      'follow_count': followCount,
      'fan_count': fanCount,
    };
  }
}
