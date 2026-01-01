import 'package:shared_preferences/shared_preferences.dart';

/// Cookie 管理器 - 用于存储和管理从 WebView 获取的 Cookie
class CookieManager {
  static const String _cookieKey = 'dalao_cookies';
  static final CookieManager _instance = CookieManager._internal();

  factory CookieManager() => _instance;
  CookieManager._internal();

  String? _cookies;

  String? get cookies => _cookies;
  bool get hasCookies => _cookies != null && _cookies!.isNotEmpty;

  /// 从本地存储加载 Cookie
  Future<void> loadCookies() async {
    final prefs = await SharedPreferences.getInstance();
    _cookies = prefs.getString(_cookieKey);
  }

  /// 保存 Cookie 到本地存储
  Future<void> saveCookies(String cookies) async {
    _cookies = cookies;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cookieKey, cookies);
  }

  /// 清除 Cookie
  Future<void> clearCookies() async {
    _cookies = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookieKey);
  }

  /// 获取 Cookie 头部字符串
  String getCookieHeader() {
    return _cookies ?? '';
  }
}
