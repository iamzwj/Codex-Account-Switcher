# Codex Desktop 多账号启动器

在 macOS 上为每个 ChatGPT 账号建立一个独立的 Codex Desktop 配置。第一次打开时，在原版 App 中通过浏览器登录。以后打开同一配置，App 会复用自己保存的会话。OpenAI 要求验证码、SSO 或其他验证时，照常完成。

## 使用

需要 macOS、Python 3 和支持独立数据目录的原版 ChatGPT Desktop 或 Codex Desktop。默认使用 `/Applications/ChatGPT.app`。

在 Finder 双击 **Codex 账号切换.app**。点击「添加账号」，输入好辨认的名称或邮箱。随后点该账号卡片的「切换」，在 Codex 中完成首次浏览器登录。已有配置会自动列出。Codex 正在运行时，确认「退出并切换」，工具会请求正常退出并重新打开 Codex。

随项目提供的 App 可直接使用。要从源码重建，运行 `./build-app.sh`。

命令行方式

在项目目录打开终端，先等正在运行的任务结束，再按 **⌘Q** 完全退出 ChatGPT Desktop。执行：

```sh
./codex-accounts open personal
```

首次打开时，在 App 中选择通过 ChatGPT 登录，在浏览器里确认登录的是个人账号，然后返回 App 检查账号菜单。配置名只是本地标签。浏览器若已登录另一账号，请在官方登录页面选择正确的账号。

新增工作账号或切回个人账号时，每次先按 **⌘Q**。然后运行对应命令：

```sh
./codex-accounts open work
./codex-accounts open personal
./codex-accounts list
```

独立安装的 Codex 可以指定路径：

```sh
./codex-accounts --app /Applications/Codex.app open work
```

- **切换配置需要重新打开 App。** 启动器检测到 App 已在运行时会提示退出。关闭窗口通常不足以退出。普通 Dock 图标用于打开默认配置。
- **当前配置重新授权通常可以在 App 内完成。** 看到登录提示时，在当前配置中走浏览器登录。若 App 要求退出登录，先在该配置里退出账号，再登录同一账号。App 自行刷新仍有效的会话。
- **列出配置无须退出 App。** 列表显示本地名称。授权是否仍然有效由 App 和服务端判断。

## 认证和数据

每个配置位于 `~/Library/Application Support/Codex Accounts/<名称>/`，包含权限为 700 的 `desktop/` 和 `codex/`。前者由桌面 App 管理其本地状态，后者用于 Codex 配置、认证和会话等。新配置将 Codex CLI 的认证存储设为 macOS 钥匙串。桌面 App 自身的会话由 App 管理。启动器仅创建配置目录与初始设置，不读取或复制 Cookie、令牌或原有 `~/.codex/auth.json`。应将这些配置目录作为本机私有数据保管。

本机安装的 ChatGPT Desktop 26.1117.41037 使用标识 `com.openai.codex`。在安装包内确认它识别 `CODEX_ELECTRON_USER_DATA_PATH` 来指定桌面数据目录，并在同时指定该变量时保留 `CODEX_HOME`。后者是公开的 Codex 状态目录选项。桌面隔离入口属于当前客户端实现，升级后需复验。公开的 ChatGPT 原生账号切换文档目前列出 Web、iOS 和 Android。

官方资料

- [登录与凭据存储](https://learn.chatgpt.com/docs/auth?surface=cli)
- [Codex 环境变量](https://learn.chatgpt.com/docs/config-file/environment-variables)
- [ChatGPT 账号切换支持范围](https://help.openai.com/en/articles/20001068-using-multiple-chatgpt-accounts-on-web-and-mobile)

## 测试

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v
```

测试覆盖配置名、目录权限和隔离、配置保留、符号链接拒绝、应用运行时阻止切换，以及传给 macOS 的启动参数。真实账号验收按上面的流程登录个人和工作账号，再切回个人账号，检查账号菜单和会话能否复用。当前执行环境的 LaunchServices 启动检查返回 `-10827`，真实浏览器回调、两账号会话复用和重新授权尚未验证。

切换到独立账号时，启动器会把原有配置里的本机项目目录补充到该账号的 Codex 侧栏。各账号打开的是同一份磁盘上的项目文件，已有项目会保留。云端项目、旧聊天、账号绑定和认证仍由各自账号管理。
