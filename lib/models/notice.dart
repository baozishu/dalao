/// 消息通知模型
class Notice {
  final int id;
  final String type; // reply, at, system 等
  final String title;
  final String content;
  final String fromUserName;
  final String fromUserAvatar;
  final int fromUserId;
  final int? postId; // 关联的帖子ID
  final String? postTitle; // 关联的帖子标题
  final DateTime createdAt;
  final bool isRead;

  Notice({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.fromUserName,
    this.fromUserAvatar = '',
    this.fromUserId = 0,
    this.postId,
    this.postTitle,
    required this.createdAt,
    this.isRead = false,
  });
}
