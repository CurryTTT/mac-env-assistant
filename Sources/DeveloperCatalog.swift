import Foundation

// Install identifiers and application names checked against Homebrew Formulae.
let developerCaskNames = ["pycharm": "pycharm", "webstorm": "webstorm", "clion": "clion", "android-studio": "android-studio", "zed": "zed", "sublime-text": "sublime-text", "iterm2": "iterm2", "github-desktop": "github", "bruno": "bruno", "insomnia": "insomnia", "tableplus": "tableplus"]
let developerApplicationNames = ["pycharm": "PyCharm.app", "webstorm": "WebStorm.app", "clion": "CLion.app", "android-studio": "Android Studio.app", "zed": "Zed.app", "sublime-text": "Sublime Text.app", "iterm2": "iTerm.app", "github-desktop": "GitHub Desktop.app", "bruno": "Bruno.app", "insomnia": "Insomnia.app", "tableplus": "TablePlus.app"]
let developerFormulaNames = ["gh": "gh", "jq": "jq", "ripgrep": "ripgrep", "fd": "fd", "fzf": "fzf", "tmux": "tmux", "shellcheck": "shellcheck", "ninja": "ninja", "gradle": "gradle"]

let developerComponents: [Component] = [
    .init(id: "pycharm", name: "PyCharm", subtitle: "Python IDE；功能授权和账号由用户自行选择", icon: "chevron.left.forwardslash.chevron.right", groups: ["Python", "软件工程"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "webstorm", name: "WebStorm", subtitle: "JavaScript / TypeScript IDE；许可由用户处理", icon: "curlybraces", groups: ["前端", "软件工程"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "clion", name: "CLion", subtitle: "C / C++ IDE；工具链与项目由用户自行配置", icon: "hammer", groups: ["嵌入式", "软件工程"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "android-studio", name: "Android Studio", subtitle: "Android IDE；SDK、模拟器与许可在首次启动时自行选择", icon: "iphone", groups: ["移动开发"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "zed", name: "Zed", subtitle: "代码编辑器；扩展与 AI 账号按需设置", icon: "chevron.left.forwardslash.chevron.right", groups: ["开发软件"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "sublime-text", name: "Sublime Text", subtitle: "轻量代码编辑器；许可由用户处理", icon: "doc.text", groups: ["开发软件", "网页设计"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "iterm2", name: "iTerm2", subtitle: "终端应用；不替换默认终端或改写 shell 配置", icon: "terminal", groups: ["终端工具"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "github-desktop", name: "GitHub Desktop", subtitle: "Git 图形客户端；不自动登录账号或克隆仓库", icon: "arrow.triangle.branch", groups: ["软件工程"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "bruno", name: "Bruno", subtitle: "API 调试工具；不导入接口密钥或集合", icon: "network", groups: ["API 调试"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "insomnia", name: "Insomnia", subtitle: "HTTP / GraphQL 调试；账号与工作区由用户配置", icon: "network", groups: ["API 调试"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "tableplus", name: "TablePlus", subtitle: "数据库客户端；连接信息与许可由用户处理", icon: "tablecells", groups: ["数据库"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "gh", name: "GitHub CLI", subtitle: "GitHub 命令行工具；不自动执行登录", icon: "terminal", groups: ["软件工程"], dependencies: ["brew"], paths: brewPaths("gh"), arguments: ["--version"]),
    .init(id: "jq", name: "jq", subtitle: "JSON 查询与格式处理", icon: "terminal", groups: ["终端工具"], dependencies: ["brew"], paths: brewPaths("jq"), arguments: ["--version"]),
    .init(id: "ripgrep", name: "ripgrep", subtitle: "快速搜索代码内容，命令为 rg", icon: "terminal", groups: ["终端工具"], dependencies: ["brew"], paths: brewPaths("rg"), arguments: ["--version"]),
    .init(id: "fd", name: "fd", subtitle: "快速文件查找工具", icon: "terminal", groups: ["终端工具"], dependencies: ["brew"], paths: brewPaths("fd"), arguments: ["--version"]),
    .init(id: "fzf", name: "fzf", subtitle: "命令行模糊搜索；不改写 shell 初始化文件", icon: "terminal", groups: ["终端工具"], dependencies: ["brew"], paths: brewPaths("fzf"), arguments: ["--version"]),
    .init(id: "tmux", name: "tmux", subtitle: "终端会话管理；不自动创建会话或后台服务", icon: "terminal", groups: ["终端工具"], dependencies: ["brew"], paths: brewPaths("tmux"), arguments: ["-V"]),
    .init(id: "shellcheck", name: "ShellCheck", subtitle: "Shell 脚本静态检查", icon: "terminal", groups: ["终端工具"], dependencies: ["brew"], paths: brewPaths("shellcheck"), arguments: ["--version"]),
    .init(id: "ninja", name: "Ninja", subtitle: "CMake 等项目可用的构建工具", icon: "terminal", groups: ["软件工程", "嵌入式"], dependencies: ["brew"], paths: brewPaths("ninja"), arguments: ["--version"]),
    .init(id: "gradle", name: "Gradle", subtitle: "Java / Kotlin 构建工具；安装源可能附带 JDK 依赖", icon: "terminal", groups: ["软件工程", "移动开发"], dependencies: ["brew"], paths: brewPaths("gradle"), arguments: ["--version"])
]

func developerCatalogTests() {
    precondition(Set(catalog.map(\.id)).count == catalog.count)
    let good = Probe(state: "已检测到", detail: "1.0", path: "/mock/brew")
    let missing = Probe(state: "未在常见位置发现", detail: "", path: "")
    for item in developerComponents {
        guard case .install(let command) = installAction(for: item, probes: [item.id: missing, "brew": good, "clt": good]) else { preconditionFailure("Missing developer tool install plan") }
        precondition(command.arguments.last == (developerCaskNames[item.id].map { "homebrew/cask/" + $0 } ?? "homebrew/core/" + developerFormulaNames[item.id]!))
        if developerApplicationNames[item.id] != nil { precondition(command.arguments.contains { $0.hasPrefix("--appdir=") }) }
        precondition(installAction(for: item, probes: [item.id: good]) == .reuse)
    }
    precondition(catalog.first { $0.id == "ripgrep" }?.paths.contains("/opt/homebrew/bin/rg") == true)
    precondition(catalog.first { $0.id == "tmux" }?.arguments == ["-V"])
    precondition(toolsForPurposes(["api"]) == ["postman", "bruno", "insomnia"])
    precondition(!toolsForPurposes(["terminal"]).contains("android-studio"))
    precondition(!toolsForPurposes(["python"]).contains("java"))
    print("PASS: 20 developer tool install/reuse plans, application directories, command names, unique catalog IDs and purpose isolation")
}
