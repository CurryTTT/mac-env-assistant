import Foundation

struct SetupPurpose: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let tools: Set<String>
}

let setupPurposes: [SetupPurpose] = [
    .init(id: "ai-code", title: "AI 编程", detail: "按需选择 Codex CLI、Claude Code、Cursor 等", icon: "sparkles", tools: ["codex", "claude", "cursor", "vscode", "git"]),
    .init(id: "local-ai", title: "本地 AI", detail: "本地模型工具与可选 Python 环境", icon: "desktopcomputer", tools: ["ollama", "python", "uv"]),
    .init(id: "web", title: "前端开发", detail: "Node.js、包管理与代码编辑器", icon: "curlybraces", tools: ["node", "pnpm", "vscode", "git", "webstorm", "zed"]),
    .init(id: "python", title: "Python 开发", detail: "选择解释器版本与依赖管理工具", icon: "terminal", tools: ["python", "uv", "vscode", "git", "pycharm"]),
    .init(id: "containers", title: "容器开发", detail: "按需安装 Docker Desktop", icon: "shippingbox", tools: ["docker"]),
    .init(id: "embedded", title: "嵌入式开发", detail: "Arduino IDE 或 PlatformIO；板卡由你选择", icon: "cpu", tools: ["arduino", "platformio", "vscode", "git", "clion", "cmake", "ninja"]),
    .init(id: "basic", title: "基础工具", detail: "仅配置命令行基础工具", icon: "hammer", tools: ["git", "brew", "clt"]),
    .init(id: "software-engineering", title: "软件工程", detail: "IDE、API 调试、Java / Go 与构建工具", icon: "wrench.and.screwdriver", tools: ["vscode", "git", "idea", "postman", "java", "maven", "go", "cmake", "gradle", "clion", "github-desktop", "gh", "bruno", "insomnia"]),
    .init(id: "game-development", title: "游戏开发", detail: "游戏引擎、管理器与 3D 资源制作", icon: "gamecontroller", tools: ["godot", "unity", "blender", "vscode", "git", "cmake"]),
    .init(id: "database", title: "数据库", detail: "选择数据库与图形客户端，不自动启动服务", icon: "externaldrive", tools: ["postgresql", "mysql", "redis", "sqlite", "dbeaver", "tableplus"]),
    .init(id: "html-design", title: "网页 / HTML 设计", detail: "编辑器、界面设计与浏览器预览", icon: "paintbrush", tools: ["vscode", "cursor", "figma", "firefox", "sublime-text"]),
    .init(id: "mobile", title: "Android 开发", detail: "选择 IDE 和构建工具；SDK 与模拟器自行配置", icon: "iphone", tools: ["android-studio", "java", "gradle", "git"]),
    .init(id: "terminal", title: "终端效率", detail: "终端、搜索与脚本工具；不改写 shell 配置", icon: "terminal", tools: ["iterm2", "jq", "ripgrep", "fd", "fzf", "tmux", "shellcheck"]),
    .init(id: "api", title: "API 调试", detail: "按需选择 API 客户端，不导入凭据", icon: "network", tools: ["postman", "bruno", "insomnia"])
]

func toolsForPurposes(_ ids: Set<String>) -> Set<String> {
    setupPurposes.filter { ids.contains($0.id) }.reduce(into: Set<String>()) { $0.formUnion($1.tools) }
}

func friendlyAction(_ item: Component, action: InstallAction?, probe: Probe?, version: String) -> String {
    switch action {
    case .reuse: return "使用已安装版本" + (versionString(probe).map { " " + $0 } ?? "") + "，无需下载"
    case .install: return "安装 " + item.name + (version == "auto" ? " 的当前稳定版本" : " " + version + " 系列")
    case .bootstrap: return "需要先安装此基础工具（系统安装器）"
    case .awaitingPrerequisite: return "基础工具就绪后安装"
    case .blocked(let reason): return "需要处理：" + reason
    case nil: return "正在准备计划"
    }
}

func purposeSelfTests() {
    precondition(toolsForPurposes(["containers"]) == ["docker"])
    precondition(!toolsForPurposes(["ai-code"]).contains("docker"))
    precondition(!toolsForPurposes(["ai-code"]).contains("python"))
    precondition(!toolsForPurposes(["embedded"]).contains("codex"))
    for purpose in setupPurposes { precondition(purpose.tools.isSubset(of: Set(catalog.map(\.id)))) }
    let good = Probe(state: "已检测到", detail: "version", path: "/opt/homebrew/bin/brew")
    let absent = Probe(state: "未在常见位置发现", detail: "", path: "")
    for id in ["codex", "claude", "cursor", "docker"] {
        let item = catalog.first { $0.id == id }!
        let action = installAction(for: item, probes: [id: absent, "brew": good, "clt": good])
        guard case .install(let command) = action else { preconditionFailure("Missing cask plan") }
        precondition(command.arguments.contains("--cask"))
        precondition(command.arguments.last == "homebrew/cask/" + caskNames[id]!)
        if ["codex", "claude"].contains(id) { precondition(!command.arguments.contains { $0.hasPrefix("--appdir=") }) }
        precondition(installAction(for: item, probes: [id: good]) == .reuse)
    }
    print("PASS: purpose relevance, no unrelated tools, complete catalog references")
}
