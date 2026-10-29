# v0.9.0 · 开发工具与安装历史试用版

- 新增 20 个常用编程工具，清单共 51 项：PyCharm、WebStorm、CLion、Android Studio、Zed、Sublime Text、iTerm2、GitHub Desktop、Bruno、Insomnia、TablePlus、GitHub CLI、jq、ripgrep、fd、fzf、tmux、ShellCheck、Ninja、Gradle。
- 增加 Android 开发、终端效率、API 调试用途，以及类别过滤和搜索；用户逐项勾选，不自动整套安装。
- 新增最近 20 次安装历史，显示当时选择、失败提示、日志和运行验证；载入后重新检测并由用户确认安装。
- 每次任务独立保留所选版本和项目选项，避免当前界面或保存失败影响后续验证；兼容旧的单记录格式。
- 运行验证保存时间戳，历史结果明确标记；提供用户主动打开应用、复制 Ollama 服务启动命令或查看 Python 项目目录的入口。

适用于 Apple Silicon、macOS 14+；Homebrew 首次引导要求 macOS 15+。第三方软件的账号、许可、SDK、模拟器和首次设置由用户处理。

仍为临时签名试用版，未完成 Apple 公证，首次启动可能被系统拦截。新增软件仅核对 Homebrew 安装清单并测试安装规划，未逐项真实在线安装。DMG 和界面仍需实机核对。测试不会替用户安装这些工具、启动服务或修改 Git 身份。
