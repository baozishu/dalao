import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (post.isPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '置顶',
                        style: TextStyle(color: Colors.orange, fontSize: 10),
                      ),
                    ),
                  if (post.category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.category,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      post.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 6),
                  Text(
                    post.authorName,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.remove_red_eye, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${post.viewCount}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.comment, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${post.replyCount}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatTime(post.createdAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (post.authorAvatar.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: post.authorAvatar,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          placeholder: (context, url) => CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[300],
            child: Text(
              post.authorName.isNotEmpty ? post.authorName[0] : '?',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[300],
            child: Text(
              post.authorName.isNotEmpty ? post.authorName[0] : '?',
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 12,
      backgroundColor: Colors.grey[300],
      child: Text(
        post.authorName.isNotEmpty ? post.authorName[0] : '?',
        style: const TextStyle(fontSize: 10),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return DateFormat('MM-dd').format(time);
    }
  }
}
