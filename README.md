# 大佬论坛 Flutter 客户端

[![CI](https://github.com/yourusername/dalao_client/actions/workflows/ci.yml/badge.svg)](https://github.com/yourusername/dalao_client/actions/workflows/ci.yml)
[![Release](https://github.com/yourusername/dalao_client/actions/workflows/release.yml/badge.svg)](https://github.com/yourusername/dalao_client/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

大佬论坛（dalao.net）的 Flutter 移动客户端应用。

## 功能特性

### 核心功能
- ✅ 用户登录/注册
- ✅ 帖子浏览（首页、分类）
- ✅ 帖子详情查看
- ✅ 评论浏览与回复
- ✅ 发布新帖子
- ✅ 搜索功能（标题/内容/用户）

### 消息通知
- ✅ 评论通知
- ✅ 提及通知
- ✅ 私信通知
- ✅ 系统通知
- ✅ 未读消息红点提示

### 个人中心
- ✅ 个人资料展示
- ✅ 我的帖子
- ✅ 我的收藏
- ✅ 浏览历史
- ✅ 账号设置（密码、邮箱、用户名、签名）

### 其他功能
- ✅ 商家中心
- ✅ 深色模式
- ✅ 下拉刷新
- ✅ 自动分页加载
- ✅ 图片缓存
- ✅ HTML 内容渲染
- ✅ 代码高亮显示

## 技术栈

- **框架**: Flutter 3.0+
- **状态管理**: Provider
- **网络请求**: Dio
- **本地存储**: SharedPreferences
- **图片缓存**: CachedNetworkImage
- **HTML 渲染**: flutter_html
- **WebView**: webview_flutter

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   ├── post.dart            # 帖子模型
│   ├── comment.dart         # 评论模型
│   ├── user.dart            # 用户模型
│   └── ...
├── providers/               # 状态管理
│   ├── auth_provider.dart   # 认证状态
│   ├── theme_provider.dart  # 主题状态
│   └── message_provider.dart # 消息状态
├── screens/                 # 页面
│   ├── home_screen.dart     # 主页
│   ├── post_detail_screen.dart # 帖子详情
│   ├── profile_screen.dart  # 个人中心
│   └── ...
├── services/                # 服务层
│   ├── api_service.dart     # API 接口
│   ├── html_parser.dart     # HTML 解析
│   └── history_service.dart # 历史记录
└── widgets/                 # 通用组件
    ├── post_card.dart       # 帖子卡片
    ├── comment_card.dart    # 评论卡片
    └── ...
```

## 开始使用

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Android SDK (用于 Android 开发)

### 安装步骤

1. 克隆项目
```bash
git clone https://github.com/yourusername/dalao_client.git
cd dalao_client
```

2. 安装依赖
```bash
flutter pub get
```

3. 运行应用
```bash
flutter run
```

### 打包 APK

```bash
# 打包所有架构
flutter build apk

# 打包分架构 APK（推荐，体积更小）
flutter build apk --split-per-abi
```

生成的 APK 文件位于 `build/app/outputs/flutter-apk/` 目录。

## 配置说明

### Android 签名配置

如需发布应用，请创建 `android/key.properties` 文件：

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=path/to/your/keystore.jks
```

**注意**: 该文件已在 `.gitignore` 中，不会被提交到 Git。

## 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 开源协议

本项目采用 MIT 协议开源 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 相关链接

- 官网: [dalao.net](https://www.dalao.net)
- 电报群: [@dalaonet](https://t.me/dalaonet)

## 致谢

感谢大佬论坛提供的 API 支持。

---

**免责声明**: 本项目为第三方客户端，与大佬论坛官方无关。
