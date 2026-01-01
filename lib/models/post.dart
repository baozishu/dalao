class Post {
  final int id;
  final String title;
  final String content;
  final String authorName;
  final String authorAvatar;
  final int authorId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int viewCount;
  final int replyCount;
  final String category;
  final bool isPinned;
  final bool isLocked;
  final bool isPrivate;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    this.authorAvatar = '',
    this.authorId = 0,
    required this.createdAt,
    this.updatedAt,
    this.viewCount = 0,
    this.replyCount = 0,
    this.category = '',
    this.isPinned = false,
    this.isLocked = false,
    this.isPrivate = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorName: json['author_name'] ?? json['authorName'] ?? '',
      authorAvatar: json['author_avatar'] ?? json['authorAvatar'] ?? '',
      authorId: json['author_id'] ?? json['authorId'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      viewCount: json['view_count'] ?? json['viewCount'] ?? 0,
      replyCount: json['reply_count'] ?? json['replyCount'] ?? 0,
      category: json['category'] ?? '',
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
      isLocked: json['is_locked'] ?? json['isLocked'] ?? false,
      isPrivate: json['is_private'] ?? json['isPrivate'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'author_id': authorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'view_count': viewCount,
      'reply_count': replyCount,
      'category': category,
      'is_pinned': isPinned,
      'is_locked': isLocked,
      'is_private': isPrivate,
    };
  }
}
