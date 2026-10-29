import Foundation

struct InstallCommand: Equatable {
    let executable: String
    let arguments: [String]
    var display: String { ([executable] + arguments).joined(separator: " ") }
}

enum InstallAction: Equatable {
    case reuse
    case install(InstallCommand)
    case bootstrap(String)
    case awaitingPrerequisite(String)
    case blocked(String)
}

let formulaNames = ["git": "git", "uv": "uv", "python": "python3", "node": "node", "pnpm": "pnpm", "ollama": "ollama", "cmake": "cmake", "ninja": "ninja", "openocd": "open-ocd", "esptool": "esptool", "dfu": "dfu-util"] .merging(expandedFormulaNames) { _, new in new }.merging(developerFormulaNames) { _, new in new }
let caskNames = ["vscode": "visual-studio-code", "arduino": "arduino-ide", "codex": "codex", "claude": "claude-code", "cursor": "cursor", "docker": "docker-desktop"] .merging(expandedCaskNames) { _, new in new }.merging(developerCaskNames) { _, new in new }
let applicationNames = ["vscode": "Visual Studio Code.app", "arduino": "Arduino IDE.app", "cursor": "Cursor.app", "docker": "Docker.app"] .merging(expandedApplicationNames) { _, new in new }.merging(developerApplicationNames) { _, new in new }

func installAction(for component: Component, probes: [String: Probe], selectedVersion: String = "auto") -> InstallAction {
    guard versionOptions(component.id).contains(where: { $0.id == selectedVersion }) else { return .blocked("请选择列表中支持的版本。") }
    if versionMatches(probes[component.id], requested: selectedVersion) { return .reuse }
    guard probes[component.id] != nil else { return .blocked("请先完成环境检测。") }
    if component.id == "clt" { return .bootstrap("clt") }
    if component.id == "brew" {
        if let current = probes["brew"], !current.path.isEmpty { return .blocked("已有 Homebrew 入口但响应异常，请先检查，避免重复安装。") }
        return .bootstrap("brew")
    }
    guard let current = probes[component.id] else { return .blocked("请先完成环境检测。") }
    if current.state == "版本冲突" { return .blocked(current.detail) }
    if component.id == "platformio", !current.path.isEmpty { return .blocked("已有 PlatformIO 入口但响应异常，请先检查。") }
    if component.id == "python" && selectedVersion != "auto" || component.id == "platformio" {
        let uvPath: String
        if let uv = probes["uv"], uv.available { uvPath = uv.path }
        else if let uv = probes["uv"], !uv.path.isEmpty { return .blocked("uv 入口存在但无法响应，请先检查。") }
        else if let brew = probes["brew"], brew.available, probes["clt"]?.available == true {
            uvPath = URL(fileURLWithPath: brew.path).deletingLastPathComponent().appendingPathComponent("uv").path
        } else { return .awaitingPrerequisite("将先安装 uv，再安装所选环境。") }
        let arguments = component.id == "python" ? ["python", "install", selectedVersion] : ["tool", "install", "platformio"]
        return .install(.init(executable: uvPath, arguments: arguments))
    }
    if !current.path.isEmpty && !(component.id == "git" && current.path == "/usr/bin/git" && probes["clt"]?.available != true) { return .blocked("已存在工具入口但检测失败，请先检查该工具，避免覆盖。") }
    guard probes["clt"]?.available == true else { return .awaitingPrerequisite("将先安装命令行工具，再安装此组件。") }
    guard let brew = probes["brew"], brew.available else { return .awaitingPrerequisite("将先安装 Homebrew，再安装此组件。") }
    if let cask = caskNames[component.id] {
        var arguments = ["install", "--cask"]
        if applicationNames[component.id] != nil {
            let directory = component.id == "docker" ? "/Applications" : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
            arguments.append("--appdir=" + directory)
        }
        arguments.append("homebrew/cask/" + cask)
        return .install(.init(executable: brew.path, arguments: arguments))
    }
    guard var formula = formulaNames[component.id] else { return .blocked("此组件尚未接入安装。") }
    if selectedVersion != "auto" { formula = versionedFormulaPrefix(component.id) + "@" + selectedVersion }
    return .install(.init(executable: brew.path, arguments: ["install", "--formula", "homebrew/core/" + formula]))
}

func actionDescription(_ action: InstallAction) -> String {
    switch action {
    case .reuse: return "复用现有工具（执行时再次验证）"
    case .install(let command): return command.display
    case .bootstrap(let id): return id == "clt" ? "打开 Apple 系统安装器；完成后返回软件验证" : "下载 Homebrew 官方签名安装包；由系统安装器授权安装"
    case .awaitingPrerequisite(let reason): return reason
    case .blocked(let reason): return "需要处理：" + reason
    }
}

struct InstallSnapshot: Codable {
    var date = Date()
    var selected: [String]
    var states: [String: String]
    var summary: String
    var log: String
    var versions: [String: String]? = nil
    var projectEnabled: Bool? = nil
    var projectDirectory: String? = nil
    var projectResult: ProjectEnvironment? = nil
    var issues: [InstallIssue]? = nil
    var runID: UUID? = nil
    var readiness: [CheckItem]? = nil
    var readinessDate: Date? = nil
}

// The lock protects the sole mutable field across the worker and main queues.
final class InstallControl: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    var stopRequested: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func requestStop() { lock.lock(); stopped = true; lock.unlock() }
}

struct InstallOutcome {
    let states: [String: String]
    let summary: String
    var issues: [InstallIssue] = []
}

// All mutating process calls pass through this runner. Tests inject a fake runner.
func runInstallCommand(_ command: InstallCommand, output: @escaping (String) -> Void) -> Int32 {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: command.executable)
    process.arguments = command.arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = pipe
    process.standardError = pipe
    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
    environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
    environment["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
    environment["HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK"] = "1"
    environment["HOMEBREW_NO_ENV_HINTS"] = "1"
    environment["HOMEBREW_NO_ANALYTICS"] = "1"
    environment["CI"] = "1"
    process.environment = environment
    do { try process.run() } catch { output("无法启动安装：\(error.localizedDescription)\n"); return -1 }
    while true {
        let data = pipe.fileHandleForReading.availableData
        if data.isEmpty { break }
        output(String(decoding: data, as: UTF8.self))
    }
    process.waitUntilExit()
    return process.terminationStatus
}

func executeInstall(
    components: [Component],
    approved: [String: InstallAction],
    control: InstallControl,
    versions: [String: String] = [:],
    probe: () -> [String: Probe] = inspect,
    run: (InstallCommand, @escaping (String) -> Void) -> Int32 = runInstallCommand,
    event: @escaping (String, String, String) -> Void
) -> InstallOutcome {
    var states = Dictionary(uniqueKeysWithValues: components.map { ($0.id, "待执行") })
    func update(_ id: String, _ state: String, _ message: String) {
        states[id] = state
        event(id, state, message)
    }
    func finishPending(_ state: String) {
        for item in components where states[item.id] == "待执行" { update(item.id, state, "") }
    }
    // Preflight the entire reviewed plan before starting any mutation.
    var current = probe()
    for item in components {
        let action = installAction(for: item, probes: current, selectedVersion: versions[item.id] ?? "auto")
        if case .bootstrap = action {
            update(item.id, "等待系统安装", "请在软件中启动前置工具安装，完成后重新验证。\n")
            finishPending("未执行")
            return .init(states: states, summary: "请先完成前置工具安装。")
        }
        if case .awaitingPrerequisite(let reason) = action {
            update(item.id, "等待前置工具", reason + "\n")
            finishPending("未执行")
            return .init(states: states, summary: "前置工具尚未就绪。")
        }
        if case .blocked(let reason) = action {
            update(item.id, "需要处理", reason + "\n")
            finishPending("未执行")
            return .init(states: states, summary: "环境检查未通过，未开始安装。")
        }
        if case .install = action, approved[item.id] != action {
            update(item.id, "计划已变化", "环境已变化，请重新预览并确认计划。\n")
            finishPending("未执行")
            return .init(states: states, summary: "计划发生变化，未开始安装。")
        }
    }
    for item in components {
        if control.stopRequested {
            finishPending("已停止")
            return .init(states: states, summary: "已停止后续步骤，已完成的安装会保留。")
        }
        current = probe()
        let action = installAction(for: item, probes: current, selectedVersion: versions[item.id] ?? "auto")
        switch action {
        case .bootstrap, .awaitingPrerequisite:
            update(item.id, "等待前置工具", "请返回安装计划完成前置工具。\n")
            finishPending("未执行")
            return .init(states: states, summary: "前置工具需要重新安装或验证。")
        case .reuse:
            update(item.id, "已复用", "\(item.name)：复用 \(current[item.id]?.path ?? "")\n")
        case .blocked(let reason):
            update(item.id, "需要处理", reason + "\n")
            finishPending("未执行")
            return .init(states: states, summary: "环境已变化，请处理后重试。")
        case .install(let command):
            guard approved[item.id] == action else {
                update(item.id, "计划已变化", "安装命令变化，请重新预览确认。\n")
                finishPending("未执行")
                return .init(states: states, summary: "计划变化，已停止。")
            }
            update(item.id, "安装中", "\n▶ \(item.name)\n\(command.display)\n")
            var recentOutput = ""
            let status = run(command) { chunk in
                recentOutput = String((recentOutput + chunk).suffix(16_000))
                event(item.id, "安装中", chunk)
            }
            if status != 0 {
                update(item.id, "失败", "\n安装退出码：\(status)。请检查日志，处理网络、权限或文件冲突后重试。\n")
                finishPending("未执行")
                return .init(states: states, summary: "\(item.name) 安装失败，后续步骤未执行。", issues: [diagnoseInstallFailure(componentID: item.id, status: status, output: recentOutput)])
            }
            update(item.id, "验证中", "\n正在检查工具响应…\n")
            let after = probe()
            guard versionMatches(after[item.id], requested: versions[item.id] ?? "auto") else {
                update(item.id, "验证失败", "命令已退出，但工具验证未通过。请查看实际安装状态后重试。\n")
                finishPending("未执行")
                return .init(states: states, summary: "\(item.name) 验证未通过。", issues: [.init(componentID: item.id, title: "安装命令已结束，但验证未通过", detail: after[item.id]?.detail ?? "未检测到所选版本。", suggestion: "重新检测实际安装路径与版本，再查看更新后的计划。已有可用安装会复用；暂时不要手动删除安装目录。")])
            }
            update(item.id, "已安装并验证", "\(after[item.id]?.detail ?? "")\n")
        }
    }
    return .init(states: states, summary: "所选步骤已完成，工具版本响应验证通过。")
}

func installerSelfTests() {
    let good = Probe(state: "已检测到", detail: "version", path: "/mock/bin/tool")
    let absent = Probe(state: "未在常见位置发现", detail: "", path: "")
    var values = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, good) })
    values["uv"] = absent
    values["ollama"] = absent
    let steps = catalog.filter { ["uv", "ollama"].contains($0.id) }
    let approval = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, installAction(for: $0, probes: values)) })
    var calls = 0
    let success = executeInstall(components: steps, approved: approval, control: InstallControl(), probe: { values }, run: { _, output in
        calls += 1; output("test output\n"); values[steps[calls - 1].id] = good; return 0
    }, event: { _, _, _ in })
    precondition(calls == 2 && success.states.values.allSatisfy { $0 == "已安装并验证" })
    values["uv"] = absent; values["ollama"] = absent; calls = 0
    let failed = executeInstall(components: steps, approved: approval, control: InstallControl(), probe: { values }, run: { _, _ in calls += 1; return 1 }, event: { _, _, _ in })
    precondition(calls == 1 && failed.states["uv"] == "失败" && failed.states["ollama"] == "未执行")
    let unverified = executeInstall(components: steps, approved: approval, control: InstallControl(), probe: { values }, run: { _, _ in 0 }, event: { _, _, _ in })
    precondition(unverified.states["uv"] == "验证失败")
    let stopped = InstallControl(); stopped.requestStop(); calls = 0
    let cancelled = executeInstall(components: steps, approved: approval, control: stopped, probe: { values }, run: { _, _ in calls += 1; return 0 }, event: { _, _, _ in })
    precondition(calls == 0 && cancelled.states["uv"] == "已停止")
    let stopAfterStep = InstallControl()
    let stoppedMidRun = executeInstall(components: steps, approved: approval, control: stopAfterStep, probe: { values }, run: { _, _ in
        values["uv"] = good
        stopAfterStep.requestStop()
        return 0
    }, event: { _, _, _ in })
    precondition(stoppedMidRun.states["uv"] == "已安装并验证" && stoppedMidRun.states["ollama"] == "已停止")
    values["uv"] = absent
    values["brew"] = absent
    let blocked = executeInstall(components: steps, approved: approval, control: InstallControl(), probe: { values }, run: { _, _ in preconditionFailure("Must not install without brew") }, event: { _, _, _ in })
    precondition(blocked.states["uv"] == "等待前置工具")
    values["brew"] = good
    values["uv"] = good
    let changed = executeInstall(components: steps, approved: ["uv": .reuse, "ollama": .reuse], control: InstallControl(), probe: { values }, run: { _, _ in preconditionFailure("Unapproved change") }, event: { _, _, _ in })
    precondition(changed.states["ollama"] == "计划已变化")
    // Re-running a successful plan must not invoke any installer.
    values["ollama"] = good
    let reused = executeInstall(components: steps, approved: approval, control: InstallControl(), probe: { values }, run: { _, _ in preconditionFailure("Must reuse existing tool") }, event: { _, _, _ in })
    precondition(reused.states.values.allSatisfy { $0 == "已复用" })
    var captured = ""
    let code = runInstallCommand(.init(executable: "/usr/bin/printf", arguments: ["%s", "runner-test"])) { captured += $0 }
    precondition(code == 0 && captured == "runner-test")
    precondition(runInstallCommand(.init(executable: "/usr/bin/false", arguments: []), output: { _ in }) != 0)
    precondition(runInstallCommand(.init(executable: "/nonexistent/envsetup-test", arguments: []), output: { _ in }) == -1)
    let snapshot = InstallSnapshot(selected: ["uv"], states: ["uv": "安装中"], summary: "test", log: "log")
    let decoded = try! JSONDecoder().decode(InstallSnapshot.self, from: JSONEncoder().encode(snapshot))
    precondition(decoded.states["uv"] == "安装中" && decoded.log == "log")
    print("PASS: success, failure, failed verification, stop before/after step, preflight, changed plan, reuse, subprocess output/exit, history serialization")
}
