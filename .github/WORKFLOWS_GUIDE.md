# GitHub Actions 工作流说明

本项目包含三个 GitHub Actions 工作流，用于自动化构建、测试和发布。

## 📋 工作流列表

### 1. CI (ci.yml)
**触发条件**: 推送到 main/develop 分支或创建 Pull Request

**功能**:
- 代码格式检查
- 静态代码分析
- 运行单元测试
- 生成测试覆盖率报告
- 构建 APK（用于验证）

**用途**: 确保代码质量，在合并前发现问题

### 2. Build (build.yml)
**触发条件**: 
- 推送 v* 标签（如 v1.0.0）
- 手动触发

**功能**:
- 构建所有架构的 APK
- 自动重命名 APK 文件
- 上传构建产物
- 创建 GitHub Release（仅标签触发时）

**用途**: 快速构建和发布测试版本

### 3. Release (release.yml)
**触发条件**: 推送 v*.*.* 格式的标签（如 v1.0.0）

**功能**:
- 创建正式的 GitHub Release
- 构建所有架构的 APK
- 自动上传到 Release
- 生成详细的发布说明

**用途**: 正式版本发布

## 🚀 使用方法

### 发布新版本

1. **更新版本号**
   ```bash
   # 编辑 pubspec.yaml
   version: 1.0.1+2
   
   # 更新应用内显示的版本号
   # lib/screens/settings_screen.dart
   # lib/screens/profile_screen.dart
   ```

2. **提交更改**
   ```bash
   git add .
   git commit -m "chore: bump version to 1.0.1"
   git push origin main
   ```

3. **创建标签并推送**
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

4. **等待自动构建**
   - 访问 GitHub Actions 页面查看构建进度
   - 构建完成后，在 Releases 页面查看发布

### 手动触发构建

1. 访问 GitHub 仓库的 Actions 页面
2. 选择 "Build and Release" 工作流
3. 点击 "Run workflow" 按钮
4. 选择分支并运行

### 查看构建结果

- **Actions 页面**: 查看构建日志和状态
- **Artifacts**: 下载构建产物（保留 7-30 天）
- **Releases 页面**: 下载正式发布的 APK

## 📦 构建产物说明

每次构建会生成 4 个 APK 文件：

| 文件名 | 架构 | 适用设备 | 大小 |
|--------|------|----------|------|
| dalao-client-vX.X.X-arm64-v8a.apk | ARM 64位 | 大多数现代设备 | ~20MB |
| dalao-client-vX.X.X-armeabi-v7a.apk | ARM 32位 | 较老的设备 | ~18MB |
| dalao-client-vX.X.X-x86_64.apk | x86 64位 | 模拟器/特殊设备 | ~22MB |
| dalao-client-vX.X.X-universal.apk | 通用 | 所有设备 | ~60MB |

**推荐**: 优先下载 arm64-v8a 版本

## ⚙️ 配置说明

### 必需的 Secrets

**如果需要签名的 APK**，需要配置以下 Secrets：

1. 访问仓库的 Settings > Secrets and variables > Actions
2. 添加以下 Secrets：
   - `KEYSTORE_BASE64`: 签名密钥的 Base64 编码
   - `KEYSTORE_PASSWORD`: 密钥库密码
   - `KEY_ALIAS`: 密钥别名（如 dalao）
   - `KEY_PASSWORD`: 密钥密码

**详细配置步骤**: 查看 [SIGNING_SETUP.md](SIGNING_SETUP.md)

**如果不配置签名**:
- 工作流会自动跳过签名步骤
- 生成 debug 签名的 APK（仅用于测试）
- 无法用于正式发布

### 可选配置

如需上传到其他平台（如 Google Play），需要添加以下 Secrets：

1. 访问仓库的 Settings > Secrets and variables > Actions
2. 添加以下 Secrets：
   - `PLAY_STORE_CREDENTIALS`: Google Play 服务账号 JSON
   - `KEYSTORE_BASE64`: 签名密钥的 Base64 编码
   - `KEYSTORE_PASSWORD`: 密钥库密码
   - `KEY_ALIAS`: 密钥别名
   - `KEY_PASSWORD`: 密钥密码

### 修改 Flutter 版本

编辑工作流文件中的 Flutter 版本：

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.19.0'  # 修改这里
    channel: 'stable'
```

## 🔧 故障排查

### 构建失败

1. **检查日志**: 在 Actions 页面查看详细错误信息
2. **本地验证**: 在本地运行 `flutter build apk` 确保能正常构建
3. **依赖问题**: 确保 `pubspec.yaml` 中的依赖版本正确

### 发布失败

1. **标签格式**: 确保标签格式为 `v1.0.0`（以 v 开头）
2. **权限问题**: 确保 Actions 有写入权限（Settings > Actions > General > Workflow permissions）
3. **重复发布**: 删除已存在的 Release 和标签后重试

### APK 上传失败

1. **文件路径**: 检查 APK 文件是否在正确的路径
2. **文件名**: 确保重命名步骤正确执行
3. **网络问题**: 重新运行工作流

## 📝 最佳实践

1. **版本号规范**: 遵循语义化版本号（Semantic Versioning）
2. **测试先行**: 确保 CI 通过后再发布
3. **标签管理**: 使用有意义的标签名和描述
4. **发布说明**: 在 Release 中详细说明更新内容
5. **保留历史**: 不要删除旧版本的 Release

## 🔗 相关链接

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Flutter CI/CD 最佳实践](https://docs.flutter.dev/deployment/cd)
- [语义化版本号](https://semver.org/lang/zh-CN/)

## 📞 获取帮助

如遇到问题，请：
1. 查看 Actions 日志
2. 搜索相关 Issue
3. 创建新的 Issue 并附上错误日志
