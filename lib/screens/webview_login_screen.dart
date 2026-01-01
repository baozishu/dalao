import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// WebView 登录页面
class WebViewLoginScreen extends StatefulWidget {
  const WebViewLoginScreen({super.key});

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() => _progress = progress / 100);
          },
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) async {
            setState(() => _isLoading = false);
            await _checkLoginStatus();
          },
          onUrlChange: (change) {
            setState(() => _currentUrl = change.url ?? '');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://dalao.net/login.htm'));
  }

  Future<void> _checkLoginStatus() async {
    try {
      final cookies =
          await _controller.runJavaScriptReturningResult('document.cookie');
      final cookieStr = cookies.toString().replaceAll('"', '');

      if (cookieStr.isNotEmpty &&
          cookieStr != 'null' &&
          !_currentUrl.contains('login')) {
        await _onLoginSuccess(cookieStr);
      }
    } catch (e) {
      debugPrint('获取 Cookie 失败: $e');
    }
  }

  Future<void> _onLoginSuccess(String cookies) async {
    final api = ApiService();
    await api.setCookies(cookies);

    if (mounted) {
      final auth = context.read<AuthProvider>();
      auth.setLoggedInWithCookie();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功！'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录大佬论坛'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '完成登录',
            onPressed: _manualCheckLogin,
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '请在下方网页中登录，登录成功后点击右上角 ✓ 完成',
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }

  void _manualCheckLogin() async {
    try {
      final cookies =
          await _controller.runJavaScriptReturningResult('document.cookie');
      final cookieStr = cookies.toString().replaceAll('"', '');

      if (cookieStr.isNotEmpty && cookieStr != 'null') {
        await _onLoginSuccess(cookieStr);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('请先在网页中完成登录'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('获取登录状态失败: $e')));
      }
    }
  }
}
