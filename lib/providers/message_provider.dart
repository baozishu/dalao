import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'dart:async';

class MessageProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  int _unreadCount = 0;
  Timer? _timer;

  int get unreadCount => _unreadCount;

  /// 开始定时检查未读消息
  void startPolling() {
    // 立即检查一次
    checkUnreadMessages();

    // 每30秒检查一次
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkUnreadMessages();
    });
  }

  /// 停止定时检查
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// 检查未读消息数量
  Future<void> checkUnreadMessages() async {
    try {
      // 获取评论我的消息（type=2）
      final notices = await _api.getNotices(type: 2, page: 1);

      // 这里简单统计所有消息数量
      // 实际应该从HTML中解析未读数量
      final newCount = notices.length;

      if (_unreadCount != newCount) {
        _unreadCount = newCount;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('检查未读消息失败: $e');
    }
  }

  /// 标记消息已读
  void markAsRead() {
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
