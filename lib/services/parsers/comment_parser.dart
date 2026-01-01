import 'package:flutter/foundation.dart';
import '../../models/comment.dart';

/// 评论解析器 - 使用正则表达式解析 dalao.net 的评论列表
class CommentParser {
  static const String _baseUrl = 'https://www.dalao.net';

  /// 从 HTML 解析评论列表
  static List<Comment> parse(String html, int postId) {
    final comments = <Comment>[];

    try {
      // 匹配 <li class="media post" data-pid="xxx" data-uid="xxx">
      final liPattern = RegExp(
        r'<li\s+class="media\s+post"\s+data-pid="(\d+)"\s+data-uid="(\d+)">',
        caseSensitive: false,
      );
      final matches = liPattern.allMatches(html).toList();

      debugPrint('CommentParser: 找到 ${matches.length} 个评论');

      for (final match in matches) {
        final pid = int.tryParse(match.group(1) ?? '') ?? 0;
        final uid = int.tryParse(match.group(2) ?? '') ?? 0;
        if (pid == 0) continue;

        // 找到这个评论块的起始位置
        final startIdx = match.start;

        // 查找下一个评论 li 或 </ul> 作为边界
        final nextMatch = liPattern.firstMatch(html.substring(match.end));
        final ulEndIdx = html.indexOf('</ul>', match.end);

        int endIdx;
        if (nextMatch != null &&
            (ulEndIdx == -1 || match.end + nextMatch.start < ulEndIdx)) {
          endIdx = match.end + nextMatch.start;
        } else if (ulEndIdx != -1) {
          endIdx = ulEndIdx;
        } else {
          endIdx = (match.end + 5000).clamp(0, html.length);
        }

        final block = html.substring(startIdx, endIdx);

        final comment = _parseCommentBlock(block, pid, uid, postId);
        if (comment != null) {
          comments.add(comment);
        }
      }
    } catch (e) {
      debugPrint('CommentParser: 解析失败 - $e');
    }

    debugPrint('CommentParser: 成功解析 ${comments.length} 条评论');
    return comments;
  }

  /// 解析单个评论块
  static Comment? _parseCommentBlock(
      String block, int pid, int uid, int postId) {
    try {
      // 解析用户名
      final authorName = _extractAuthorName(block);

      // 解析头像
      final authorAvatar = _extractAvatar(block);

      // 解析评论内容
      final content = _extractContent(block);
      if (content.isEmpty) return null;

      // 解析时间
      final createdAt = _extractTime(block);

      // 检查是否是楼主
      final isOp = block.contains('haya-post-info-first-floor');

      // 解析 @回复
      final (replyToName, replyToId) = _extractReplyTo(block);

      return Comment(
        id: pid,
        postId: postId,
        content: content,
        authorName: authorName,
        authorAvatar: authorAvatar,
        authorId: uid,
        createdAt: createdAt,
        isPinned: isOp,
        replyToId: replyToId,
        replyToName: replyToName,
      );
    } catch (e) {
      debugPrint('CommentParser: 解析评论块失败 pid=$pid - $e');
      return null;
    }
  }

  /// 提取用户名
  static String _extractAuthorName(String block) {
    // 匹配: font-weight-bold"...>用户名</a>
    final pattern = RegExp(r'font-weight-bold"[^>]*>([^<]+)</a>');
    final match = pattern.firstMatch(block);
    if (match != null) {
      String name = match.group(1) ?? '';
      // 处理带颜色的用户名 <span style="color:...">用户名</span>
      if (name.contains('<span')) {
        final spanPattern = RegExp(r'>([^<]+)</span>');
        final spanMatch = spanPattern.firstMatch(name);
        if (spanMatch != null) {
          name = spanMatch.group(1) ?? '';
        }
      }
      name = name.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (name.isNotEmpty) return name;
    }

    // 备选: 匹配带 span 的用户名
    final colorPattern =
        RegExp(r'font-weight-bold"[^>]*><span[^>]*>([^<]+)</span></a>');
    final colorMatch = colorPattern.firstMatch(block);
    if (colorMatch != null) {
      return colorMatch.group(1)?.trim() ?? '匿名';
    }

    return '匿名';
  }

  /// 提取头像
  static String _extractAvatar(String block) {
    final pattern = RegExp(r'<img\s+class="avatar-3"\s+src="([^"]*)"');
    final match = pattern.firstMatch(block);
    if (match != null) {
      return _fixUrl(match.group(1) ?? '');
    }
    return '';
  }

  /// 提取评论内容
  static String _extractContent(String block) {
    // 匹配: <div class="message mt-1 break-all"...>内容</div>
    final pattern = RegExp(
      r'<div\s+class="message\s+mt-1\s+break-all"[^>]*>(.*?)</div>\s*<div\s+class="positon">',
      dotAll: true,
    );
    final match = pattern.firstMatch(block);
    if (match != null) {
      String content = match.group(1)?.trim() ?? '';
      content = _fixImageUrls(content);
      return content;
    }

    // 备选: 不带 positon 的匹配
    final altPattern = RegExp(
      r'<div\s+class="message\s+mt-1\s+break-all"[^>]*>(.*?)</div>',
      dotAll: true,
    );
    final altMatch = altPattern.firstMatch(block);
    if (altMatch != null) {
      String content = altMatch.group(1)?.trim() ?? '';
      content = _fixImageUrls(content);
      return content;
    }

    return '';
  }

  /// 提取时间
  static DateTime _extractTime(String block) {
    // 匹配 datetime 属性
    final pattern = RegExp(r'datetime="([^"]+)"');
    final match = pattern.firstMatch(block);
    if (match != null) {
      final datetime = match.group(1) ?? '';
      final parsed = DateTime.tryParse(datetime);
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }

  /// 提取 @回复
  static (String?, int?) _extractReplyTo(String block) {
    // 匹配: haya-post-info-at...href="user-xxx.htm"...<em>@用户名</em>
    final pattern = RegExp(
        r'haya-post-info-at[^>]*href="user-(\d+)\.htm"[^>]*><em>@([^<]+)</em>');
    final match = pattern.firstMatch(block);
    if (match != null) {
      final uid = int.tryParse(match.group(1) ?? '');
      final name = match.group(2)?.trim();
      return (name, uid);
    }

    // 备选: 只匹配 @用户名
    final altPattern = RegExp(r'<em>@([^<]+)</em>');
    final altMatch = altPattern.firstMatch(block);
    if (altMatch != null) {
      return (altMatch.group(1)?.trim(), null);
    }

    return (null, null);
  }

  /// 修复图片 URL
  static String _fixImageUrls(String content) {
    return content.replaceAllMapped(
      RegExp(r'src="([^"]*)"'),
      (match) {
        String url = match.group(1) ?? '';
        url = _fixUrl(url);
        return 'src="$url"';
      },
    );
  }

  /// 修复 URL
  static String _fixUrl(String url) {
    if (url.isEmpty) return '';
    url = url.replaceAll(r'\/', '/');
    if (!url.startsWith('http') && !url.startsWith('data:')) {
      if (url.startsWith('/')) {
        url = '$_baseUrl$url';
      } else {
        url = '$_baseUrl/$url';
      }
    }
    return url;
  }
}
