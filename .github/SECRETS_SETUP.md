# GitHub Secrets 设置指南

## 📋 需要添加的 Secrets

在 GitHub 仓库中添加以下 4 个 Secrets 以启用 APK 签名：

### 1. KEYSTORE_BASE64
- **Name**: `KEYSTORE_BASE64`
- **Value**: 粘贴 `keystore.txt` 文件的全部内容
- **说明**: 这是你的密钥库文件的 Base64 编码

### 2. KEYSTORE_PASSWORD
- **Name**: `KEYSTORE_PASSWORD`
- **Value**: `dalao123456`
- **说明**: 密钥库密码

### 3. KEY_ALIAS
- **Name**: `KEY_ALIAS`
- **Value**: `dalao`
- **说明**: 密钥别名

### 4. KEY_PASSWORD
- **Name**: `KEY_PASSWORD`
- **Value**: `dalao123456`
- **说明**: 密钥密码

## 🔧 如何添加 Secrets

1. 打开你的 GitHub 仓库
2. 点击 **Settings** (设置)
3. 在左侧菜单中找到 **Secrets and variables** → **Actions**
4. 点击 **New repository secret** 按钮
5. 依次添加上述 4 个 secrets

## ✅ 验证设置

添加完 Secrets 后：

1. **测试构建**: 进入 Actions 标签，手动触发 "Build APK" workflow
2. **查看日志**: 检查构建日志，确保签名步骤成功执行
3. **下载 APK**: 构建成功后，下载 APK 并验证签名

## 📝 注意事项

- Secrets 添加后不可查看，只能更新或删除
- 确保 `keystore.txt` 内容完整复制，不要有多余的空格或换行
- 如果构建失败，检查 Actions 日志中的错误信息
- 密钥信息非常重要，请妥善保管，不要泄露

## 🚀 工作流说明

### CI Workflow (ci.yml)
- 触发条件: 推送到 main/develop 分支或 PR
- 功能: 代码分析、格式检查、测试
- 不需要签名 Secrets

### Build Workflow (build.yml)
- 触发条件: 推送 tag 或手动触发
- 功能: 构建签名的 APK
- 需要签名 Secrets

### Release Workflow (release.yml)
- 触发条件: 推送 tag (如 v1.0.1)
- 功能: 创建 GitHub Release 并上传 APK
- 需要签名 Secrets

## 📦 发布新版本

1. 更新 `pubspec.yaml` 中的版本号
2. 提交代码并推送
3. 创建并推送 tag:
   ```bash
   git tag v1.0.2
   git push origin v1.0.2
   ```
4. GitHub Actions 会自动构建并创建 Release
