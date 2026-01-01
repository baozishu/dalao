class Comment {
  final int id;
  final int postId;
  final String content;
  final String authorName;
  final String authorAvatar;
  final int authorId;
  final DateTime createdAt;
  final bool isPinned;
  final int? replyToId;
  final String? replyToName;

  Comment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorName,
    required this.authorAvatar,
    required this.authorId,
    required this.createdAt,
    this.isPinned = false,
    this.replyToId,
    this.replyToName,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? json['postId'] ?? 0,
      content: json['content'] ?? '',
      authorName: json['author_name'] ?? json['authorName'] ?? '',
      authorAvatar: json['author_avatar'] ?? json['authorAvatar'] ?? '',
      authorId: json['author_id'] ?? json['authorId'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
      replyToId: json['reply_to_id'] ?? json['replyToId'],
      replyToName: json['reply_to_name'] ?? json['replyToName'],
    );
  }
}
