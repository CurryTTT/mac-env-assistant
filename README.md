# Mac Env Assistant · macOS 环境配置助手

使用 SwiftUI 构建的 macOS 开发环境配置助手。按用途浏览或自定义选择工具，检查已有环境与版本，确认安装计划后执行安装，并管理 Python 项目环境、Git 身份和可复用配置方案。选择页面支持类别过滤和搜索。

当前版本：**0.10.0，本机试用阶段**。

## 下载

[下载 v0.10.0 DMG](https://github.com/CurryTTT/mac-env-assistant/releases/download/v0.10.0/MacEnvAssistant-v0.10.0-macOS-arm64.dmg) · [Release 页面](https://github.com/CurryTTT/mac-env-assistant/releases/tag/v0.10.0)

适用于 Apple Silicon、macOS 14 及以上。打开 DMG，将应用拖入 Applications。当前仅有临时签名，尚未经过 Apple 公证。

## 功能

- **按用途配置与自定义选择**：AI 编程、本地 AI、软件工程、游戏开发、数据库、网页 / HTML 设计、前端、Python、容器及嵌入式开发。
- **失败处理**：按安装日志提供网络、空间、权限、校验、文件冲突等排查提示；重新检测后生成新计划，已有可用工具优先复用，不自动重复执行失败命令。
- **安装历史**：本机保留最近 20 次任务，查看当时选择、结果、失败提示及运行验证；载入后重新检测，不直接安装。
- **已有环境复用**：逐个检查候选入口，优先复用可用安装；支持 Applications 有限层级、JetBrains Toolbox 常见目录及 nvm / pyenv / Volta 的部分运行时目录。显示实际使用路径，保留损坏安装的处理提示。覆盖范围见 [DISCOVERY.md](DISCOVERY.md)。
- **版本选择**：支持部分 Python、Node.js、pnpm、JDK、PostgreSQL 和 MySQL 版本系列。
- **安装前检查**：已知版本与入口冲突、空间、项目目录及常用下载服务连通性。
- **Python 项目隔离**：创建或复用 `.venv`，检查解释器、SSL 和 pip，不覆盖冲突或未知目录。
- **运行状态验证**：区分安装状态与 Docker、Ollama、数据库服务状态；不自动启动服务或登录账号。
- **Git 配置**：用户填写姓名与邮箱、选择用户级或项目级范围，预览后保存，支持备份恢复及并发修改保护。
- **配置方案**：保存和导入 JSON，复用工具、版本系列及项目环境选项，不携带账号凭据或项目绝对路径。
- **macOS 原生布局**：标准侧栏、分组表单、原生列表、工具栏及系统外观。

## 可选软件

当前清单包含 51 个工具及基础组件，新增 20 个常用开发工具，安装来源见 [CATALOG_SOURCES.md](CATALOG_SOURCES.md)。新增工具默认只提供安装源当前版本，不承诺任意历史版本。

| 用途 | 示例 |
|---|---|
| AI 编程 | Codex CLI、Claude Code、Cursor、VS Code |
| 软件工程 | IntelliJ IDEA、PyCharm、WebStorm、CLion、Postman、Bruno、Insomnia、GitHub Desktop、GitHub CLI、CMake、Ninja、Go、Java JDK、Maven、Gradle |
| 游戏开发 | Godot、Unity Hub、Blender |
| 数据库 | PostgreSQL、MySQL、Redis、SQLite、DBeaver Community、TablePlus |
| 网页设计 | VS Code、Cursor、Zed、Sublime Text、Figma、Firefox |
| 本地 AI / Python | Ollama、Python、uv |
| 前端 / 容器 / 嵌入式 | Node.js、pnpm、Docker Desktop、Arduino IDE、PlatformIO Core |
| Android 开发 | Android Studio；SDK、模拟器和许可自行选择 |
| 终端效率 | iTerm2、jq、ripgrep、fd、fzf、tmux、ShellCheck |

第三方软件的订阅、许可、登录、引擎版本和首次启动设置由用户在对应产品中处理。

## 构建与运行

要求 macOS、Xcode 或可用的 Swift 编译工具。当前构建与测试以 Apple Silicon 为主；部署目标为 macOS 14。Homebrew 首次安装引导要求 macOS 15 及以上。

```bash
bash build.sh
open dist/MacEnvAssistant.app
```

构建产物采用本地临时签名，尚未完成公众分发签名和公证。`dist/` 和构建缓存不纳入源码。

## 验证

```bash
bash test.sh
```

验证涵盖安装计划、版本复用、用途隔离、配置方案、临时项目中的真实虚拟环境创建与复用、Git 配置备份恢复、超时处理，以及用模拟 CLI 区分服务可用性。测试不会安装清单里的第三方软件、启动数据库或修改用户的 Git 身份信息。详见 [TESTING.md](TESTING.md)。

## 使用边界

- 检测覆盖常见位置，不保证识别所有自定义安装或第三方版本管理器。
- 版本选择表示受支持系列；安装源的可用补丁版本可能变化，不是完整依赖锁文件。
- Homebrew 可能调整依赖；数据库配方可能初始化默认数据目录。发现已有 PostgreSQL / MySQL 目标数据目录时会阻断，不自动迁移数据或设置密码。
- 不提供完整自动回滚，不自动切换系统 PATH 或 JAVA_HOME，不自动执行项目业务代码。
- 网络检查不保证所有最终文件可下载；服务响应不代表账号权限和业务项目均已验证。
- 新增软件尚未逐项完成完整在线安装测试；原生界面尚需继续在实际窗口核对布局与不同系统外观。

## 本地数据

任务记录和日志保存在 `~/Library/Application Support/EnvSetupAssistant/`，Git 备份位于其 `GitBackups/` 子目录。下载的 Homebrew 引导包在 `~/Library/Caches/EnvSetupAssistant/Packages/`。最近 20 次任务归档保存在 `Runs/` 子目录，单个任务状态更新沿用同一编号；运行验证带时间戳，历史结果不代表当前可用性。应用不上传这些日志和备份；分享日志前请检查个人路径及其他配置内容。

## 项目结构

`Sources/` 包含 SwiftUI 界面、组件安装与检测、版本规划、项目环境、配置方案和测试入口。`Info.plist` 为应用元数据，`build.sh` 与 `test.sh` 提供本地构建和验证。

项目尚未指定开源许可证。第三方软件分别遵循其自身许可。

## 打包与正式签名

拖拽安装包、Developer ID 签名和公证流程见 [Packaging/README.md](Packaging/README.md)。本机暂无可用签名证书，v0.10.0 仍为临时签名试用版，不能保证直接通过 Gatekeeper。
