import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' hide Comment;
import '../models/post.dart';
import '../models/comment.dart';
import '../models/user.dart';
import '../models/notice.dart';
import '../models/merchant.dart';
import '../models/moyu_item.dart';
import '../models/domain_item.dart';

/// HTML 解析器 - 用于解析 dalao.net 的 HTML 页面
class HtmlParser {
  /// 从 AJAX JSON 响应解析帖子列表
  static List<Post> parsePostListFromJson(String jsonStr) {
    try {
      debugPrint('解析帖子JSON, 长度: ${jsonStr.length}');
      final json = jsonDecode(jsonStr);

      // 检查不同的响应格式
      if (json is Map) {
        // 格式1: {success: true, threadlist: "html"}
        if (json['success'] == true && json['threadlist'] != null) {
          final htmlContent = json['threadlist'] as String;
          debugPrint('格式1: threadlist HTML 长度: ${htmlContent.length}');
          return parsePostListHtml(htmlContent);
        }

        // 格式2: {html: "html"} 或 {data: "html"}
        if (json['html'] != null) {
          final htmlContent = json['html'] as String;
          debugPrint('格式2: html 长度: ${htmlContent.length}');
          return parsePostListHtml(htmlContent);
        }

        if (json['data'] != null && json['data'] is String) {
          final htmlContent = json['data'] as String;
          debugPrint('格式3: data 长度: ${htmlContent.length}');
          return parsePostListHtml(htmlContent);
        }

        debugPrint('未知JSON格式, keys: ${json.keys}');
      }

      // 如果不是JSON，可能直接是HTML
      debugPrint('尝试直接解析为HTML');
      return parsePostListHtml(jsonStr);
    } catch (e) {
      debugPrint('解析帖子失败: $e');
      // JSON解析失败，尝试直接作为HTML解析
      return parsePostListHtml(jsonStr);
    }
  }

  /// 解析帖子列表 HTML 片段
  static List<Post> parsePostListHtml(String htmlContent) {
    final document = html_parser.parseFragment(htmlContent);
    final posts = <Post>[];

    // 尝试多种选择器
    var postElements = document.querySelectorAll('li.media.thread');
    debugPrint('选择器1 (li.media.thread): ${postElements.length} 个');

    if (postElements.isEmpty) {
      postElements = document.querySelectorAll('.thread');
      debugPrint('选择器2 (.thread): ${postElements.length} 个');
    }

    if (postElements.isEmpty) {
      postElements = document.querySelectorAll('li.media');
      debugPrint('选择器3 (li.media): ${postElements.length} 个');
    }

    if (postElements.isEmpty) {
      postElements = document.querySelectorAll('[data-tid]');
      debugPrint('选择器4 ([data-tid]): ${postElements.length} 个');
    }

    for (var element in postElements) {
      try {
        final post = _parseThreadElement(element);
        if (post != null) {
          posts.add(post);
        }
      } catch (e) {
        debugPrint('解析帖子元素失败: $e');
      }
    }

    debugPrint('最终解析到 ${posts.length} 个帖子');
    return posts;
  }

  /// 解析单个帖子元素 (新格式)
  static Post? _parseThreadElement(Element element) {
    // 从 data-tid 获取帖子 ID
    final tidStr = element.attributes['data-tid'] ?? '';
    final id = int.tryParse(tidStr) ?? 0;

    if (id == 0) {
      debugPrint('帖子ID为0, data-tid=$tidStr, 元素属性: ${element.attributes}');
      // 尝试从链接中提取ID
      final linkElement = element.querySelector('a[href*="thread-"]');
      if (linkElement != null) {
        final href = linkElement.attributes['href'] ?? '';
        final match = RegExp(r'thread-(\d+)').firstMatch(href);
        if (match != null) {
          final extractedId = int.tryParse(match.group(1)!) ?? 0;
          if (extractedId > 0) {
            debugPrint('从链接提取到ID: $extractedId');
            return _parseThreadElementWithId(element, extractedId);
          }
        }
      }
      return null;
    }

    return _parseThreadElementWithId(element, id);
  }

  static Post? _parseThreadElementWithId(Element element, int id) {
    // 获取标题
    final titleElement = element.querySelector('.subject a');
    final title = titleElement?.text.trim() ?? '';
    if (title.isEmpty) {
      debugPrint('帖子标题为空, id=$id');
      return null;
    }

    // 获取作者信息
    final authorElement = element.querySelector('.username');
    String authorName = authorElement?.text.trim() ?? '匿名';

    // 获取作者 UID
    final uidStr = authorElement?.attributes['uid'] ?? '0';
    final authorId = int.tryParse(uidStr) ?? 0;

    // 获取作者头像
    final avatarElement = element.querySelector('img.avatar-3');
    String authorAvatar = avatarElement?.attributes['src'] ?? '';
    authorAvatar = _fixImageUrl(authorAvatar);

    // 获取时间
    final timeElement = element.querySelector('.date');
    final timeText = timeElement?.text.trim() ?? '';
    final createdAt = _parseTime(timeText);

    // 获取浏览数
    final viewElement = element.querySelector('.icon-eye')?.parent;
    final viewText = viewElement?.text.trim() ?? '0';
    final viewCount =
        int.tryParse(viewText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

    // 获取回复数 (最后一个 span 里的数字)
    final replyElements = element.querySelectorAll('.text-muted span');
    int replyCount = 0;
    for (var span in replyElements) {
      final style = span.attributes['style'] ?? '';
      if (style.contains('background')) {
        replyCount = int.tryParse(span.text.trim()) ?? 0;
        break;
      }
    }

    // 检查是否置顶
    final isPinned = element.classes.contains('top_3') ||
        element.querySelector('.icon-top-3') != null;

    return Post(
      id: id,
      title: title,
      content: '',
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorId: authorId,
      createdAt: createdAt,
      viewCount: viewCount,
      replyCount: replyCount,
      isPinned: isPinned,
    );
  }

  /// 修复图片 URL
  static String _fixImageUrl(String url) {
    if (url.isEmpty) return '';

    // 处理转义字符
    url = url.replaceAll(r'\/', '/');

    // 补全相对路径
    if (!url.startsWith('http')) {
      if (url.startsWith('/')) {
        url = 'https://www.dalao.net$url';
      } else {
        url = 'https://www.dalao.net/$url';
      }
    }

    return url;
  }

  /// 解析帖子列表页面 (旧方法保留兼容)
  static List<Post> parsePostList(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final posts = <Post>[];

    debugPrint('parsePostList: 开始解析HTML');

    // 首先尝试使用新格式解析器 (li.media.thread[data-tid])
    var postElements = document.querySelectorAll('li.media.thread[data-tid]');
    debugPrint('parsePostList: 新格式选择器找到 ${postElements.length} 个');

    if (postElements.isNotEmpty) {
      for (var element in postElements) {
        try {
          final post = _parseThreadElement(element);
          if (post != null) {
            posts.add(post);
          }
        } catch (e) {
          debugPrint('parsePostList: 解析新格式失败: $e');
        }
      }
      debugPrint('parsePostList: 新格式解析到 ${posts.length} 个帖子');
      return posts;
    }

    // 尝试解析"我的帖子"格式 (li.media.post[data-pid])
    postElements = document.querySelectorAll('li.media.post[data-pid]');
    debugPrint('parsePostList: 我的帖子格式找到 ${postElements.length} 个');

    if (postElements.isNotEmpty) {
      for (var element in postElements) {
        try {
          final post = _parseMyPostElement(element);
          if (post != null) {
            posts.add(post);
          }
        } catch (e) {
          debugPrint('parsePostList: 解析我的帖子格式失败: $e');
        }
      }
      debugPrint('parsePostList: 我的帖子格式解析到 ${posts.length} 个帖子');
      return posts;
    }

    // 尝试旧格式选择器
    postElements = document.querySelectorAll(
        '.thread-item, .post-item, .topic-item, article, .list-item');
    debugPrint('parsePostList: 旧格式选择器找到 ${postElements.length} 个');

    for (var element in postElements) {
      try {
        final post = _parsePostElement(element);
        if (post != null) {
          posts.add(post);
        }
      } catch (e) {
        debugPrint('parsePostList: 解析旧格式失败: $e');
      }
    }

    debugPrint('parsePostList: 最终解析到 ${posts.length} 个帖子');
    return posts;
  }

  /// 解析"我的帖子"元素 (li.media.post)
  static Post? _parseMyPostElement(Element element) {
    // 从 data-pid 获取评论 ID (这里作为临时ID)
    final pidStr = element.attributes['data-pid'] ?? '';
    final pid = int.tryParse(pidStr) ?? 0;

    // 从标题链接中提取真正的帖子ID
    final titleLink = element.querySelector('.message h6 a');
    if (titleLink == null) return null;

    final href = titleLink.attributes['href'] ?? '';
    final tidMatch = RegExp(r'thread-(\d+)').firstMatch(href);
    final id = tidMatch != null ? int.tryParse(tidMatch.group(1)!) ?? 0 : 0;
    if (id == 0) return null;

    // 获取标题
    final title = titleLink.text.trim();
    if (title.isEmpty) return null;

    // 获取作者信息
    final authorElement = element.querySelector('.username a');
    final authorName = authorElement?.text.trim() ?? '匿名';

    // 获取作者 UID
    final uidStr = element.attributes['data-uid'] ?? '0';
    final authorId = int.tryParse(uidStr) ?? 0;

    // 获取作者头像
    final avatarElement = element.querySelector('img.avatar-3');
    String authorAvatar = avatarElement?.attributes['src'] ?? '';
    authorAvatar = _fixImageUrl(authorAvatar);

    // 获取时间
    final timeElement = element.querySelector('time.date');
    final timeText = timeElement?.text.trim() ?? '';
    final createdAt = _parseTime(timeText);

    // 获取内容预览 (去掉标题部分)
    final messageElement = element.querySelector('.message');
    String content = '';
    if (messageElement != null) {
      // 移除 h6 标题后的内容
      final clone = messageElement.clone(true);
      clone.querySelector('h6')?.remove();
      content = clone.text.trim();
    }

    return Post(
      id: id,
      title: title,
      content: content,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorId: authorId,
      createdAt: createdAt,
      viewCount: 0,
      replyCount: 0,
    );
  }

  /// 解析单个帖子元素
  static Post? _parsePostElement(Element element) {
    // 尝试获取标题
    final titleElement =
        element.querySelector('a.title, .thread-title a, h2 a, h3 a, .title a');
    if (titleElement == null) return null;

    final title = titleElement.text.trim();
    final href = titleElement.attributes['href'] ?? '';

    // 从 URL 提取帖子 ID (thread-12345.htm)
    final idMatch = RegExp(r'thread-(\d+)').firstMatch(href);
    final id = idMatch != null ? int.tryParse(idMatch.group(1)!) ?? 0 : 0;

    // 获取作者信息
    final authorElement =
        element.querySelector('.author a, .user a, .username, .poster');
    final authorName = authorElement?.text.trim() ?? '匿名';

    // 获取作者头像
    final avatarElement = element.querySelector('img.avatar, .avatar img');
    final authorAvatar = avatarElement?.attributes['src'] ?? '';

    // 获取回复数
    final replyElement =
        element.querySelector('.reply-count, .replies, .comment-count');
    final replyCount = int.tryParse(
            replyElement?.text.replaceAll(RegExp(r'[^\d]'), '') ?? '0') ??
        0;

    // 获取浏览数
    final viewElement = element.querySelector('.view-count, .views');
    final viewCount = int.tryParse(
            viewElement?.text.replaceAll(RegExp(r'[^\d]'), '') ?? '0') ??
        0;

    // 获取时间
    final timeElement =
        element.querySelector('.time, .date, time, .created-at');
    final timeText = timeElement?.text.trim() ?? '';
    final createdAt = _parseTime(timeText);

    // 获取分类
    final categoryElement =
        element.querySelector('.category, .tag, .forum-name');
    final category = categoryElement?.text.trim() ?? '';

    return Post(
      id: id,
      title: title,
      content: '', // 列表页通常没有内容
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorId: 0,
      createdAt: createdAt,
      viewCount: viewCount,
      replyCount: replyCount,
      category: category,
    );
  }

  /// 解析帖子详情页面
  static Post? parsePostDetail(String htmlContent, int postId) {
    final document = html_parser.parse(htmlContent);

    // 获取标题 - dalao.net 使用 h4.break-all 或 title
    final titleElement = document.querySelector('h4.break-all, .media-body h4');
    String title = titleElement?.text.trim() ?? '';

    // 如果没找到，尝试从 title 标签获取
    if (title.isEmpty) {
      final pageTitle = document.querySelector('title');
      title = pageTitle?.text.trim().replaceAll(' - 大佬论坛', '') ?? '';
    }

    // 获取内容 - dalao.net 使用 .message.break-all.box-shadow
    final contentElement = document.querySelector(
        '.message.break-all.box-shadow, .message.break-all[isfirst="1"]');
    String content = contentElement?.innerHtml ?? '';

    // 修复内容中的图片 URL
    content = _fixContentImageUrls(content);

    // 获取作者信息
    final authorElement = document
        .querySelector('.card-thread .username a, .media-body .username a');
    final authorName = authorElement?.text.trim() ?? '匿名';

    // 获取作者头像
    final avatarElement = document
        .querySelector('.card-user-info img, .card-thread img.avatar-3');
    String authorAvatar = avatarElement?.attributes['src'] ?? '';
    authorAvatar = _fixImageUrl(authorAvatar);

    // 获取作者 ID
    final authorHref = authorElement?.attributes['href'] ?? '';
    final authorIdMatch = RegExp(r'user-(\d+)').firstMatch(authorHref);
    final authorId =
        authorIdMatch != null ? int.tryParse(authorIdMatch.group(1)!) ?? 0 : 0;

    // 获取时间
    final timeElement =
        document.querySelector('.card-thread time.date, .media-body time');
    final timeText = timeElement?.text.trim() ?? '';
    final createdAt = _parseTime(timeText);

    // 获取浏览数 - 在 .icon-eye 旁边
    final viewElement =
        document.querySelector('[title="浏览"] .icon-eye, .icon-eye');
    int viewCount = 0;
    if (viewElement != null) {
      final viewParent = viewElement.parent;
      final viewText = viewParent?.text.trim() ?? '';
      viewCount = int.tryParse(viewText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    }

    // 获取回复数 - 在 .posts 里
    final replyElement = document.querySelector('.posts');
    final replyText = replyElement?.text.trim() ?? '0';
    final replyCount =
        int.tryParse(replyText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

    return Post(
      id: postId,
      title: title,
      content: content,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorId: authorId,
      createdAt: createdAt,
      viewCount: viewCount,
      replyCount: replyCount,
    );
  }

  /// 修复内容中的图片 URL
  static String _fixContentImageUrls(String content) {
    // 匹配 src 属性中的相对路径
    return content.replaceAllMapped(
      RegExp(r'src="([^"]*)"'),
      (match) {
        String url = match.group(1) ?? '';
        if (url.isNotEmpty &&
            !url.startsWith('http') &&
            !url.startsWith('data:')) {
          if (url.startsWith('/')) {
            url = 'https://www.dalao.net$url';
          } else {
            url = 'https://www.dalao.net/$url';
          }
        }
        return 'src="$url"';
      },
    );
  }

  /// 解析评论列表
  /// HTML 结构: ul.postlist > li.media.post[data-pid][data-uid]
  static List<Comment> parseComments(String htmlContent, int postId) {
    final comments = <Comment>[];

    debugPrint('=== 开始解析评论 ===');

    // 使用 html 解析器来解析评论
    final document = html_parser.parse(htmlContent);

    // 查找所有评论元素: li.media.post[data-pid]
    final commentElements =
        document.querySelectorAll('li.media.post[data-pid]');
    debugPrint('DOM解析找到 ${commentElements.length} 个评论元素');

    for (var element in commentElements) {
      try {
        final pidStr = element.attributes['data-pid'] ?? '';
        final pid = int.tryParse(pidStr) ?? 0;
        if (pid == 0) continue;

        final uidStr = element.attributes['data-uid'] ?? '0';
        final uid = int.tryParse(uidStr) ?? 0;

        // 解析评论内容
        var contentElement = element.querySelector('.message.mt-1.break-all');
        contentElement ??= element.querySelector('.message.break-all');
        contentElement ??= element.querySelector('.message');

        String content = contentElement?.innerHtml.trim() ?? '';
        if (content.isEmpty) {
          content = contentElement?.text.trim() ?? '';
        }
        if (content.isEmpty) continue;

        // 修复内容中的图片 URL
        content = _fixContentImageUrls(content);

        // 解析作者名 - 多种选择器
        String authorName = '匿名';
        var authorElement =
            element.querySelector('.username a.text-muted.font-weight-bold');
        authorElement ??= element.querySelector('.username a');
        if (authorElement != null) {
          authorName = authorElement.text.trim();
          authorName = authorName.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        }
        if (authorName.isEmpty) authorName = '匿名';

        // 解析头像
        final avatarElement = element.querySelector('img.avatar-3');
        String authorAvatar = avatarElement?.attributes['src'] ?? '';
        authorAvatar = _fixImageUrl(authorAvatar);

        // 解析时间
        var timeElement = element.querySelector('time.comment-time');
        timeElement ??= element.querySelector('time.date');
        timeElement ??= element.querySelector('time');
        String timeText = timeElement?.attributes['data-relative'] ??
            timeElement?.text.trim() ??
            '';
        final createdAt = _parseTime(timeText);

        // 检查是否是楼主
        final isOp =
            element.querySelector('.haya-post-info-first-floor') != null;

        // 检查是否有 @回复
        String? replyToName;
        int? replyToId;
        final atElement = element.querySelector('.haya-post-info-at em');
        if (atElement != null) {
          replyToName = atElement.text.replaceAll('@', '').trim();
          final atLink = element.querySelector('.haya-post-info-at');
          if (atLink != null) {
            final href = atLink.attributes['href'] ?? '';
            final uidMatch = RegExp(r'user-(\d+)').firstMatch(href);
            if (uidMatch != null) {
              replyToId = int.tryParse(uidMatch.group(1)!);
            }
          }
        }

        debugPrint('评论: pid=$pid, author=$authorName, reply=$replyToName');

        comments.add(Comment(
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
        ));
      } catch (e) {
        debugPrint('解析评论失败: $e');
      }
    }

    debugPrint('=== 最终解析到 ${comments.length} 个评论 ===');
    return comments;
  }

  /// 解析用户信息
  static User? parseUserProfile(String htmlContent) {
    final document = html_parser.parse(htmlContent);

    final usernameElement =
        document.querySelector('.username, .nickname, .user-name');
    final username = usernameElement?.text.trim() ?? '';
    if (username.isEmpty) return null;

    final avatarElement =
        document.querySelector('.avatar img, img.avatar, .user-avatar');
    final avatar = avatarElement?.attributes['src'] ?? '';

    final signatureElement =
        document.querySelector('.signature, .bio, .user-signature');
    final signature = signatureElement?.text.trim();

    return User(
      id: 0,
      username: username,
      nickname: username,
      email: '',
      avatar: avatar,
      signature: signature,
    );
  }

  /// 从首页解析当前登录用户信息
  static User? parseCurrentUser(String htmlContent) {
    final document = html_parser.parse(htmlContent);

    // dalao.net 导航栏用户信息结构:
    // <li class="nav-item username">
    //   <a class="nav-link" href="my.htm">
    //     <img class="avatar-1" src="upload/avatar/000/329.png?xxx"> 包子叔
    //     <span class="text-muted-name">(UID: 329)</span>
    //   </a>
    // </li>

    String username = '';
    String avatar = '';
    int userId = 0;

    // 方法1: 从导航栏获取
    final userNavItem = document.querySelector('.nav-item.username a.nav-link');
    if (userNavItem != null) {
      // 获取头像
      final avatarEl = userNavItem.querySelector('img.avatar-1');
      avatar = avatarEl?.attributes['src'] ?? '';
      avatar = _fixImageUrl(avatar);

      // 获取用户名 - 移除子元素后的文本
      username = userNavItem.text.trim();
      // 移除 (UID: xxx) 部分
      username =
          username.replaceAll(RegExp(r'\s*\(UID:\s*\d+\)\s*'), '').trim();

      // 获取 UID
      final uidMatch = RegExp(r'UID:\s*(\d+)').firstMatch(userNavItem.text);
      if (uidMatch != null) {
        userId = int.tryParse(uidMatch.group(1)!) ?? 0;
      }
    }

    // 方法2: 如果导航栏没找到，尝试从侧边栏获取 (my.htm 页面)
    if (username.isEmpty || avatar.isEmpty) {
      final sidebarAvatar = document.querySelector('#my_aside .avatar-4');
      if (sidebarAvatar != null && avatar.isEmpty) {
        avatar = sidebarAvatar.attributes['src'] ?? '';
        avatar = _fixImageUrl(avatar);
      }

      // 侧边栏用户名在头像下方
      final sidebarBody = document.querySelector('#my_aside .card-body');
      if (sidebarBody != null && username.isEmpty) {
        username = sidebarBody.text.trim();
      }
    }

    // 方法3: 从 HTML 文本中提取 UID
    if (userId == 0) {
      final uidTextMatch = RegExp(r'UID:\s*(\d+)').firstMatch(htmlContent);
      if (uidTextMatch != null) {
        userId = int.tryParse(uidTextMatch.group(1)!) ?? 0;
      }
    }

    if (username.isEmpty && avatar.isEmpty) return null;

    return User(
      id: userId,
      username: username.isNotEmpty ? username : '用户$userId',
      nickname: username.isNotEmpty ? username : '用户$userId',
      email: '',
      avatar: avatar,
    );
  }

  /// 从 my.htm 页面解析完整用户信息（包含统计数据）
  static User? parseMyProfile(String htmlContent) {
    final document = html_parser.parse(htmlContent);

    // 头像: #my_aside .avatar-4
    final avatarEl = document.querySelector('#my_aside .avatar-4');
    String avatar = avatarEl?.attributes['src'] ?? '';
    avatar = _fixImageUrl(avatar);

    // 用户名: #my_aside .card-body 文本
    final cardBody = document.querySelector('#my_aside .card-body');
    String username = '';
    if (cardBody != null) {
      username = cardBody.text.trim();
    }

    // 统计数据
    int postCount = 0;
    int replyCount = 0;
    int favoriteCount = 0;
    int followCount = 0;
    int fanCount = 0;
    int userId = 0;
    String? signature;

    final statsBody = document.querySelector('#my_main .card-body');
    if (statsBody != null) {
      final text = statsBody.text;

      // 主题数
      var match = RegExp(r'主题数：(\d+)').firstMatch(text);
      if (match != null) postCount = int.tryParse(match.group(1)!) ?? 0;

      // 帖子数
      match = RegExp(r'帖子数：(\d+)').firstMatch(text);
      if (match != null) replyCount = int.tryParse(match.group(1)!) ?? 0;

      // 收藏数
      match = RegExp(r'收藏数：(\d+)').firstMatch(text);
      if (match != null) favoriteCount = int.tryParse(match.group(1)!) ?? 0;

      // 关注数
      match = RegExp(r'关注数：(\d+)').firstMatch(text);
      if (match != null) followCount = int.tryParse(match.group(1)!) ?? 0;

      // 粉丝数
      match = RegExp(r'粉丝数：(\d+)').firstMatch(text);
      if (match != null) fanCount = int.tryParse(match.group(1)!) ?? 0;

      // UID
      match = RegExp(r'UID：(\d+)').firstMatch(text);
      if (match != null) userId = int.tryParse(match.group(1)!) ?? 0;

      // 个性签名
      match = RegExp(r'个性签名：(.+?)(?:Telegram|$)').firstMatch(text);
      if (match != null) {
        signature = match.group(1)?.trim();
        if (signature == '这家伙太懒了，什么也没留下。') {
          signature = null;
        }
      }
    }

    if (username.isEmpty && avatar.isEmpty) return null;

    return User(
      id: userId,
      username: username.isNotEmpty ? username : '用户$userId',
      nickname: username.isNotEmpty ? username : '用户$userId',
      email: '',
      avatar: avatar,
      signature: signature,
      postCount: postCount,
      replyCount: replyCount,
      favoriteCount: favoriteCount,
      followCount: followCount,
      fanCount: fanCount,
    );
  }

  /// 检查是否已登录
  static bool isLoggedIn(String htmlContent) {
    // 方法1: 检查是否包含退出链接
    if (htmlContent.contains('user-logout.htm') ||
        htmlContent.contains('退出') ||
        htmlContent.contains('icon-sign-out')) {
      debugPrint('检测到退出链接，已登录');
      return true;
    }

    // 方法2: 检查是否有用户头像和用户名
    if (htmlContent.contains('upload/avatar/') &&
        htmlContent.contains('UID:')) {
      debugPrint('检测到用户头像和UID，已登录');
      return true;
    }

    // 方法3: 检查是否有"我的"相关链接
    if (htmlContent.contains('my.htm') ||
        htmlContent.contains('my-notice.htm')) {
      debugPrint('检测到个人中心链接，已登录');
      return true;
    }

    // 方法4: 检查是否有登录表单（未登录）
    if (htmlContent.contains('login.htm') && htmlContent.contains('请先登录')) {
      debugPrint('检测到登录提示，未登录');
      return false;
    }

    debugPrint('无法确定登录状态，默认未登录');
    return false;
  }

  /// 解析时间字符串
  static DateTime _parseTime(String timeText) {
    if (timeText.isEmpty) return DateTime.now();

    // 处理相对时间
    if (timeText.contains('秒前')) {
      final seconds =
          int.tryParse(timeText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      return DateTime.now().subtract(Duration(seconds: seconds));
    }
    if (timeText.contains('分钟前')) {
      final minutes =
          int.tryParse(timeText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      return DateTime.now().subtract(Duration(minutes: minutes));
    }
    if (timeText.contains('小时前')) {
      final hours =
          int.tryParse(timeText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      return DateTime.now().subtract(Duration(hours: hours));
    }
    if (timeText.contains('天前')) {
      final days = int.tryParse(timeText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      return DateTime.now().subtract(Duration(days: days));
    }

    // 尝试解析标准日期格式
    try {
      // 2024-12-30 格式
      final dateMatch =
          RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(timeText);
      if (dateMatch != null) {
        return DateTime(
          int.parse(dateMatch.group(1)!),
          int.parse(dateMatch.group(2)!),
          int.parse(dateMatch.group(3)!),
        );
      }
    } catch (e) {
      // 解析失败
    }

    return DateTime.now();
  }

  /// 解析消息通知列表
  /// [type] 7=私信, 2=评论我的, 156=提及我的, 3=系统通知
  static List<Notice> parseNotices(String htmlContent, int type) {
    final document = html_parser.parse(htmlContent);
    final notices = <Notice>[];

    // 私信类型 - 解析联系人列表
    if (type == 7) {
      final contactElements = document.querySelectorAll('.pm-contact-item');
      debugPrint('私信: 找到 ${contactElements.length} 个联系人元素');
      for (var i = 0; i < contactElements.length; i++) {
        try {
          final notice = _parsePrivateMessageContact(contactElements[i], i);
          if (notice != null) {
            notices.add(notice);
          }
        } catch (e) {
          debugPrint('解析私信联系人失败: $e');
        }
      }
      return notices;
    }

    // 其他通知类型 - 解析通知列表
    var noticeElements = document.querySelectorAll('ul.noticelist > li.notice');
    debugPrint('通知类型 $type: 选择器1找到 ${noticeElements.length} 个元素');

    if (noticeElements.isEmpty) {
      noticeElements = document.querySelectorAll('.noticelist .notice');
      debugPrint('通知类型 $type: 选择器2找到 ${noticeElements.length} 个元素');
    }
    if (noticeElements.isEmpty) {
      noticeElements = document.querySelectorAll('li.notice.media');
      debugPrint('通知类型 $type: 选择器3找到 ${noticeElements.length} 个元素');
    }

    for (var i = 0; i < noticeElements.length; i++) {
      try {
        final notice = _parseNoticeElement(noticeElements[i], type, i);
        if (notice != null) {
          notices.add(notice);
        }
      } catch (e) {
        // 跳过解析失败的元素
      }
    }

    return notices;
  }

  /// 解析私信联系人
  static Notice? _parsePrivateMessageContact(Element element, int index) {
    // 跳过群聊
    if (element.classes.contains('group-chat-item')) {
      final preview =
          element.querySelector('.pm-contact-preview')?.text.trim() ?? '';
      final time = element.querySelector('.pm-contact-time')?.text.trim() ?? '';
      return Notice(
        id: index,
        type: 'private',
        title: '官方群聊',
        content: preview,
        fromUserName: '官方群聊',
        fromUserAvatar: '',
        fromUserId: 0,
        createdAt: _parseTime(time),
      );
    }

    // 获取用户ID
    final uidStr = element.attributes['data-uid'] ?? '0';
    final fromUserId = int.tryParse(uidStr) ?? 0;

    // 获取用户名
    final fromUserName = element.attributes['data-username'] ??
        element.querySelector('.pm-contact-name')?.text.trim() ??
        '未知';

    // 获取头像
    final avatarElement = element.querySelector('.pm-contact-avatar img');
    String fromUserAvatar = avatarElement?.attributes['src'] ?? '';
    fromUserAvatar = _fixImageUrl(fromUserAvatar);

    // 获取最后消息预览
    final preview =
        element.querySelector('.pm-contact-preview')?.text.trim() ?? '';

    // 获取时间
    final time = element.querySelector('.pm-contact-time')?.text.trim() ?? '';
    final createdAt = _parseTime(time);

    return Notice(
      id: index,
      type: 'private',
      title: '$fromUserName 的私信',
      content: preview,
      fromUserName: fromUserName,
      fromUserAvatar: fromUserAvatar,
      fromUserId: fromUserId,
      createdAt: createdAt,
    );
  }

  /// 解析单个消息元素 (评论/提及/系统)
  /// HTML 结构: li.notice.media 包含:
  /// - 头像: img.avatar-3
  /// - 用户名: .username a 或 .username (系统通知)
  /// - 时间: span.date
  /// - 帖子链接: .comment-info a[href*="thread-"] 或 .message a[href*="thread-"]
  /// - 回复内容: .single-comment a 或 .message 文本
  static Notice? _parseNoticeElement(Element element, int type, int index) {
    // 获取发送者信息
    final userLinkElement = element.querySelector('.username a');
    final userSpanElement = element.querySelector('.username');
    String fromUserName;
    String userHref = '';

    if (userLinkElement != null) {
      fromUserName = userLinkElement.text.trim();
      userHref = userLinkElement.attributes['href'] ?? '';
    } else if (userSpanElement != null) {
      fromUserName = userSpanElement.text.trim();
    } else {
      fromUserName = '系统';
    }

    // 获取发送者头像
    final avatarElement = element.querySelector('img.avatar-3');
    String fromUserAvatar = avatarElement?.attributes['src'] ?? '';
    fromUserAvatar = _fixImageUrl(fromUserAvatar);

    // 获取发送者ID
    final userIdMatch = RegExp(r'user-(\d+)').firstMatch(userHref);
    final fromUserId =
        userIdMatch != null ? int.tryParse(userIdMatch.group(1)!) ?? 0 : 0;

    // 获取关联的帖子
    var postLink = element.querySelector('.comment-info a[href*="thread-"]');
    postLink ??= element.querySelector('.message a[href*="thread-"]');

    String? postTitle;
    int? postId;
    if (postLink != null) {
      postTitle = postLink.attributes['title']?.trim();
      if (postTitle == null || postTitle.isEmpty) {
        postTitle = postLink.text.trim();
        postTitle = postTitle.replaceAll(RegExp(r'^《|》$'), '');
      }
      final postHref = postLink.attributes['href'] ?? '';
      final postIdMatch = RegExp(r'thread-(\d+)').firstMatch(postHref);
      postId = postIdMatch != null ? int.tryParse(postIdMatch.group(1)!) : null;
    }

    // 获取内容
    String content = '';
    final replyElement = element.querySelector('.single-comment a');
    if (replyElement != null) {
      content = replyElement.text.trim();
    }
    if (content.isEmpty) {
      final messageElement = element.querySelector('.message.break-all');
      if (messageElement != null) {
        content = messageElement.text.trim();
        content = content.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }

    // 获取时间
    final timeElement = element.querySelector('span.date');
    final timeText = timeElement?.text.trim() ?? '';
    final createdAt = _parseTime(timeText);

    // 确定消息类型和标题
    String noticeType;
    String title;
    switch (type) {
      case 156:
        noticeType = 'mention';
        title = '$fromUserName 提及了你';
        break;
      case 3:
        noticeType = 'system';
        title = '系统通知';
        break;
      default:
        noticeType = 'reply';
        title = '$fromUserName 评论了你';
    }

    return Notice(
      id: index,
      type: noticeType,
      title: title,
      content: content,
      fromUserName: fromUserName,
      fromUserAvatar: fromUserAvatar,
      fromUserId: fromUserId,
      postId: postId,
      postTitle: postTitle,
      createdAt: createdAt,
    );
  }

  /// 解析商家列表

  /// 解析商家列表
  /// HTML 结构: .provider > .merchant-card[data-uid]
  ///   - .merchant-card-front img.merchant-logo - logo图片
  ///   - .merchant-card-back .merchant-brand-name - 品牌名
  ///   - .merchant-card-back .merchant-brand-link - 官网链接
  ///   - .merchant-card-back .merchant-user-link - 用户主页
  static List<Merchant> parseMerchants(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final merchants = <Merchant>[];

    // 选择所有商家卡片
    final merchantElements =
        document.querySelectorAll('.merchant-card[data-uid]');
    debugPrint('商家: 找到 ${merchantElements.length} 个商家卡片');

    for (var i = 0; i < merchantElements.length; i++) {
      try {
        final merchant = _parseMerchantElement(merchantElements[i], i);
        if (merchant != null) {
          merchants.add(merchant);
        }
      } catch (e) {
        debugPrint('解析商家失败: $e');
      }
    }

    return merchants;
  }

  /// 解析单个商家元素
  static Merchant? _parseMerchantElement(Element element, int index) {
    // 获取用户ID
    final uidStr = element.attributes['data-uid'] ?? '';
    final id = int.tryParse(uidStr) ?? index;

    // 获取 logo 图片
    final logoElement =
        element.querySelector('.merchant-card-front img.merchant-logo');
    String logo = logoElement?.attributes['src'] ?? '';
    logo = _fixImageUrl(logo);

    // 获取品牌名称
    final nameElement = element.querySelector('.merchant-brand-name');
    String name = nameElement?.text.trim() ?? '';

    // 如果没有名称，尝试从 logo 的 alt 获取
    if (name.isEmpty) {
      name = logoElement?.attributes['alt']?.trim() ?? '';
    }

    if (name.isEmpty && logo.isEmpty) return null;

    // 获取官网链接
    final brandLinkElement = element.querySelector('.merchant-brand-link');
    String? website = brandLinkElement?.attributes['href'];

    // 获取用户名
    final userLinkElement = element.querySelector('.merchant-user-link');
    String? userName = userLinkElement?.text.trim().replaceAll('@', '');

    return Merchant(
      id: id,
      name: name,
      logo: logo,
      website: website,
      description: userName,
    );
  }

  /// 解析摸鱼 RSS 聚合列表
  /// HTML 结构: li.media.thread[data-rss-item="1"]
  ///   - a > img.avatar-3 - 来源图标
  ///   - .subject a - 标题和链接
  ///   - .username - 作者
  ///   - .date - 时间
  ///   - span[style*="background"] - 来源名称
  static List<MoyuItem> parseMoyuList(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final items = <MoyuItem>[];

    // 选择所有 RSS 项目
    final itemElements =
        document.querySelectorAll('li.media.thread[data-rss-item="1"]');
    debugPrint('摸鱼: 找到 ${itemElements.length} 个 RSS 项目');

    for (var element in itemElements) {
      try {
        final item = _parseMoyuElement(element);
        if (item != null) {
          items.add(item);
        }
      } catch (e) {
        debugPrint('解析摸鱼项目失败: $e');
      }
    }

    return items;
  }

  /// 解析单个摸鱼元素
  static MoyuItem? _parseMoyuElement(Element element) {
    // 获取标题和链接
    final titleElement = element.querySelector('.subject a');
    final title = titleElement?.text.trim() ?? '';
    final url = titleElement?.attributes['href'] ?? '';

    if (title.isEmpty || url.isEmpty) return null;

    // 获取来源图标
    final iconElement = element.querySelector('img.avatar-3');
    String sourceIcon = iconElement?.attributes['src'] ?? '';
    sourceIcon = _fixImageUrl(sourceIcon);

    // 获取作者
    final authorElement = element.querySelector('.username');
    final author = authorElement?.text.trim() ?? '';

    // 获取时间
    final timeElement = element.querySelector('.date');
    final timeText = timeElement?.text.trim() ?? '';
    final publishedAt = _parseTime(timeText);

    // 获取来源名称 - 从带背景色的 span 中提取
    String source = '';
    final sourceElements =
        element.querySelectorAll('span[style*="background"]');
    for (var span in sourceElements) {
      final text = span.text.trim();
      if (text.isNotEmpty) {
        source = text;
        break;
      }
    }

    // 如果没找到，尝试从图标的 title 属性获取
    if (source.isEmpty) {
      source = iconElement?.attributes['title'] ?? '';
    }

    return MoyuItem(
      title: title,
      url: url,
      author: author,
      source: source,
      sourceIcon: sourceIcon,
      publishedAt: publishedAt,
    );
  }

  /// 解析搜索结果
  /// 搜索结果页面使用与帖子列表相同的 HTML 结构
  static List<Post> parseSearchResults(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final posts = <Post>[];

    // 搜索结果在 ul.threadlist > li.media.thread
    var postElements = document.querySelectorAll('li.media.thread[data-tid]');
    debugPrint('搜索结果: 找到 ${postElements.length} 个帖子');

    if (postElements.isEmpty) {
      // 尝试其他选择器
      postElements = document.querySelectorAll('.threadlist .thread');
      debugPrint('搜索结果备选: 找到 ${postElements.length} 个帖子');
    }

    for (var element in postElements) {
      try {
        final post = _parseThreadElement(element);
        if (post != null) {
          posts.add(post);
        }
      } catch (e) {
        debugPrint('解析搜索结果失败: $e');
      }
    }

    return posts;
  }

  /// 提取发帖页面的 session ID (sid)
  static String? extractSid(String htmlContent) {
    final document = html_parser.parse(htmlContent);

    // 查找 hidden input name="sid"
    final sidInput = document.querySelector('input[name="sid"]');
    if (sidInput != null) {
      return sidInput.attributes['value'];
    }

    // 备用方案：从 JavaScript 中提取
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      final match =
          RegExp(r'sid\s*[=:]\s*["\x27]([a-zA-Z0-9]+)["\x27]').firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// 解析发帖响应
  static Map<String, dynamic> parseCreatePostResponse(String responseText) {
    try {
      // 尝试解析 JSON 响应
      if (responseText.trim().startsWith('{')) {
        final json = jsonDecode(responseText);
        final code = json['code'] ?? json['errcode'] ?? -1;
        final message = json['message'] ?? json['msg'] ?? json['errmsg'] ?? '';

        if (code == 0) {
          final tid = json['tid'] ?? json['data']?['tid'];
          return {
            'success': true,
            'message': message.isEmpty ? '发帖成功' : message,
            'tid': tid,
          };
        } else {
          return {
            'success': false,
            'message': message.isEmpty ? '发帖失败' : message,
          };
        }
      }

      // 检查是否包含成功标识
      if (responseText.contains('发帖成功') ||
          responseText.contains('thread-') ||
          responseText.contains('"code":0')) {
        final tidMatch = RegExp(r'thread-(\d+)').firstMatch(responseText);
        return {
          'success': true,
          'message': '发帖成功',
          'tid': tidMatch?.group(1),
        };
      }

      // 检查错误信息
      if (responseText.contains('登录') || responseText.contains('login')) {
        return {'success': false, 'message': '请先登录'};
      }

      if (responseText.contains('标题') && responseText.contains('不能为空')) {
        return {'success': false, 'message': '标题不能为空'};
      }

      if (responseText.contains('内容') && responseText.contains('不能为空')) {
        return {'success': false, 'message': '内容不能为空'};
      }

      // 尝试从 HTML 中提取错误信息
      final document = html_parser.parse(responseText);
      final alertElement = document.querySelector('.alert, .error, .message');
      if (alertElement != null) {
        return {'success': false, 'message': alertElement.text.trim()};
      }

      return {'success': false, 'message': '发帖失败，请稍后重试'};
    } catch (e) {
      debugPrint('解析发帖响应失败: $e');
      return {'success': false, 'message': '解析响应失败'};
    }
  }

  /// 解析域名市场列表
  /// HTML 结构: table.dm-market-list-table > tbody > tr
  ///   - td:nth-child(1) a - 域名名称
  ///   - td:nth-child(1) .domain-verify-status - 验证状态
  ///   - td:nth-child(2) span - 价格
  ///   - td:nth-child(3) .domain-description-text - 描述
  ///   - td:nth-child(4) - 长度
  ///   - td:nth-child(5) .publisher-name - 发布人
  static List<DomainItem> parseDomainMarket(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final items = <DomainItem>[];

    // 选择表格中的所有行
    final rowElements = document.querySelectorAll('#domain-list-tbody tr');
    debugPrint('域名市场: 找到 ${rowElements.length} 行');

    for (var i = 0; i < rowElements.length; i++) {
      try {
        final item = _parseDomainRow(rowElements[i], i);
        if (item != null) {
          items.add(item);
        }
      } catch (e) {
        debugPrint('解析域名行失败: $e');
      }
    }

    return items;
  }

  /// 解析单个域名行
  static DomainItem? _parseDomainRow(Element row, int index) {
    final cells = row.querySelectorAll('td');
    if (cells.length < 5) return null;

    // 第1列: 域名
    final domainLink = cells[0].querySelector('a');
    String domain = '';
    if (domainLink != null) {
      // 从 onclick 属性提取域名
      final onclick = domainLink.attributes['onclick'] ?? '';
      final match = RegExp(r"showDomainWhois\('([^']+)'").firstMatch(onclick);
      if (match != null) {
        domain = match.group(1)!;
      } else {
        domain = domainLink.text.trim();
      }
    }
    if (domain.isEmpty) return null;

    // 提取后缀
    final dotIndex = domain.indexOf('.');
    final suffix = dotIndex > 0 ? domain.substring(dotIndex + 1) : '';

    // 验证状态
    final verifyStatus = cells[0].querySelector('.domain-verify-status');
    final isVerified = verifyStatus?.classes.contains('verified') ?? false;

    // 验证时间
    DateTime? verifiedAt;
    final tooltipLine = cells[0].querySelector('.tooltip-line:last-child');
    if (tooltipLine != null) {
      final timeText =
          tooltipLine.text.replaceAll(RegExp(r'验证时间[：:]'), '').trim();
      verifiedAt = _parseTime(timeText);
    }

    // 第2列: 价格
    final priceSpan = cells[1].querySelector('span');
    final priceText = priceSpan?.text.trim() ?? '';
    double? price;
    bool isInquiry = false;
    if (priceText.contains('询价')) {
      isInquiry = true;
    } else {
      final priceMatch = RegExp(r'[\d,]+').firstMatch(priceText);
      if (priceMatch != null) {
        price = double.tryParse(priceMatch.group(0)!.replaceAll(',', ''));
      }
    }

    // 第3列: 描述
    final descSpan = cells[2].querySelector('.domain-description-text');
    String description = descSpan?.text.trim() ?? '';
    if (description == '--') description = '';

    // 第4列: 长度
    final lengthText = cells[3].text.trim();
    final length =
        int.tryParse(lengthText) ?? domain.indexOf('.').clamp(0, 999);

    // 第5列: 发布人
    final publisherSpan = cells[4].querySelector('.publisher-name');
    final publisherName = publisherSpan?.text.trim() ?? '未知';

    // 从 onclick 提取域名ID
    final detailOnclick = cells[2]
            .querySelector('[onclick*="showDomainDetail"]')
            ?.attributes['onclick'] ??
        '';
    final idMatch =
        RegExp(r'showDomainDetail\((\d+)\)').firstMatch(detailOnclick);
    final id =
        idMatch != null ? int.tryParse(idMatch.group(1)!) ?? index : index;

    return DomainItem(
      id: id,
      domain: domain,
      suffix: suffix,
      length: length,
      price: price,
      isInquiry: isInquiry,
      description: description.isNotEmpty ? description : null,
      publisherName: publisherName,
      publisherId: 0,
      isVerified: isVerified,
      verifiedAt: verifiedAt,
    );
  }
}
