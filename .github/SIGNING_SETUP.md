# APK 签名配置指南

GitHub Actions 自动构建需要配置签名密钥才能生成可安装的 APK。

## 📋 准备工作

### 1. 生成签名密钥（如果还没有）

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias dalao
```

按提示输入：
- 密钥库密码（Keystore password）
- 密钥密码（Key password）
- 姓名、组织等信息

**重要**: 妥善保管密钥文件和密码！

### 2. 将密钥转换为 Base64

```bash
# Linux/macOS
base64 -i upload-keystore.jks -o keystore.txt

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Out-File keystore.txt
```

## 🔐 配置 GitHub Secrets

### 步骤

1. 打开 GitHub 仓库
2. 进入 **Settings** > **Secrets and variables** > **Actions**
3. 点击 **New repository secret**
4. 添加以下 4 个 Secrets：

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `KEYSTORE_BASE64` | keystore.txt 的内容 | 密钥文件的 Base64 编码 |
| `KEYSTORE_PASSWORD` | 你的密钥库密码 | 创建密钥时设置的密码 |
| `KEY_ALIAS` | dalao | 密钥别名 |
| `KEY_PASSWORD` | 你的密钥密码 | 创建密钥时设置的密码 |

### 添加 Secret 示例

**KEYSTORE_BASE64**:
```
MIIKXAIBAzCCCh4GCSqGSIb3DQEHAaCCCg8EggoLMIIKBzCCBW8GCSqGSIb3DQEH...
(很长的 Base64 字符串)
```

**KEYSTORE_PASSWORD**:
```
your_keystore_password
```

**KEY_ALIAS**:
```
dalao
```

**KEY_PASSWORD**:
```
your_key_password
```

## ✅ 验证配置

### 方法 1: 手动触发构建

1. 进入 **Actions** 页面
2. 选择 **Build and Release** 工作流
3. 点击 **Run workflow**
4. 等待构建完成
5. 下载 APK 并安装测试

### 方法 2: 推送标签触发

```bash
git tag v1.0.0-test
git push origin v1.0.0-test
```

查看 Actions 页面的构建日志，确认签名步骤成功。

## 🔍 故障排查

### 问题 1: 密钥解码失败

**错误信息**:
```
base64: invalid input
```

**解决方法**:
- 确保 Base64 字符串没有换行符
- 重新生成 Base64 编码
- 检查是否复制完整

### 问题 2: 签名失败

**错误信息**:
```
Keystore was tampered with, or password was incorrect
```

**解决方法**:
- 检查 `KEYSTORE_PASSWORD` 是否正确
- 检查 `KEY_PASSWORD` 是否正确
- 确认密钥别名 `KEY_ALIAS` 正确

### 问题 3: APK 无法安装

**可能原因**:
- 签名配置错误
- 密钥不匹配（更新应用时）

**解决方法**:
- 卸载旧版本后重新安装
- 检查签名是否成功（查看构建日志）

## 📝 本地测试签名

在推送到 GitHub 之前，先在本地测试签名：

### 1. 创建 key.properties

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=dalao
storeFile=/path/to/upload-keystore.jks
```

### 2. 构建签名 APK

```bash
flutter build apk --release
```

### 3. 验证签名

```bash
# 查看签名信息
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# 或使用 apksigner
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

## 🔒 安全建议

### 1. 密钥管理
- ✅ 使用 GitHub Secrets 存储敏感信息
- ✅ 不要将密钥文件提交到 Git
- ✅ 定期备份密钥文件
- ✅ 使用强密码

### 2. 访问控制
- ✅ 限制仓库访问权限
- ✅ 定期审查 Secrets 使用情况
- ✅ 使用分支保护规则

### 3. 密钥轮换
- 如果密钥泄露，立即：
  1. 删除 GitHub Secrets
  2. 生成新的密钥
  3. 重新配置 Secrets
  4. 发布新版本

## 🚀 无签名构建（测试用）

如果只是测试构建流程，可以不配置签名：

1. **不添加** GitHub Secrets
2. 工作流会自动跳过签名步骤
3. 生成的是 **debug 签名** 的 APK
4. 可以安装，但不能用于正式发布

**注意**: Debug 签名的 APK 无法更新已安装的 Release 版本。

## 📚 相关文档

- [Android 应用签名](https://developer.android.com/studio/publish/app-signing)
- [Flutter 部署文档](https://docs.flutter.dev/deployment/android)
- [GitHub Secrets 文档](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

## 💡 常见问题

### Q: 可以使用 Google Play 的签名吗？

A: 可以。如果使用 Google Play App Signing：
1. 上传 App Bundle 而不是 APK
2. Google Play 会自动管理签名
3. 本地只需要上传密钥

### Q: 密钥丢失了怎么办？

A: 
- 如果是新应用：生成新密钥重新发布
- 如果已发布：无法更新应用，只能发布新应用
- **重要**: 一定要备份密钥！

### Q: 可以更改密钥吗？

A:
- 新应用：可以
- 已发布应用：不能（会导致无法更新）
- 建议：从一开始就使用正确的密钥

## 📞 获取帮助

如遇到问题：
1. 查看 Actions 构建日志
2. 检查本文档的故障排查部分
3. 在 Issues 中搜索相关问题
4. 创建新 Issue 并附上错误日志
