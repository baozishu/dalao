import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'cookie_manager.dart';
import 'html_parser.dart';
import 'parsers/comment_parser.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/notice.dart';
import '../models/merchant.dart';
import '../models/moyu_item.dart';
import '../models/domain_item.dart';
import '../models/user.dart';

class ApiService {
  static const String baseUrl = 'https://www.dalao.net';
  static final ApiService _instance = ApiService._internal();
  late Dio _dio;
  final CookieManager _cookieManager = CookieManager();

  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
      },
      responseType: ResponseType.plain,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 添加 Cookie
        if (_cookieManager.hasCookies) {
          options.headers['Cookie'] = _cookieManager.getCookieHeader();
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  /// 初始化 - 加载保存的 Cookie
  Future<void> init() async {
    await _cookieManager.loadCookies();
  }

  /// 设置 Cookie (从 WebView 登录后调用)
  Future<void> setCookies(String cookies) async {
    await _cookieManager.saveCookies(cookies);
  }

  /// 清除 Cookie
  Future<void> clearCookies() async {
    await _cookieManager.clearCookies();
  }

  /// 检查是否有有效的 Cookie
  bool get hasCookies => _cookieManager.hasCookies;

  /// 获取原始 HTML 页面
  Future<String> fetchPage(String path) async {
    final response = await _dio.get(path);
    return response.data.toString();
  }

  /// 获取帖子列表 (AJAX 接口)
  Future<List<Post>> getPostList({int page = 1, String? category}) async {
    String path = category ?? '/index.htm';

    // 处理分页
    if (page > 1) {
      // URL 格式: index-{page}-{type}.htm
      if (path == '/index.htm') {
        path = '/index-$page.htm';
      } else if (path.contains('index-1-')) {
        path = path.replaceFirst('index-1-', 'index-$page-');
      } else if (path.contains('domain-market')) {
        path = path.replaceFirst('.htm', '-$page.htm');
      }
    }

    // 添加 ajax=1 参数获取 JSON 数据
    final separator = path.contains('?') ? '&' : '?';
    path = '$path${separator}ajax=1';

    debugPrint('获取帖子列表: $path');
    final response = await _dio.get(path);
    debugPrint('响应长度: ${response.data.toString().length}');
    return HtmlParser.parsePostListFromJson(response.data.toString());
  }

  /// 获取帖子详情
  Future<Post?> getPostDetail(int postId) async {
    final html = await fetchPage('/thread-$postId.htm');
    return HtmlParser.parsePostDetail(html, postId);
  }

  /// 获取帖子评论
  Future<List<Comment>> getComments(int postId, {int page = 1}) async {
    String path = '/thread-$postId-$page.htm';
    final html = await fetchPage(path);
    return CommentParser.parse(html, postId);
  }

  /// 发送评论/回复
  /// [postId] 帖子ID
  /// [content] 评论内容
  /// [replyPid] 回复的评论ID（可选，回复楼主时不传）
  /// [replyUserName] 回复的用户名（可选）
  Future<bool> postComment(int postId, String content,
      {int? replyPid, String? replyUserName}) async {
    try {
      // 如果是回复某楼层，在内容前加上 @用户名
      String finalContent = content;
      if (replyUserName != null && replyUserName.isNotEmpty) {
        finalContent = '@$replyUserName $content';
      }

      // dalao.net 的评论提交接口
      final formData = {
        'message': finalContent,
      };

      // 如果是回复某个评论，添加 pid 参数
      if (replyPid != null) {
        formData['pid'] = replyPid.toString();
      }

      final response = await _dio.post(
        '/post-create-$postId.htm',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': '$baseUrl/thread-$postId.htm',
          },
        ),
      );

      // 检查响应
      final responseText = response.data.toString();
      debugPrint('评论响应: $responseText');

      // 成功时通常会返回 JSON 或重定向
      return !responseText.contains('error') &&
          !responseText.contains('登录') &&
          !responseText.contains('login');
    } catch (e) {
      debugPrint('发送评论失败: $e');
      return false;
    }
  }

  /// 检查登录状态
  Future<bool> checkLoginStatus() async {
    if (!_cookieManager.hasCookies) return false;

    try {
      final html = await fetchPage('/');
      return HtmlParser.isLoggedIn(html);
    } catch (e) {
      return false;
    }
  }

  /// 获取当前登录用户信息
  Future<User?> getCurrentUser() async {
    try {
      final html = await fetchPage('/');
      return HtmlParser.parseCurrentUser(html);
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
      return null;
    }
  }

  /// 获取完整用户资料（包含统计数据）
  Future<User?> getMyProfile() async {
    try {
      final html = await fetchPage('/my.htm');
      return HtmlParser.parseMyProfile(html);
    } catch (e) {
      debugPrint('获取用户资料失败: $e');
      return null;
    }
  }

  /// 原始 HTTP 请求方法 (保留兼容性)
  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    return await _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  /// 获取消息通知列表
  /// [type] 消息类型: 7=私信, 2=评论我的, 156=提及我的, 3=系统通知
  Future<List<Notice>> getNotices({int type = 2, int page = 1}) async {
    String path = '/my-notice-$type.htm';
    if (page > 1) {
      path = '/my-notice-$type-$page.htm';
    }

    debugPrint('获取消息: path=$path, hasCookies=${_cookieManager.hasCookies}');
    final html = await fetchPage(path);
    debugPrint('获取到 HTML 长度: ${html.length}');

    // 检查是否被重定向到登录页面
    if (html.contains('login.htm') || html.contains('请先登录')) {
      debugPrint('需要登录才能查看消息');
      return [];
    }

    return HtmlParser.parseNotices(html, type);
  }

  /// 获取商家列表
  Future<List<Merchant>> getMerchants() async {
    final html = await fetchPage('/provider.htm');
    debugPrint('获取商家页面 HTML 长度: ${html.length}');
    return HtmlParser.parseMerchants(html);
  }

  /// 获取摸鱼 RSS 聚合列表
  Future<List<MoyuItem>> getMoyuList({int page = 1}) async {
    String path = '/index-$page-2.htm';
    debugPrint('获取摸鱼列表: $path');
    final html = await fetchPage(path);
    debugPrint('获取摸鱼页面 HTML 长度: ${html.length}');
    return HtmlParser.parseMoyuList(html);
  }

  /// 搜索帖子
  /// [keyword] 关键词
  /// [range] 搜索范围: 1=标题, 0=内容, 3=用户
  Future<List<Post>> search(String keyword, {int range = 1}) async {
    final encodedKeyword = Uri.encodeComponent(keyword);
    final path = '/search-$encodedKeyword-$range-0.htm';
    debugPrint('搜索: $path');
    final html = await fetchPage(path);
    return HtmlParser.parseSearchResults(html);
  }

  /// 发布新帖子
  /// [fid] 版块ID: 1=大佬论坛
  /// [subject] 标题
  /// [message] 内容
  Future<Map<String, dynamic>> createPost({
    int fid = 1,
    required String subject,
    required String message,
  }) async {
    try {
      // 先获取发帖页面获取 sid
      final createPageHtml = await fetchPage('/thread-create-0.htm');
      final sid = HtmlParser.extractSid(createPageHtml);

      if (sid == null) {
        return {'success': false, 'message': '获取会话ID失败，请重新登录'};
      }

      final formData = {
        'fid': fid.toString(),
        'subject': subject,
        'message': message,
        'doctype': '0', // 0=普通文本, 1=富文本
        'quotepid': '0',
        'sid': sid,
        'readperm': '102', // 公开可见
      };

      final response = await _dio.post(
        '/thread-create.htm',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': '$baseUrl/thread-create-0.htm',
          },
        ),
      );

      final responseText = response.data.toString();
      debugPrint('发帖响应: $responseText');

      // 解析响应
      return HtmlParser.parseCreatePostResponse(responseText);
    } catch (e) {
      debugPrint('发帖失败: $e');
      return {'success': false, 'message': '发帖失败: $e'};
    }
  }

  /// 获取域名市场列表
  /// [page] 页码
  /// [priceType] 价格类型: '' = 全部, 'fixed' = 一口价, 'inquiry' = 询价
  /// [suffix] 后缀筛选 (如 'com', 'net')
  /// [keyword] 搜索关键词
  Future<List<DomainItem>> getDomainMarket({
    int page = 1,
    String priceType = '',
    String? suffix,
    String? keyword,
  }) async {
    String path = '/domain-market.htm';
    if (page > 1) {
      path = '/domain-market-page-$page.htm';
    }

    // 构建查询参数
    final params = <String, String>{};
    if (priceType.isNotEmpty) {
      params['price_type'] = priceType;
    }
    if (suffix != null && suffix.isNotEmpty) {
      params['suffix'] = suffix;
    }
    if (keyword != null && keyword.isNotEmpty) {
      params['keyword'] = keyword;
      params['prefix'] = keyword;
    }

    if (params.isNotEmpty) {
      path +=
          '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    }

    debugPrint('获取域名市场: $path');
    final html = await fetchPage(path);
    debugPrint('获取域名市场 HTML 长度: ${html.length}');
    return HtmlParser.parseDomainMarket(html);
  }

  /// 获取我的收藏列表
  Future<List<Post>> getFavorites({int page = 1}) async {
    String path = '/my-favorite.htm';
    if (page > 1) {
      path = '/my-favorite-$page.htm';
    }

    debugPrint('获取收藏列表: $path');
    final html = await fetchPage(path);
    debugPrint('获取收藏 HTML 长度: ${html.length}');

    // 检查是否需要登录
    if (html.contains('login.htm') || html.contains('请先登录')) {
      debugPrint('需要登录才能查看收藏');
      return [];
    }

    // 检查HTML结构
    debugPrint('收藏页面包含threadlist: ${html.contains('threadlist')}');
    debugPrint(
        '收藏页面包含li.media.thread: ${html.contains('li class="media thread')}');
    debugPrint('收藏页面包含data-tid: ${html.contains('data-tid')}');

    final posts = HtmlParser.parsePostList(html);
    debugPrint('收藏页面解析到 ${posts.length} 个帖子');
    return posts;
  }

  /// 获取我的帖子列表
  Future<List<Post>> getMyPosts({int page = 1}) async {
    String path = '/my-post.htm';
    if (page > 1) {
      path = '/my-post-$page.htm';
    }

    debugPrint('获取我的帖子: $path');
    final html = await fetchPage(path);
    debugPrint('获取我的帖子 HTML 长度: ${html.length}');

    // 检查是否需要登录
    if (html.contains('login.htm') || html.contains('请先登录')) {
      debugPrint('需要登录才能查看我的帖子');
      return [];
    }

    final posts = HtmlParser.parsePostList(html);
    debugPrint('我的帖子页面解析到 ${posts.length} 个帖子');
    return posts;
  }
}
