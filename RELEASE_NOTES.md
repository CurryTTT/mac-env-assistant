# v0.10.0 · 已有环境识别改进试用版

- 修复第一个入口损坏或无法响应时漏掉其他正常安装的问题；逐个检查候选入口并复用可用安装。
- 扩展用户与系统 Applications 的有限层级、JetBrains Toolbox 常见目录识别，支持部分 JetBrains 社区版与版本后缀。
- 增加 nvm、pyenv、Volta 常见运行时目录及其目录环境变量支持，按用户选择匹配 Python / Node.js 版本系列。
- 显示实际采用路径；检测版本管理器目录不代表终端当前默认版本，不切换默认版本或运行管理器安装钩子。
- 只发现损坏应用时保留路径并阻止自动覆盖；应用检测与首次启动、许可及 Apple 签名验证分别说明。
- 增加第七组回归测试，使用临时目录验证回退、边界和复用。

清单仍为 51 项，由用户选择；适用于 Apple Silicon、macOS 14+。Homebrew 首次引导要求 macOS 15+。

仍为临时签名试用版，未完成 Apple 公证，首次启动可能被系统拦截。未逐项在线安装第三方工具，也未完成 GUI / DMG 的实机外观核对。检测不覆盖任意自定义目录和所有版本管理器，详见 DISCOVERY.md。

---

# v0.9.0 · 开发工具与安装历史试用版

- 新增 20 个常用编程工具，清单共 51 项：PyCharm、WebStorm、CLion、Android Studio、Zed、Sublime Text、iTerm2、GitHub Desktop、Bruno、Insomnia、TablePlus、GitHub CLI、jq、ripgrep、fd、fzf、tmux、ShellCheck、Ninja、Gradle。
- 增加 Android 开发、终端效率、API 调试用途，以及类别过滤和搜索；用户逐项勾选，不自动整套安装。
- 新增最近 20 次安装历史，显示当时选择、失败提示、日志和运行验证；载入后重新检测并由用户确认安装。
- 每次任务独立保留所选版本和项目选项，避免当前界面或保存失败影响后续验证；兼容旧的单记录格式。
- 运行验证保存时间戳，历史结果明确标记；提供用户主动打开应用、复制 Ollama 服务启动命令或查看 Python 项目目录的入口。

适用于 Apple Silicon、macOS 14+；Homebrew 首次引导要求 macOS 15+。第三方软件的账号、许可、SDK、模拟器和首次设置由用户处理。

仍为临时签名试用版，未完成 Apple 公证，首次启动可能被系统拦截。新增软件仅核对 Homebrew 安装清单并测试安装规划，未逐项真实在线安装。DMG 和界面仍需实机核对。测试不会替用户安装这些工具、启动服务或修改 Git 身份。
