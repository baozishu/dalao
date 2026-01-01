import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/post.dart';

/// 浏览历史服务
class HistoryService {
  static const String _historyKey = 'browse_history';
  static const int _maxHistoryCount = 100; // 最多保存100条历史

  /// 添加浏览记录
  static Future<void> addHistory(Post post) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);

      List<Map<String, dynamic>> historyList = [];
      if (historyJson != null) {
        final decoded = jsonDecode(historyJson);
        if (decoded is List) {
          historyList = List<Map<String, dynamic>>.from(decoded);
        }
      }

      // 移除已存在的相同帖子
      historyList.removeWhere((item) => item['id'] == post.id);

      // 添加到列表开头
      historyList.insert(0, {
        'id': post.id,
        'title': post.title,
        'content': post.content,
        'authorName': post.authorName,
        'authorAvatar': post.authorAvatar,
        'authorId': post.authorId,
        'createdAt': post.createdAt.toIso8601String(),
        'viewCount': post.viewCount,
        'replyCount': post.replyCount,
        'category': post.category,
        'isPinned': post.isPinned,
        'browsedAt': DateTime.now().toIso8601String(),
      });

      // 限制历史记录数量
      if (historyList.length > _maxHistoryCount) {
        historyList = historyList.sublist(0, _maxHistoryCount);
      }

      // 保存
      await prefs.setString(_historyKey, jsonEncode(historyList));
    } catch (e) {
      print('保存浏览历史失败: $e');
    }
  }

  /// 获取浏览历史
  static Future<List<Post>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);

      if (historyJson == null) return [];

      final decoded = jsonDecode(historyJson);
      if (decoded is! List) return [];

      final historyList = List<Map<String, dynamic>>.from(decoded);

      return historyList.map((item) {
        return Post(
          id: item['id'] ?? 0,
          title: item['title'] ?? '',
          content: item['content'] ?? '',
          authorName: item['authorName'] ?? '',
          authorAvatar: item['authorAvatar'] ?? '',
          authorId: item['authorId'] ?? 0,
          createdAt: DateTime.parse(
              item['createdAt'] ?? DateTime.now().toIso8601String()),
          viewCount: item['viewCount'] ?? 0,
          replyCount: item['replyCount'] ?? 0,
          category: item['category'],
          isPinned: item['isPinned'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('读取浏览历史失败: $e');
      return [];
    }
  }

  /// 清空浏览历史
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      print('清空浏览历史失败: $e');
    }
  }

  /// 删除单条历史记录
  static Future<void> removeHistory(int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);

      if (historyJson == null) return;

      final decoded = jsonDecode(historyJson);
      if (decoded is! List) return;

      List<Map<String, dynamic>> historyList =
          List<Map<String, dynamic>>.from(decoded);
      historyList.removeWhere((item) => item['id'] == postId);

      await prefs.setString(_historyKey, jsonEncode(historyList));
    } catch (e) {
      print('删除浏览历史失败: $e');
    }
  }
}
