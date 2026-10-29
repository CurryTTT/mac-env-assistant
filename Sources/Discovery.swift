import Foundation

struct DiscoveryContext {
    var home: URL
    var applicationRoots: [URL]
    var toolboxRoots: [URL]
    var environment: [String: String]
    static var live: DiscoveryContext {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return .init(home: home, applicationRoots: [home.appendingPathComponent("Applications"), URL(fileURLWithPath: "/Applications")], toolboxRoots: [home.appendingPathComponent("Library/Application Support/JetBrains/Toolbox/apps")], environment: ProcessInfo.processInfo.environment)
    }
    func expand(_ path: String) -> String {
        path.hasPrefix("~/") ? home.appendingPathComponent(String(path.dropFirst(2))).path : path
    }
}

func uniqueDiscoveryPaths(_ paths: [String]) -> [String] {
    var seen = Set<String>()
    return paths.filter { seen.insert(URL(fileURLWithPath: $0).resolvingSymlinksInPath().path).inserted }
}

// Never scan projects or the entire home directory; stop at app bundles,
// avoid directory symlinks and bound both depth and entries visited.
func discoverAppBundles(root: URL, depth: Int, limit: Int = 400) -> [String] {
    var remaining = limit, apps = [String]()
    func visit(_ folder: URL, depth: Int) {
        guard depth >= 0, remaining > 0,
              let children = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { return }
        for child in children.sorted(by: { $0.path.localizedStandardCompare($1.path) == .orderedAscending }) {
            guard remaining > 0 else { return }; remaining -= 1
            if child.pathExtension.lowercased() == "app" { apps.append(child.path); continue }
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if depth > 0, values?.isDirectory == true, values?.isSymbolicLink != true { visit(child, depth: depth - 1) }
        }
    }
    visit(root, depth: depth)
    return apps
}

let jetBrainsTools: Set<String> = ["idea", "pycharm", "webstorm", "clion"]
func appFilenameMatches(_ path: String, id: String) -> Bool {
    let filename = URL(fileURLWithPath: path).lastPathComponent
    guard let canonical = applicationNames[id] else { return false }
    if filename.caseInsensitiveCompare(canonical) == .orderedSame { return true }
    let aliases = ["idea": ["IntelliJ IDEA CE.app"], "pycharm": ["PyCharm CE.app"]]
    if aliases[id]?.contains(where: { filename.caseInsensitiveCompare($0) == .orderedSame }) == true { return true }
    guard jetBrainsTools.contains(id) else { return false }
    // Toolbox may retain a version suffix. Require digits after a space,
    // rather than matching arbitrary applications that share a prefix.
    let stem = String(canonical.dropLast(4))
    let pattern = "^" + NSRegularExpression.escapedPattern(for: stem) + #" [0-9][0-9. -]*\.app$"#
    return filename.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

func applicationCandidates(id: String, context: DiscoveryContext, discovered: [String]) -> [String] {
    guard let name = applicationNames[id] else { return [] }
    let direct = context.applicationRoots.map { $0.appendingPathComponent(name).path }
    return uniqueDiscoveryPaths(direct + discovered.filter { appFilenameMatches($0, id: id) })
}

func probeApplication(_ item: Component, candidates: [String]) -> Probe {
    var firstExisting: String?
    for path in candidates where FileManager.default.fileExists(atPath: path) {
        if firstExisting == nil { firstExisting = path }
        guard let bundle = Bundle(path: path), let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else { continue }
        return .init(state: "已检测到", detail: item.name + " " + (bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "版本未知") + "\n应用包及主程序存在；未验证首次启动、许可或签名。", path: path)
    }
    if let firstExisting { return .init(state: "需要检查", detail: "发现应用目录，但未找到可用主程序。请核对安装完整性；软件不会直接覆盖。", path: firstExisting) }
    return .init(state: "未在常见位置发现", detail: "已检查用户及系统 Applications 的有限层级；自定义目录可能未覆盖。", path: "")
}

// Direct installed binaries only. Do not source shell profiles or invoke
// manager shims, install commands, or automatic download hooks.
func managedRuntimePaths(_ id: String, requested: String? = nil, context: DiscoveryContext = .live) -> [String] {
    guard ["python", "node"].contains(id) else { return [] }
    func root(_ variable: String, fallback: String) -> URL {
        let value = context.environment[variable] ?? ""
        return value.hasPrefix("/") ? URL(fileURLWithPath: value) : context.home.appendingPathComponent(fallback)
    }
    var folders: [(URL, String)] = []
    if id == "python" {
        folders = [(root("PYENV_ROOT", fallback: ".pyenv").appendingPathComponent("versions"), "python3")]
    } else {
        folders = [(root("NVM_DIR", fallback: ".nvm").appendingPathComponent("versions/node"), "node")]
        if id == "node" { folders.append((root("VOLTA_HOME", fallback: ".volta").appendingPathComponent("tools/image/node"), "node")) }
    }
    var paths = [String]()
    for (folder, binary) in folders {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { name in
                let normalized = name.hasPrefix("v") ? String(name.dropFirst()) : name
                guard normalized.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil else { return false }
                return requested == nil || normalized == requested! || normalized.hasPrefix(requested! + ".")
            }.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
        for name in names.prefix(12) { paths.append(folder.appendingPathComponent(name + "/bin/" + binary).path) }
    }
    return uniqueDiscoveryPaths(paths)
}

func probeCommandCandidates(_ item: Component, paths: [String], cltAvailable: Bool = true, requested: String = "auto", run: (String, [String]) -> (Int32, String)? = runProbe) -> Probe {
    var failed: Probe?
    for path in uniqueDiscoveryPaths(paths) where FileManager.default.isExecutableFile(atPath: path) {
        if item.id == "git", path == "/usr/bin/git", !cltAvailable {
            if failed == nil { failed = .init(state: "需要检查", detail: "存在系统入口，但命令行工具尚未就绪。", path: path) }
            continue
        }
        let response = run(path, item.arguments)
        if let (code, text) = response, code == 0 {
            let probe = Probe(state: "已检测到", detail: text.isEmpty ? "工具未返回版本信息" : text, path: path)
            if versionMatches(probe, requested: requested) { return probe }
        }
        if failed == nil { failed = .init(state: "需要检查", detail: response?.1 ?? "无法启动检测进程，请检查权限。", path: path) }
    }
    return failed ?? .init(state: "未在常见位置发现", detail: "未在检测范围发现可用入口；自定义目录或其他管理器可能未覆盖。", path: "")
}
