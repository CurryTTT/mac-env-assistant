# 环境配置助手 · Windows 版

Windows 首个试用版 **0.1.0**，使用 C# / Windows Forms 实现。与 macOS 原生版本共用仓库，Windows 安装逻辑单独实现。

## 下载与使用

[Windows Release](https://github.com/CurryTTT/mac-env-assistant/releases/tag/windows-v0.1.0)

下载 `EnvAssistant-v0.1.0-Windows-x64.exe`，放在本地文件夹，双击运行。单文件包含 .NET 运行库，无需另外安装 .NET；首次运行会把必要运行文件解压到系统临时目录。

面向 Windows 10 / 11 x64，需要可用的微软 WinGet / App Installer；建议先在 Windows 11 上试用。不支持在 macOS 中直接运行。没有代码签名，Windows 可能提示未知发布者；不应通过关闭系统防护解决。

1. 按用途筛选，自己勾选软件。筛选不会自动勾选。
2. 允许 WinGet 联网查询，点击“检测所选软件”。
3. 如需指定版本，选中对应行，点击“查询当前行版本”，再选择具体版本。
4. 查看安装计划并确认。已有匹配版本直接复用，其他已安装版本不自动切换。
5. 留意第三方安装器的许可、管理员权限和重启提示，结束后查看日志。

如果 WinGet 首次使用提示源协议需要确认，请在 Windows 终端运行 `winget list --source winget`，阅读协议并自行决定，然后返回软件重新检测。本软件不会代为接受源协议或第三方软件许可。

## 首批 28 项

Git、VS Code、Cursor、GitHub Desktop、GitHub CLI、Python 3.12 / 3.13、Node.js LTS、uv、Go、Microsoft OpenJDK 21、Rustup、Ollama、Docker Desktop、Postman、Bruno、DBeaver Community、DB Browser for SQLite、PostgreSQL 17、Godot、Unity Hub、Blender、Arduino IDE、CMake、Ninja、Firefox、PowerShell、Windows Terminal。

ID 已核对到微软 [winget-pkgs 清单](https://github.com/microsoft/winget-pkgs/tree/master/manifests)。当前清单不保证任意历史版本都仍可下载，第三方包所需的依赖由 WinGet 和安装器处理。WSL、GPU、SDK、游戏引擎、模型、登录及数据库服务需另行配置。

## 其他功能

- 保存 / 导入配置方案：仅软件 ID 与版本，导入后必须重新检测。
- 安装前逐项重新检测，未知查询结果阻断安装；失败即停止后续任务，不自动重试。
- 安装后再次查询，区分“安装器成功退出”和“检测到所选版本”。
- 完成当前项后停止，不提供强制中断安装器或自动回滚。
- Python 项目：用户指定解释器和项目目录，创建 `.venv`，检查解释器、SSL 和 pip；已有目录不覆盖。
- 日志在当前会话中保留，可手动导出；本版尚未移植 macOS 的 Git 身份管理、安装历史和服务运行验证。

WinGet 查询只能识别其匹配到的安装；自定义目录、便携版、其他管理器可能未识别。未匹配到前应由用户再次核对。检测成功不代表首次启动、服务或项目依赖已经就绪。

## 构建与验证

需要 .NET 10 SDK：

```powershell
dotnet run --project Tests/CoreTests.csproj -c Release
dotnet publish EnvAssistant.Windows.csproj -c Release -r win-x64 --self-contained true -o dist
```

也可在 Windows 执行 `build.ps1`，生成命名后的 EXE 和 SHA256 校验文件。项目启用 Windows 目标支持，可在其他平台交叉编译。单文件部署方式见 [微软文档](https://learn.microsoft.com/dotnet/core/deploying/single-file/)。WinGet 命令见微软 [list](https://learn.microsoft.com/windows/package-manager/winget/list) / [install](https://learn.microsoft.com/windows/package-manager/winget/install) 文档。

核心回归测试使用模拟查询和安装，不安装第三方软件，覆盖查询解析、失败阻断、精确版本复用、方案校验、参数传递、执行前复查、安装后验证及停止。当前交付在 macOS 交叉编译；尚未完成 Windows 实机 GUI、真实 WinGet 安装、UAC、重启和不同缩放比例的验证。
