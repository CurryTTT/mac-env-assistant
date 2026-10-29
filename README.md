# Mac Env Assistant · macOS 环境配置助手

使用 SwiftUI 构建的 macOS 开发环境配置助手。按用途浏览或自定义选择工具，检查已有环境与版本，确认安装计划后执行安装，并管理 Python 项目环境、Git 身份和可复用配置方案。

当前版本：**0.7.0，本机试用阶段**。

## 功能

- **按用途配置与自定义选择**：AI 编程、本地 AI、软件工程、游戏开发、数据库、网页 / HTML 设计、前端、Python、容器及嵌入式开发。
- **已有环境复用**：检测常见安装位置，所选版本可用时直接复用；必要依赖自动合并，不自动勾选整套软件。
- **版本选择**：支持部分 Python、Node.js、pnpm、JDK、PostgreSQL 和 MySQL 版本系列。
- **安装前检查**：已知版本与入口冲突、空间、项目目录及常用下载服务连通性。
- **Python 项目隔离**：创建或复用 `.venv`，检查解释器、SSL 和 pip，不覆盖冲突或未知目录。
- **运行状态验证**：区分安装状态与 Docker、Ollama、数据库服务状态；不自动启动服务或登录账号。
- **Git 配置**：用户填写姓名与邮箱、选择用户级或项目级范围，预览后保存，支持备份恢复及并发修改保护。
- **配置方案**：保存和导入 JSON，复用工具、版本系列及项目环境选项，不携带账号凭据或项目绝对路径。
- **macOS 原生布局**：标准侧栏、分组表单、原生列表、工具栏及系统外观。

## 可选软件

| 用途 | 示例 |
|---|---|
| AI 编程 | Codex CLI、Claude Code、Cursor、VS Code |
| 软件工程 | IntelliJ IDEA、Postman、CMake、Go、Java JDK、Maven |
| 游戏开发 | Godot、Unity Hub、Blender |
| 数据库 | PostgreSQL、MySQL、Redis、SQLite、DBeaver Community |
| 网页设计 | VS Code、Cursor、Figma、Firefox |
| 本地 AI / Python | Ollama、Python、uv |
| 前端 / 容器 / 嵌入式 | Node.js、pnpm、Docker Desktop、Arduino IDE、PlatformIO Core |

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

任务记录和日志保存在 `~/Library/Application Support/EnvSetupAssistant/`，Git 备份位于其 `GitBackups/` 子目录。下载的 Homebrew 引导包在 `~/Library/Caches/EnvSetupAssistant/Packages/`。应用不上传这些日志和备份；分享日志前请检查个人路径及其他配置内容。

## 项目结构

`Sources/` 包含 SwiftUI 界面、组件安装与检测、版本规划、项目环境、配置方案和测试入口。`Info.plist` 为应用元数据，`build.sh` 与 `test.sh` 提供本地构建和验证。

项目尚未指定开源许可证。第三方软件分别遵循其自身许可。
