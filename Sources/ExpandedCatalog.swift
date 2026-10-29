import Foundation

let expandedFormulaNames = ["cmake": "cmake", "go": "go", "java": "openjdk@21", "maven": "maven", "postgresql": "postgresql@18", "mysql": "mysql", "redis": "redis", "sqlite": "sqlite"]
let expandedCaskNames = ["idea": "intellij-idea", "postman": "postman", "godot": "godot", "unity": "unity-hub", "blender": "blender", "dbeaver": "dbeaver-community", "figma": "figma", "firefox": "firefox"]
let expandedApplicationNames = ["idea": "IntelliJ IDEA.app", "postman": "Postman.app", "godot": "Godot.app", "unity": "Unity Hub.app", "blender": "Blender.app", "dbeaver": "DBeaver.app", "figma": "Figma.app", "firefox": "Firefox.app"]
let databaseServers: Set<String> = ["postgresql", "mysql", "redis"]

func brewPaths(_ binary: String, formulas: [String] = []) -> [String] {
    let prefixes = ["/opt/homebrew", "/usr/local"]
    return prefixes.flatMap { prefix in formulas.map { prefix + "/opt/" + $0 + "/bin/" + binary } + [prefix + "/bin/" + binary] }
}

let expandedComponents: [Component] = [
    .init(id: "idea", name: "IntelliJ IDEA", subtitle: "Java IDE；账号和功能授权由用户处理", icon: "chevron.left.forwardslash.chevron.right", groups: ["软件工程"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "postman", name: "Postman", subtitle: "API 开发与调试；不导入账号或接口凭据", icon: "network", groups: ["软件工程"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "cmake", name: "CMake", subtitle: "C / C++ 项目构建工具", icon: "hammer", groups: ["软件工程", "游戏开发"], dependencies: ["brew"], paths: brewPaths("cmake"), arguments: ["--version"]),
    .init(id: "go", name: "Go", subtitle: "Go 开发工具链", icon: "terminal", groups: ["软件工程"], dependencies: ["brew"], paths: brewPaths("go") + ["/usr/local/go/bin/go"], arguments: ["version"]),
    .init(id: "java", name: "Java JDK", subtitle: "默认安装 JDK 21；可选系列，不切换系统 JAVA_HOME", icon: "cup.and.saucer", groups: ["软件工程"], dependencies: ["brew"], paths: brewPaths("java", formulas: ["openjdk@21", "openjdk@17", "openjdk@25", "openjdk"]), arguments: ["--version"]),
    .init(id: "maven", name: "Maven", subtitle: "Java 项目构建；Homebrew 可能同时安装其 JDK 依赖", icon: "shippingbox", groups: ["软件工程"], dependencies: ["brew"], paths: brewPaths("mvn"), arguments: ["--version"]),
    .init(id: "godot", name: "Godot", subtitle: "2D / 3D 游戏引擎；项目由用户自行选择", icon: "gamecontroller", groups: ["游戏开发"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "unity", name: "Unity Hub", subtitle: "仅安装管理器；引擎、模块、许可在 Hub 内自行选择", icon: "gamecontroller", groups: ["游戏开发"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "blender", name: "Blender", subtitle: "3D 建模与游戏资源制作", icon: "cube", groups: ["游戏开发"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "postgresql", name: "PostgreSQL", subtitle: "默认 18 系列，可选 17；安装可能初始化数据目录，不自动启动", icon: "externaldrive", groups: ["数据库"], dependencies: ["brew"], paths: brewPaths("postgres", formulas: ["postgresql@18", "postgresql@17", "postgresql@16"]), arguments: ["--version"]),
    .init(id: "mysql", name: "MySQL", subtitle: "安装可能初始化默认数据目录；不自动迁移、设密码或启动", icon: "externaldrive", groups: ["数据库"], dependencies: ["brew"], paths: brewPaths("mysqld", formulas: ["mysql", "mysql@8.4"]), arguments: ["--version"]),
    .init(id: "redis", name: "Redis", subtitle: "内存数据库；不自动启动或开放端口", icon: "memorychip", groups: ["数据库"], dependencies: ["brew"], paths: brewPaths("redis-server"), arguments: ["--version"]),
    .init(id: "sqlite", name: "SQLite", subtitle: "轻量数据库；可复用 macOS 自带命令，不创建业务数据库", icon: "externaldrive", groups: ["数据库"], dependencies: ["brew"], paths: brewPaths("sqlite3", formulas: ["sqlite"]) + ["/usr/bin/sqlite3"], arguments: ["--version"]),
    .init(id: "dbeaver", name: "DBeaver Community", subtitle: "数据库图形客户端；连接信息由用户填写", icon: "tablecells", groups: ["数据库"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "figma", name: "Figma", subtitle: "界面设计与原型；账号和订阅由用户处理", icon: "paintbrush", groups: ["网页设计"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "firefox", name: "Firefox", subtitle: "HTML / CSS 预览与浏览器开发者工具", icon: "globe", groups: ["网页设计"], dependencies: ["brew"], paths: [], arguments: [])
]

func versionedFormulaPrefix(_ id: String) -> String { id == "java" ? "openjdk" : id }
func versionedBinary(_ id: String) -> String { ["java": "java", "postgresql": "postgres", "mysql": "mysqld"][id] ?? id }

func extraProbePaths(_ id: String) -> [String] {
    guard id == "java" else { return [] }
    let folders = [URL(fileURLWithPath: "/Library/Java/JavaVirtualMachines"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Java/JavaVirtualMachines")]
    return folders.flatMap { folder in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?.sorted { $0.path < $1.path }.map { $0.appendingPathComponent("Contents/Home/bin/java").path } ?? [] }
}

func expandedVersionOptions(_ id: String) -> [VersionOption]? {
    let series: [String]
    switch id {
    case "java": series = ["17", "21", "25"]
    case "postgresql": series = ["17", "18"]
    case "mysql": series = ["8.4"]
    default: return nil
    }
    let defaultLabel = id == "java" ? "优先复用；缺失时安装 JDK 21" : (id == "postgresql" ? "优先复用；缺失时安装 PostgreSQL 18" : "优先复用；缺失时安装源稳定版本")
    return [.init(id: "auto", label: defaultLabel)] + series.map { .init(id: $0, label: $0 + " 系列") }
}

func databaseReadiness(_ item: Component, probe: Probe) -> CheckItem {
    let folder = URL(fileURLWithPath: probe.path).deletingLastPathComponent()
    let command: String, arguments: [String], port: String
    switch item.id {
    case "postgresql": command = "pg_isready"; arguments = ["-h", "127.0.0.1", "-p", "5432", "-t", "2"]; port = "5432"
    case "mysql": command = "mysqladmin"; arguments = ["--no-defaults", "--connect-timeout=2", "--host=127.0.0.1", "--port=3306", "ping"]; port = "3306"
    default: command = "redis-cli"; arguments = ["-h", "127.0.0.1", "-p", "6379", "PING"]; port = "6379"
    }
    let executable = folder.appendingPathComponent(command).path
    guard FileManager.default.isExecutableFile(atPath: executable) else { return .init(id: item.id, title: item.name + " 服务", level: "warning", detail: "程序已安装，但未找到服务探测命令。不自动启动或迁移数据。") }
    let result = limitedProcess(executable, arguments, timeout: 4)
    let text = result.output.lowercased()
    let ready = result.code == 0 && (item.id != "redis" || text.trimmingCharacters(in: .whitespacesAndNewlines) == "pong") && !text.contains("access denied") && !text.contains("authentication")
    return .init(id: item.id, title: item.name + " 本机服务", level: ready ? "ok" : "warning", detail: ready ? "本机默认端口 \(port) 有服务响应；未验证服务端版本、账号权限或业务数据库。" : "安装已检测到，但默认端口 \(port) 未就绪或需要认证。不会自动启动、改密码或开放端口。\n" + String(result.output.prefix(500)))
}

func databaseDataCheck(_ directory: URL, name: String) -> CheckItem? {
    guard FileManager.default.fileExists(atPath: directory.path) else { return nil }
    guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
        return .init(id: "database-existing-data-" + name, title: name + " 数据目录无法确认", level: "blocked", detail: "无法读取 \(directory.path)。请先确认权限和现有数据，软件不会自动初始化此目录。")
    }
    guard !contents.isEmpty else { return nil }
    return .init(id: "database-existing-data-" + name, title: name + " 已有数据目录", level: "blocked", detail: "目标安装的数据目录非空：\(directory.path)。请先核对版本及备份，软件不会自动接管或迁移这些数据。")
}

func expandedCatalogTests() throws {
    let good = Probe(state: "已检测到", detail: "version", path: "/opt/homebrew/bin/brew")
    let missing = Probe(state: "未在常见位置发现", detail: "", path: "")
    for item in expandedComponents {
        let action = installAction(for: item, probes: [item.id: missing, "brew": good, "clt": good])
        guard case .install(let command) = action else { preconditionFailure("No install plan: " + item.id) }
        precondition(command.executable == good.path)
        precondition(!command.arguments.contains("services"))
        if let cask = expandedCaskNames[item.id] { precondition(command.arguments.last == "homebrew/cask/" + cask) }
        else { precondition(command.arguments.last == "homebrew/core/" + expandedFormulaNames[item.id]!) }
        precondition(installAction(for: item, probes: [item.id: good]) == .reuse)
    }
    let java = catalog.first { $0.id == "java" }!
    if case .install(let command) = installAction(for: java, probes: ["java": missing, "brew": good, "clt": good], selectedVersion: "17") { precondition(command.arguments.last == "homebrew/core/openjdk@17") } else { preconditionFailure("Invalid JDK version plan") }
    precondition(toolsForPurposes(["html-design"]) == ["vscode", "cursor", "figma", "firefox"])
    precondition(!toolsForPurposes(["html-design"]).contains("node"))
    precondition(!toolsForPurposes(["database"]).contains("unity"))
    let conflict = Probe(state: "版本冲突", detail: "MySQL data migration required", path: "/mock/mysqld")
    if case .blocked = installAction(for: catalog.first { $0.id == "mysql" }!, probes: ["mysql": conflict], selectedVersion: "8.4") {} else { preconditionFailure("Must not migrate MySQL automatically") }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("envsetup-db-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    precondition(databaseDataCheck(folder, name: "test") == nil)
    try Data("existing data".utf8).write(to: folder.appendingPathComponent("keep"))
    precondition(databaseDataCheck(folder, name: "test")?.level == "blocked")
    let mysqlAdmin = folder.appendingPathComponent("mysqladmin")
    try "#!/bin/sh\nprintf 'Access denied\\n'\nexit 0\n".write(to: mysqlAdmin, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: mysqlAdmin.path)
    let mysql = catalog.first { $0.id == "mysql" }!
    let ping = databaseReadiness(mysql, probe: .init(state: "已检测到", detail: "version", path: folder.appendingPathComponent("mysqld").path))
    precondition(ping.level == "warning")
    let scheme = ConfigurationScheme(schemaVersion: 1, name: "db", purposes: ["database"], customMode: false, tools: ["postgresql", "dbeaver"], versions: ["postgresql": "17"], projectVirtualEnvironment: false)
    let restored = try decodeScheme(JSONEncoder().encode(scheme))
    precondition(restored.versions["postgresql"] == "17")
    print("PASS: expanded install/reuse plans, JDK mapping, purpose isolation, database version scheme, no service start commands")
}
