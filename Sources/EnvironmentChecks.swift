import Foundation
import Darwin

struct CheckItem: Identifiable, Codable {
    let id: String
    let title: String
    let level: String // ok, warning, blocked
    let detail: String
}

struct PreflightReport {
    let fingerprint: String
    let date: Date
    let items: [CheckItem]
    var blocked: Bool { items.contains { $0.level == "blocked" } }
}

struct ProjectEnvironment: Codable {
    let project: URL
    let python: URL
    let version: String
    let reused: Bool
}

struct LimitedResult {
    let code: Int32
    let output: String
    let timedOut: Bool
}

func limitedProcess(_ path: String, _ arguments: [String], timeout: TimeInterval = 8) -> LimitedResult {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("envsetup-output-" + UUID().uuidString)
    _ = FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
    guard let output = try? FileHandle(forWritingTo: file) else { return .init(code: -1, output: "无法创建临时输出文件", timedOut: false) }
    defer { try? output.close(); try? FileManager.default.removeItem(at: file) }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    var environment = ProcessInfo.processInfo.environment
    environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
    process.environment = environment
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = output
    process.standardError = output
    do { try process.run() } catch { return .init(code: -1, output: error.localizedDescription, timedOut: false) }
    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
    let timedOut = process.isRunning
    if timedOut {
        process.terminate()
        Thread.sleep(forTimeInterval: 0.1)
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }
    process.waitUntilExit()
    try? output.synchronize()
    let reader = try? FileHandle(forReadingFrom: file)
    let bytes = (try? reader?.read(upToCount: 32_000)) ?? Data()
    try? reader?.close()
    return .init(code: timedOut ? -2 : process.terminationStatus, output: String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines), timedOut: timedOut)
}

struct PythonHealth: Decodable {
    let version: String
    let prefix: String
    let base: String
    var isolated: Bool { prefix != base }
}

func pythonHealth(_ executable: String) throws -> PythonHealth {
    let result = limitedProcess(executable, ["-I", "-c", "import sys,json,ssl; print(json.dumps(dict(version='.'.join(map(str,sys.version_info[:3])),prefix=sys.prefix,base=sys.base_prefix)))"])
    guard result.code == 0, let health = try? JSONDecoder().decode(PythonHealth.self, from: Data(result.output.utf8)) else {
        throw SetupError.message("Python 运行验证失败：" + String(result.output.prefix(800)))
    }
    return health
}

func projectCheck(_ project: URL, expectedVersion: String?) -> CheckItem {
    var directory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: project.path, isDirectory: &directory), directory.boolValue else {
        return .init(id: "project", title: "项目目录", level: "blocked", detail: "请选择一个已存在的项目目录。")
    }
    let environment = project.appendingPathComponent(".venv")
    guard FileManager.default.isWritableFile(atPath: project.path) else {
        return .init(id: "project", title: "项目目录权限", level: "blocked", detail: "项目目录不可写：" + project.path)
    }
    let attributes = try? FileManager.default.attributesOfItem(atPath: environment.path)
    if attributes == nil { return .init(id: "project", title: "项目独立环境", level: "ok", detail: "将创建 \(environment.path)，不修改全局 Python。") }
    guard attributes?[.type] as? FileAttributeType == .typeDirectory,
          FileManager.default.fileExists(atPath: environment.appendingPathComponent("pyvenv.cfg").path),
          let health = try? pythonHealth(environment.appendingPathComponent("bin/python").path), health.isolated,
          URL(fileURLWithPath: health.prefix).resolvingSymlinksInPath().path == environment.resolvingSymlinksInPath().path else {
        return .init(id: "project", title: "现有 .venv", level: "blocked", detail: "存在无法确认的 .venv，软件不会覆盖或删除它。请先检查该目录。")
    }
    if let expectedVersion, !health.version.hasPrefix(expectedVersion + ".") && health.version != expectedVersion {
        return .init(id: "project", title: "项目 Python 版本冲突", level: "blocked", detail: "现有环境为 \(health.version)，所选为 \(expectedVersion)。请选择匹配版本或其他项目目录。")
    }
    let pip = limitedProcess(environment.appendingPathComponent("bin/python").path, ["-I", "-m", "pip", "--version"])
    guard pip.code == 0 else { return .init(id: "project", title: "现有 .venv 未就绪", level: "blocked", detail: "解释器存在，但 pip 不可用。请先修复此环境，软件不会覆盖。") }
    if expectedVersion == nil { return .init(id: "project", title: "现有 .venv 版本待核对", level: "warning", detail: "已有 Python \(health.version)，但尚无法确定待装解释器的版本。建议选择相同系列；创建步骤会再次核对，不匹配时停止。") }
    return .init(id: "project", title: "项目独立环境", level: "ok", detail: "复用现有 Python \(health.version) 虚拟环境及其依赖。")
}

func createProjectEnvironment(project: URL, interpreter: Probe) throws -> ProjectEnvironment {
    let health = try pythonHealth(interpreter.path)
    let series = health.version.split(separator: ".").prefix(2).joined(separator: ".")
    let check = projectCheck(project, expectedVersion: series)
    guard check.level != "blocked" else { throw SetupError.message(check.detail) }
    let target = project.appendingPathComponent(".venv")
    let existed = FileManager.default.fileExists(atPath: target.path)
    if !existed {
        // mkdir is exclusive: never hand venv an existing directory after a race.
        guard Darwin.mkdir(target.path, S_IRWXU) == 0 else { throw SetupError.message("无法独占创建 .venv，目录可能已被其他程序创建。请重新检查。") }
        let result = limitedProcess(interpreter.path, ["-I", "-m", "venv", target.path], timeout: 120)
        guard result.code == 0 else {
            throw SetupError.message("虚拟环境创建未完成：\(String(result.output.prefix(1200)))。已保留 \(target.path)，请检查后再重试，软件不会自动删除。")
        }
    }
    let final = projectCheck(project, expectedVersion: series)
    guard final.level == "ok" else { throw SetupError.message(final.detail) }
    let python = target.appendingPathComponent("bin/python")
    let verified = try pythonHealth(python.path)
    return .init(project: project, python: python, version: verified.version, reused: existed)
}

func freeSpace(_ path: URL) -> Int64? {
    if let values = try? path.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]), let bytes = values.volumeAvailableCapacityForImportantUsage { return bytes }
    let attributes = try? FileManager.default.attributesOfFileSystem(forPath: path.path)
    return (attributes?[.systemFreeSize] as? NSNumber)?.int64Value
}

func spaceCheck(id: String, title: String, available: Int64?, suggested: Int64) -> CheckItem {
    guard let available else { return .init(id: id, title: title, level: "warning", detail: "无法获取剩余空间，请自行确认。") }
    let level = available < 256_000_000 ? "blocked" : (available < suggested ? "warning" : "ok")
    return .init(id: id, title: title, level: level, detail: "可用约 \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))；建议预留 \(ByteCountFormatter.string(fromByteCount: suggested, countStyle: .file))。这是安全余量，不是精确下载体积。")
}

func sourceCheck(_ url: URL) async -> CheckItem {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 8
    configuration.timeoutIntervalForResource = 12
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    do {
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let reachable = (200..<400).contains(status) || (url.host == "ghcr.io" && status == 401)
        return .init(id: "source-" + (url.host ?? ""), title: "下载源：" + (url.host ?? ""), level: reachable ? "ok" : "warning", detail: reachable ? "服务可连接；不代表所有下载文件及访问权限都已验证。" : "服务返回 HTTP \(status)。安装可能失败；已有缓存时仍可尝试。")
    } catch {
        return .init(id: "source-" + (url.host ?? ""), title: "下载源：" + (url.host ?? ""), level: "warning", detail: "连接未通过：\(error.localizedDescription)。安装可能失败；已有缓存时仍可尝试。")
    }
}

func performPreflight(fingerprint: String, components: [Component], actions: [String: InstallAction], versions: [String: String], probes: [String: Probe], base: [String: Probe], project: URL?) async -> PreflightReport {
    var items = [CheckItem]()
    var needsDownload = false
    var sources = Set<String>()
    for item in components {
        let action = actions[item.id]
        if case .blocked(let reason) = action { items.append(.init(id: "conflict-" + item.id, title: item.name, level: "blocked", detail: reason)) }
        if case .install(let command) = action {
            needsDownload = true
            if command.executable.hasSuffix("/brew") { sources.formUnion(["https://formulae.brew.sh/", "https://ghcr.io/v2/"]) }
            else { sources.insert("https://github.com/") }
            if item.id == "platformio" { sources.formUnion(["https://pypi.org/", "https://files.pythonhosted.org/"]) }
            if item.id == "docker" { sources.insert("https://desktop.docker.com/") }
            if item.id == "cursor" { sources.insert("https://downloads.cursor.com/") }
        }
        if case .bootstrap(let id) = action {
            needsDownload = true
            if id == "brew" { sources.insert("https://api.github.com/repos/Homebrew/brew/releases/latest") }
            else { items.append(.init(id: "apple-source", title: "Apple 系统下载", level: "warning", detail: "实际下载由系统安装器完成，请在安装器内确认网络与磁盘要求。")) }
        }
        let requested = versions[item.id] ?? "auto"
        if databaseServers.contains(item.id), case .install = action {
            items.append(.init(id: "database-data-" + item.id, title: item.name + " 数据目录", level: "warning", detail: "Homebrew 安装可能初始化默认数据目录。软件不自动启动服务、不迁移数据、不创建业务库或修改密码。已有数据库请先确认备份及目录。"))
            if ["mysql", "postgresql"].contains(item.id), let brew = probes["brew"], brew.available {
                let prefix = URL(fileURLWithPath: brew.path).deletingLastPathComponent().deletingLastPathComponent()
                let name = item.id == "mysql" ? "mysql" : "postgresql@" + (requested == "auto" ? "18" : requested)
                if let check = databaseDataCheck(prefix.appendingPathComponent("var/" + name), name: item.name) { items.append(check) }
            }
        }
        let paths = Set(item.paths.map { NSString(string: $0).expandingTildeInPath }.filter { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path })
        if paths.count > 1 { items.append(.init(id: "providers-" + item.id, title: item.name + " 存在多个入口", level: "warning", detail: "将使用检测到的明确路径；其他安装保留。请留意终端 PATH 与项目使用的版本可能不同。")) }
        if requested != "auto", let current = base[item.id], current.available, !versionMatches(current, requested: requested) {
            items.append(.init(id: "versions-" + item.id, title: item.name + " 多版本", level: "warning", detail: "本机 \(versionString(current) ?? "其他版本") 会保留，新选的 \(requested) 单独安装；不会切换全局默认版本。"))
        }
    }
    if versions["python"] == "3.10" { items.append(.init(id: "python-eol", title: "Python 3.10", level: "warning", detail: "已于 2026-10-01 结束官方支持，请仅在旧项目确有要求时选择。")) }
    if needsDownload {
        let newIDs = Set(components.filter { if case .reuse = actions[$0.id] { return false }; return true }.map(\.id))
        let reserve: Int64 = newIDs.contains("docker") ? 8_000_000_000 : (newIDs.contains("python") ? 3_000_000_000 : 2_000_000_000)
        items.append(spaceCheck(id: "disk", title: "安装盘空间", available: freeSpace(FileManager.default.homeDirectoryForCurrentUser), suggested: reserve))
    } else { items.append(.init(id: "reuse", title: "复用现有工具", level: "ok", detail: "所选工具无需下载；仍会重新检查实际版本。")) }
    if let project {
        let expected = versions["python"].flatMap { $0 == "auto" ? nil : $0 } ?? versionString(probes["python"]).map { $0.split(separator: ".").prefix(2).joined(separator: ".") }
        items.append(projectCheck(project, expectedVersion: expected))
        items.append(spaceCheck(id: "project-disk", title: "项目盘空间", available: freeSpace(project), suggested: 500_000_000))
    }
    if !items.contains(where: { $0.id.hasPrefix("conflict-") }) { items.append(.init(id: "conflicts", title: "已知版本与入口冲突", level: "ok", detail: "未发现当前检测范围内的阻断项；未验证所有项目依赖与第三方版本管理器。")) }
    let network = await withTaskGroup(of: CheckItem.self, returning: [CheckItem].self) { group in
        for source in sources.sorted() { if let url = URL(string: source) { group.addTask { await sourceCheck(url) } } }
        var values = [CheckItem](); for await value in group { values.append(value) }; return values.sorted { $0.id < $1.id }
    }
    items.append(contentsOf: network)
    return .init(fingerprint: fingerprint, date: Date(), items: items)
}

func readinessChecks(ids: Set<String>, probes: [String: Probe], project: ProjectEnvironment?) async -> [CheckItem] {
    var items = [CheckItem]()
    for item in catalog where ids.contains(item.id) {
        guard let probe = probes[item.id], probe.available else { items.append(.init(id: item.id, title: item.name, level: "blocked", detail: "未检测到可用安装。")); continue }
        if databaseServers.contains(item.id) {
            items.append(databaseReadiness(item, probe: probe))
        } else if item.id == "sqlite" {
            let result = limitedProcess(probe.path, [":memory:", "select 1;"])
            items.append(.init(id: item.id, title: "SQLite 运行", level: result.code == 0 && result.output == "1" ? "ok" : "warning", detail: result.code == 0 && result.output == "1" ? "内存数据库查询成功，未创建磁盘数据库。" : "程序存在，但内存查询未通过：" + String(result.output.prefix(500))))
        } else if item.id == "docker" {
            let docker = URL(fileURLWithPath: probe.path).appendingPathComponent("Contents/Resources/bin/docker").path
            let result = limitedProcess(docker, ["--context", "desktop-linux", "info", "--format", "{{.ServerVersion}}"], timeout: 8)
            items.append(.init(id: item.id, title: "Docker 引擎", level: result.code == 0 && !result.output.isEmpty ? "ok" : "warning", detail: result.code == 0 ? "本机 desktop-linux 上下文可连接，服务端版本：\(result.output)" : "应用已安装，但本机引擎未就绪或连接失败。请打开 Docker Desktop 完成初始化后重新验证。\n" + String(result.output.prefix(500))))
        } else if item.id == "python" {
            do {
                let executable = project?.python.path ?? probe.path
                let health = try pythonHealth(executable)
                items.append(.init(id: item.id, title: project == nil ? "Python 运行" : "Python 项目环境", level: "ok", detail: "Python \(health.version) 可执行，标准库与 SSL 可导入。\n\(executable)\n未运行项目业务代码或检查其全部依赖。"))
            } catch { items.append(.init(id: item.id, title: "Python 运行", level: "blocked", detail: error.localizedDescription)) }
        } else if item.id == "ollama" {
            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }
            var request = URLRequest(url: URL(string: "http://127.0.0.1:11434/api/version")!); request.timeoutInterval = 4
            do {
                let (data, response) = try await session.data(for: request)
                let version = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["version"] as? String
                let ready = (response as? HTTPURLResponse)?.statusCode == 200 && version != nil
                items.append(.init(id: item.id, title: "Ollama 服务", level: ready ? "ok" : "warning", detail: ready ? "本机服务可连接，版本 \(version!)。未验证模型推理。" : "程序已安装，但服务响应未通过验证。"))
            } catch { items.append(.init(id: item.id, title: "Ollama 服务", level: "warning", detail: "程序已安装，本机服务尚不可连接。请先启动服务，再重新验证。")) }
        } else if ["codex", "claude", "cursor", "gh"].contains(item.id) {
            items.append(.init(id: item.id, title: item.name, level: "warning", detail: "已安装；账号登录、订阅及模型请求状态未检查，请在软件内确认。"))
        } else {
            items.append(.init(id: item.id, title: item.name, level: applicationNames[item.id] == nil ? "ok" : "warning", detail: applicationNames[item.id] == nil ? "命令行版本响应正常；未验证实际项目。" : "应用包及主程序存在；首次启动状态尚未验证，请在软件内确认。"))
        }
    }
    return items
}
