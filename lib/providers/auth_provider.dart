import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoggedIn = false;
  bool _isLoading = true; // 初始为 true，表示正在检查登录状态
  bool _isInitialized = false;
  final ApiService _api = ApiService();

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    await _api.init();
    await _checkLoginStatus();

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _checkLoginStatus() async {
    // 检查是否有保存的 Cookie
    if (_api.hasCookies) {
      debugPrint('发现已保存的 Cookie，验证登录状态...');
      // 验证 Cookie 是否有效
      final isValid = await _api.checkLoginStatus();
      if (isValid) {
        debugPrint('Cookie 有效，自动登录成功');
        _isLoggedIn = true;
        // 获取用户信息
        await _fetchUserInfo();
        return;
      } else {
        debugPrint('Cookie 已失效');
      }
    }

    // 兼容旧的 token 方式
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      _isLoggedIn = true;
    }
  }

  /// 获取用户信息
  Future<void> _fetchUserInfo() async {
    try {
      final user = await _api.getCurrentUser();
      if (user != null) {
        _user = user;
        debugPrint('获取用户信息成功: ${user.nickname}, 头像: ${user.avatar}');
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
    }
  }

  /// WebView 登录成功后调用
  Future<void> setLoggedInWithCookie() async {
    _isLoggedIn = true;
    await _fetchUserInfo();
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.post('/api/login', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(
      String username, String email, String password, String inviteCode) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.post('/api/register', data: {
        'username': username,
        'email': email,
        'password': password,
        'invite_code': inviteCode,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Register error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _api.clearCookies();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');

    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  void setUser(User user) {
    _user = user;
    _isLoggedIn = true;
    notifyListeners();
  }
}
