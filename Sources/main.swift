import SwiftUI
import AppKit

struct Component: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let groups: [String]
    let dependencies: [String]
    let paths: [String]
    let arguments: [String]
}

let catalog: [Component] = [
    .init(id: "clt", name: "命令行工具", subtitle: "Apple 开发基础工具", icon: "hammer", groups: ["基础工具"], dependencies: [], paths: ["/usr/bin/xcode-select"], arguments: ["-p"]),
    .init(id: "brew", name: "Homebrew", subtitle: "管理开发工具和软件包", icon: "shippingbox", groups: ["基础工具"], dependencies: ["clt"], paths: ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"], arguments: ["--version"]),
    .init(id: "git", name: "Git", subtitle: "代码版本管理", icon: "arrow.triangle.branch", groups: ["基础工具"], dependencies: ["brew"], paths: ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"], arguments: ["--version"]),
    .init(id: "uv", name: "uv", subtitle: "Python 版本、虚拟环境与依赖管理", icon: "cube", groups: ["Python", "AI"], dependencies: ["brew"], paths: ["~/.local/bin/uv", "/opt/homebrew/bin/uv", "/usr/local/bin/uv"], arguments: ["--version"]),
    .init(id: "python", name: "Python", subtitle: "Homebrew 当前稳定版本；已有版本优先复用", icon: "terminal", groups: ["Python", "AI"], dependencies: ["brew"], paths: ["~/.local/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"], arguments: ["--version"]),
    .init(id: "node", name: "Node.js", subtitle: "JavaScript 运行环境", icon: "curlybraces", groups: ["前端"], dependencies: ["brew"], paths: ["/opt/homebrew/bin/node", "/usr/local/bin/node"], arguments: ["--version"]),
    .init(id: "pnpm", name: "pnpm", subtitle: "前端项目依赖管理", icon: "square.stack.3d.up", groups: ["前端"], dependencies: ["node"], paths: ["/opt/homebrew/bin/pnpm", "/usr/local/bin/pnpm", "~/Library/pnpm/pnpm"], arguments: ["--version"]),
    .init(id: "ollama", name: "Ollama", subtitle: "本地模型运行工具（模型另行下载）", icon: "sparkles", groups: ["AI"], dependencies: ["brew"], paths: ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama", "/Applications/Ollama.app/Contents/Resources/ollama"], arguments: ["--version"]),
    .init(id: "vscode", name: "Visual Studio Code", subtitle: "代码编辑器；安装到用户 Applications 目录", icon: "chevron.left.forwardslash.chevron.right", groups: ["开发软件"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "arduino", name: "Arduino IDE", subtitle: "Arduino 开发软件；开发板包由用户后续选择", icon: "infinity", groups: ["嵌入式", "开发软件"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "platformio", name: "PlatformIO Core", subtitle: "嵌入式命令行工具；不预选开发板或安装编辑器扩展", icon: "cpu", groups: ["嵌入式"], dependencies: ["uv"], paths: ["~/.local/bin/pio", "/opt/homebrew/bin/pio", "/usr/local/bin/pio"], arguments: ["--version"]),
    .init(id: "codex", name: "Codex CLI", subtitle: "OpenAI 命令行编程助手；与桌面应用分开检测", icon: "terminal", groups: ["AI 编程"], dependencies: ["brew"], paths: ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", "~/.local/bin/codex", "~/.npm-global/bin/codex", "/Applications/Codex.app/Contents/Resources/codex"], arguments: ["--version"]),
    .init(id: "claude", name: "Claude Code", subtitle: "命令行编程助手；登录由你完成", icon: "terminal", groups: ["AI 编程"], dependencies: ["brew"], paths: ["~/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"], arguments: ["--version"]),
    .init(id: "cursor", name: "Cursor", subtitle: "AI 代码编辑器；账号及订阅自行配置", icon: "cursorarrow", groups: ["AI 编程"], dependencies: ["brew"], paths: [], arguments: []),
    .init(id: "docker", name: "Docker Desktop", subtitle: "容器环境；首次启动需自行完成授权及初始化", icon: "shippingbox", groups: ["容器"], dependencies: ["brew"], paths: [], arguments: [])
] + expandedComponents

struct Probe: Codable {
    let state: String
    let detail: String
    let path: String
    var available: Bool { state == "已检测到" }
}

func runProbe(_ path: String, _ arguments: [String]) -> (Int32, String)? {
    let result = limitedProcess(path, arguments, timeout: 5)
    return (result.code, result.timedOut ? "检测超时，请手动检查此工具" : String(result.output.prefix(1200)))
}

func inspect() -> [String: Probe] {
    var result: [String: Probe] = [:]
    let clt = runProbe("/usr/bin/xcode-select", ["-p"])
    for item in catalog {
        if let name = applicationNames[item.id] {
            let folders = [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path, "/Applications"]
            let app = folders.map { $0 + "/" + name }.first { FileManager.default.fileExists(atPath: $0) }
            if let app, let bundle = Bundle(path: app), let executable = bundle.executableURL, FileManager.default.isExecutableFile(atPath: executable.path) {
                result[item.id] = Probe(state: "已检测到", detail: item.name + " " + (bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "版本未知"), path: app)
            } else { result[item.id] = Probe(state: "未在常见位置发现", detail: "已检查用户及系统 Applications 目录。", path: "") }
            continue
        }
        let paths = (item.paths + extraProbePaths(item.id)).map { NSString(string: $0).expandingTildeInPath }
        guard let path = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            result[item.id] = Probe(state: "未在常见位置发现", detail: "可能安装在自定义目录或版本管理器目录，请自行核对。", path: "")
            continue
        }
        // Avoid triggering Apple's installation dialog by invoking a developer shim.
        if item.id == "git" && path == "/usr/bin/git" && clt?.0 != 0 {
            result[item.id] = Probe(state: "需要检查", detail: "存在系统入口，但命令行工具尚未就绪。", path: path)
            continue
        }
        let response = item.id == "clt" ? clt : runProbe(path, item.arguments)
        if let (code, text) = response {
            result[item.id] = Probe(state: code == 0 ? "已检测到" : "需要检查", detail: text.isEmpty ? "工具未返回版本信息" : text, path: path)
        } else {
            result[item.id] = Probe(state: "无法检测", detail: "无法启动检测进程，请检查权限。", path: path)
        }
    }
    return result
}

func dependencyClosure(_ selected: Set<String>) -> Set<String> {
    var required = selected
    var previous = Set<String>()
    while previous != required {
        previous = required
        for item in catalog where required.contains(item.id) { required.formUnion(item.dependencies) }
    }
    return required
}

@MainActor
final class Model: ObservableObject {
    @Published var page = 5
    @Published var purposes = Set<String>()
    @Published var customMode = false
    @Published var showAllTools = false
    @Published var selected = Set<String>()
    @Published var results: [String: Probe] = [:]
    @Published var installedResults: [String: Probe] = [:]
    @Published var versions: [String: String] = [:]
    @Published var groupFilter = "全部"
    @Published var scanning = false
    @Published var scannedAt: Date?
    @Published var query = ""
    @Published var copied = false
    @Published var installing = false
    @Published var states: [String: String] = [:]
    @Published var runSelected = Set<String>()
    @Published var runResults: [String: Probe] = [:]
    @Published var issues: [InstallIssue] = []
    @Published var summary = "尚未开始安装"
    @Published var log = ""
    @Published var stopRequested = false
    @Published var storageError = ""
    @Published var savedRun: InstallSnapshot?
    @Published var bootstrapID: String?
    @Published var preflightReport: PreflightReport?
    @Published var preflightBusy = false
    @Published var projectEnvironmentEnabled = false
    @Published var projectDirectory = ""
    @Published var projectResult: ProjectEnvironment?
    @Published var readiness = [CheckItem]()
    @Published var readinessBusy = false
    var readinessGeneration = UUID()
    @Published var schemeMessage = ""
    private var control = InstallControl()
    static let historyURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("EnvSetupAssistant/last-run.json")
    init() {
        if let data = try? Data(contentsOf: Self.historyURL), let record = try? JSONDecoder().decode(InstallSnapshot.self, from: data) { savedRun = record }
    }
    var actions: [String: InstallAction] { Dictionary(uniqueKeysWithValues: plan.map { ($0.id, installAction(for: $0, probes: results, selectedVersion: versions[$0.id] ?? "auto")) }) }
    var hasBlocker: Bool { actions.values.contains { if case .blocked = $0 { return true }; return false } }
    var installCount: Int { actions.values.filter { switch $0 { case .install, .bootstrap, .awaitingPrerequisite: return true; default: return false } }.count }
    var nextBootstrap: String? { plan.first { if case .bootstrap = actions[$0.id] { return true }; return false }?.id }
    var required: Set<String> { resolvedDependencies(selected, probes: results, versions: versions) }
    var plan: [Component] { catalog.filter { required.contains($0.id) } }
    var taskSucceeded: Bool { !states.isEmpty && states.values.allSatisfy { ["已复用", "已安装并验证", "已创建并验证"].contains($0) } }
    var relevantTools: Set<String> { customMode ? Set(catalog.map(\.id)) : toolsForPurposes(purposes) }
    var visibleTools: [Component] {
        catalog.filter { (showAllTools || purposes.isEmpty || relevantTools.contains($0.id)) && (query.isEmpty || ($0.name + $0.subtitle).localizedCaseInsensitiveContains(query)) }
    }
    var purposeSummary: String { customMode ? "自定义选择" : setupPurposes.filter { purposes.contains($0.id) }.map(\.title).joined(separator: "、") }
    func beginCustom() {
        guard !installing && bootstrapID == nil else { return }
        customMode = true
        showAllTools = true
        query = ""
        page = 1
        if scannedAt == nil { scan() }
    }
    func continuePurpose() {
        guard !purposes.isEmpty else { return }
        customMode = false
        selected.formIntersection(relevantTools)
        showAllTools = false
        page = 1
        if scannedAt == nil { scan() }
    }
    var detected: Int { installedResults.values.filter(\.available).count }
    func scan() {
        guard !scanning && !installing else { return }
        scanning = true
        let choices = versions
        DispatchQueue.global(qos: .userInitiated).async {
            let base = inspect()
            let values = inspectVersions(choices, base: base)
            DispatchQueue.main.async {
                if self.versions != choices {
                    self.scanning = false
                    self.scan()
                    return
                }
                self.installedResults = base
                self.results = values
                self.scanning = false
                self.scannedAt = Date()
                if self.page == 2 { self.runPreflight() }
                if self.taskSucceeded && self.runResults.isEmpty { self.runResults = values }
                if let id = self.bootstrapID {
                    if values[id]?.available == true {
                        self.states[id] = "已安装并验证"
                        self.bootstrapID = nil
                        self.summary = "前置工具已验证，请确认后续计划并继续安装。"
                        self.log += "\n前置工具已通过检测。\n"
                        self.page = 2
                    } else {
                        self.summary = "尚未检测到安装完成。请完成系统安装器的操作，再点击验证。"
                    }
                    self.saveRun()
                }
            }
        }
    }
    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
    func setVersion(_ id: String, _ value: String) {
        guard !installing && !scanning && bootstrapID == nil else { return }
        versions[id] = value
        scan()
    }
    func saveRun() {
        let record = InstallSnapshot(selected: selected.sorted(), states: states, summary: installing ? "任务运行中；如已中断，请重新检测后重试。" : summary, log: log, versions: versions, projectEnabled: wantsProjectEnvironment, projectDirectory: wantsProjectEnvironment ? projectDirectory : nil, projectResult: projectResult, issues: issues)
        do {
            try FileManager.default.createDirectory(at: Self.historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(record).write(to: Self.historyURL, options: .atomic)
            savedRun = record
        } catch { storageError = "任务记录保存失败：" + error.localizedDescription }
    }
    func restoreRun() {
        guard let record = savedRun, !installing, bootstrapID == nil else { return }
        selected = Set(record.selected).intersection(Set(catalog.map(\.id)))
        versions = (record.versions ?? [:]).filter { id, value in versionOptions(id).contains { $0.id == value } }
        projectEnvironmentEnabled = record.projectEnabled ?? false
        projectDirectory = record.projectDirectory ?? ""
        projectResult = record.projectResult
        resetReadiness()
        states = record.states
        issues = record.issues ?? []
        runSelected = Set(record.selected)
        runResults = [:]
        log = record.log
        summary = "上次记录：\(record.summary) 请重新检测，并确认计划后重试。"
        page = 3
        scan()
    }
    func reviewAfterFailure() {
        guard !installing && !scanning && bootstrapID == nil else { return }
        preflightReport = nil
        page = 2
        scan()
    }
    func requestStop() {
        control.requestStop()
        stopRequested = true
        summary = "将在当前步骤完成及验证后停止；已安装内容会保留。"
    }
    func selectForInstall(_ ids: Set<String>) {
        guard !installing && bootstrapID == nil else { return }
        selected = ids
        page = 2
    }
    func endBootstrapWait() {
        guard !installing else { return }
        if let id = bootstrapID { states[id] = "等待已结束（未确认完成）" }
        bootstrapID = nil
        summary = "已结束等待。外部安装器仍需你自行完成或取消。"
        saveRun()
    }
    func bootstrapFailure(_ message: String) {
        if let id = bootstrapID { states[id] = "启动失败" }
        installing = false
        InstallAppDelegate.busy = false
        bootstrapID = nil
        summary = message
        log += "\n" + message + "\n"
        saveRun()
    }
    func bootstrapLaunched() {
        installing = false
        InstallAppDelegate.busy = false
        if let id = bootstrapID { states[id] = "等待系统安装完成" }
        summary = "请在系统安装器中完成安装，再点击“安装完成，验证并继续”。"
        log += "\n已打开系统安装器。打开成功不代表安装完成。\n"
        saveRun()
    }
    func startBootstrap(_ id: String) {
        guard !installing && bootstrapID == nil else { return }
        bootstrapID = id
        installing = true
        InstallAppDelegate.busy = true
        page = 3
        states = Dictionary(uniqueKeysWithValues: plan.map { ($0.id, "待执行") })
        runSelected = selected
        runResults = [:]
        issues = []
        resetReadiness()
        states[id] = "准备系统安装"
        summary = id == "clt" ? "正在打开 Apple 安装器…" : "正在下载并检查 Homebrew 官方安装包…"
        log = "启动前置工具安装：\(id)\n安装需要的协议与授权由用户在系统安装器中处理。\n"
        saveRun()
        let choices = versions
        Task.detached {
            let fresh = inspect()
            let targeted = inspectVersions(choices, base: fresh)
            guard let component = catalog.first(where: { $0.id == id }) else { return }
            let refreshedAction = installAction(for: component, probes: fresh)
            if refreshedAction == .reuse {
                await MainActor.run {
                    self.results = targeted
                    self.installedResults = fresh
                    self.scannedAt = Date()
                    self.states[id] = "已复用"
                    self.installing = false
                    InstallAppDelegate.busy = false
                    self.bootstrapID = nil
                    self.summary = "检测到前置工具已就绪，请确认后续计划。"
                    self.page = 2
                    self.saveRun()
                }
                return
            }
            guard refreshedAction == .bootstrap(id) else {
                await MainActor.run { self.bootstrapFailure("环境已变化：" + actionDescription(refreshedAction) + "。请重新检测。") }
                return
            }
            if id == "clt" {
                let result = runProbe("/usr/bin/xcode-select", ["--install"])
                await MainActor.run {
                    self.log += result?.1 ?? "没有检测输出"
                    if result?.0 == 0 { self.bootstrapLaunched() }
                    else { self.bootstrapFailure("Apple 安装器未能启动，请查看日志；如已安装请重新检测。") }
                }
            } else {
                do {
                    let package = try await downloadHomebrewPackage()
                    await MainActor.run {
                        self.log += "签名检查通过：\(package.lastPathComponent)\n"
                        let configuration = NSWorkspace.OpenConfiguration()
                        configuration.activates = true
                        NSWorkspace.shared.open([package], withApplicationAt: URL(fileURLWithPath: "/System/Library/CoreServices/Installer.app"), configuration: configuration) { _, error in
                            DispatchQueue.main.async {
                                if let error { self.bootstrapFailure("无法打开系统安装器：" + error.localizedDescription) }
                                else { self.bootstrapLaunched() }
                            }
                        }
                    }
                } catch {
                    await MainActor.run { self.bootstrapFailure(error.localizedDescription) }
                }
            }
        }
    }
    func startInstall() {
        guard !installing && !scanning && bootstrapID == nil && !plan.isEmpty && !hasBlocker && scannedAt != nil else { return }
        guard preflightPassed else { runPreflight(); return }
        if let id = nextBootstrap { startBootstrap(id); return }
        let steps = plan
        let approved = actions
        let choices = versions
        let project = wantsProjectEnvironment ? URL(fileURLWithPath: projectDirectory) : nil
        installing = true
        InstallAppDelegate.busy = true
        stopRequested = false
        control = InstallControl()
        states = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, "待执行") })
        runSelected = selected
        runResults = [:]
        projectResult = nil
        issues = []
        resetReadiness()
        summary = "正在重新检查环境…"
        log = "开始时间：\(Date().formatted())\n版本响应验证不代表完整项目兼容性验证。\n"
        storageError = ""
        page = 3
        saveRun()
        let currentControl = control
        DispatchQueue.global(qos: .userInitiated).async {
            var outcome = executeInstall(components: steps, approved: approved, control: currentControl, versions: choices, probe: { inspectVersions(choices, base: inspect()) }, event: { id, state, text in
                DispatchQueue.main.async {
                    self.states[id] = state
                    self.log += text
                    // Retain the latest 100,000 characters; never let long brew output grow memory without bound.
                    if self.log.count > 100_000 { self.log = "[仅保留最近日志]\n" + String(self.log.suffix(90_000)) }
                    if state != "安装中" || text.hasPrefix("\n▶") { self.saveRun() }
                }
            })
            let base = inspect()
            let refreshed = inspectVersions(choices, base: base)
            var created: ProjectEnvironment?
            if let project, !currentControl.stopRequested, outcome.states.values.allSatisfy({ ["已复用", "已安装并验证"].contains($0) }), let python = refreshed["python"], python.available {
                DispatchQueue.main.async { self.states["project-venv"] = "创建 / 验证中"; self.summary = "正在准备项目独立环境…" }
                do {
                    created = try createProjectEnvironment(project: project, interpreter: python)
                    var states = outcome.states; states["project-venv"] = "已创建并验证"
                    outcome = InstallOutcome(states: states, summary: "工具与项目独立环境已安装并验证。")
                } catch {
                    var states = outcome.states; states["project-venv"] = "失败"
                    outcome = InstallOutcome(states: states, summary: "项目环境未就绪：" + error.localizedDescription, issues: [.init(componentID: "project-venv", title: "项目环境未就绪", detail: error.localizedDescription, suggestion: "检查所选目录及 .venv。软件会保留未完成内容，不自动删除；处理后重新检测，或选择其他项目目录。")])
                }
            } else if project != nil {
                var states = outcome.states; states["project-venv"] = currentControl.stopRequested ? "已停止" : "未执行"
                outcome = InstallOutcome(states: states, summary: outcome.summary + " 项目环境尚未创建或验证。", issues: outcome.issues)
            }
            let finished = outcome
            let projectEnvironment = created
            DispatchQueue.main.async {
                self.states = finished.states
                self.issues = finished.issues
                self.summary = finished.summary
                self.installing = false
                InstallAppDelegate.busy = false
                self.results = refreshed
                self.runResults = refreshed
                self.installedResults = base
                self.scannedAt = Date()
                self.projectResult = projectEnvironment
                self.saveRun()
                self.verifyReadiness()
            }
        }
    }
    func report() -> String {
        let lines = plan.enumerated().map { index, item in
            let probe = results[item.id]
            let action = actionDescription(actions[item.id] ?? .blocked("尚未规划")) + "；版本选择：" + (versions[item.id] ?? "auto")
            return "\(index + 1). \(item.name)：\(action)\n   检测：\(probe?.state ?? "未检测")\n   详情：\(probe?.detail ?? "请先运行环境体检")\n   路径：\(probe?.path ?? "")"
        }
        return "macOS 环境配置助手 · 安装计划预览\n\(Date().formatted())\n系统：\(ProcessInfo.processInfo.operatingSystemVersionString)\n\n" + lines.joined(separator: "\n\n") + "\n\n此文件仅为计划，不代表已执行。前置工具由系统安装器完成，可能需要管理员授权。其他工具使用 Homebrew 核心仓库，实际版本与空间占用以安装时为准。安装可能连带安装或升级依赖；应用不自动改写 shell 配置、不强制覆盖。检测仅覆盖常见路径，未发现项请先核对自定义安装。当前不提供自动回滚、版本切换、AI 框架或模型下载。\n"
    }
}

struct ContentView: View {
    @StateObject var model = Model()
    let pages = [("环境体检", "waveform.path.ecg"), ("选择工具", "square.grid.2x2"), ("确认安装", "list.bullet.clipboard"), ("安装与结果", "text.alignleft"), ("Git 配置", "person.crop.circle"), ("开始配置", "square.grid.2x2"), ("自定义选择", "checklist")]
    var body: some View {
        NavigationSplitView {
            List(selection: Binding<Int?>(get: {
                if [1, 2].contains(model.page) { return model.customMode ? 6 : 5 }
                return model.page
            }, set: { value in
                guard let value else { return }
                if value == 6 { model.beginCustom() } else { model.page = value }
            })) {
                Section("配置") {
                    Label("按用途配置", systemImage: "square.grid.2x2").tag(5)
                    Label("自定义选择", systemImage: "checklist").tag(6)
                }
                Section("管理") {
                    Label("环境体检", systemImage: "waveform.path.ecg").tag(0)
                    Label("安装与结果", systemImage: "arrow.down.circle").tag(3)
                    Label("Git 配置", systemImage: "person.crop.circle").tag(4)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("环境配置助手")
            .navigationSplitViewColumnWidth(min: 185, ideal: 205, max: 250)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("本机环境管理").font(.caption)
                        Text("按需安装 · 已有复用").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(16)
            }
        } detail: {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pages[model.page].0).font(.title2.weight(.semibold))
                        Text(["查看当前电脑已有的工具。", "只勾选你需要的工具，已安装的会复用。", "检查要安装和复用的内容，再开始。", "查看进度、处理失败或继续使用工具。", "填写信息并选择作用范围，保存前可预览。", "先选用途，再选择工具和版本。"][model.page]).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if [0, 1, 2].contains(model.page) {
                        if model.scanning { ProgressView().controlSize(.small) }
                    }
                }
                if [5, 1, 2].contains(model.page) {
                    HStack(spacing: 10) {
                        ForEach(Array([(5, "1 选用途"), (1, "2 选工具"), (2, "3 确认安装")].enumerated()), id: \.offset) { _, step in
                            Button(step.1) { if step.0 == 1 { if model.customMode { model.beginCustom() } else { model.continuePurpose() } } else { model.page = step.0 } }
                                .buttonStyle(.bordered).controlSize(.small)
                                .fontWeight(model.page == step.0 ? .semibold : .regular)
                                .disabled(model.installing || model.bootstrapID != nil || (step.0 == 1 && model.purposes.isEmpty && !model.customMode) || (step.0 == 2 && model.selected.isEmpty))
                        }
                    }
                }
                if model.page == 0 { overview }
                if model.page == 1 { selection.disabled(model.installing || model.bootstrapID != nil) }
                if model.page == 2 { plan }
                if model.page == 3 { execution }
                if model.page == 4 {
                    VStack(alignment: .leading, spacing: 12) {
                        Button("返回工具选择") { model.page = 1 }
                        GitConfigurationView().disabled(model.installing || model.bootstrapID != nil)
                    }
                }
                if model.page == 5 { purposeSelection.disabled(model.installing || model.bootstrapID != nil) }
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(pages[model.page].0)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button(action: model.scan) { Label("重新检测", systemImage: "arrow.clockwise") }
                        .help("重新检测本机工具").disabled(model.scanning || model.installing)
                        .keyboardShortcut("r", modifiers: .command)
                    Menu {
                        Button("导入配置方案…", action: model.importScheme)
                        Button("保存当前方案…", action: model.saveScheme).disabled(model.selected.isEmpty)
                    } label: { Label("配置方案", systemImage: "ellipsis.circle") }
                    .disabled(model.installing || model.bootstrapID != nil)
                }
            }
        }.navigationSplitViewStyle(.balanced).frame(minWidth: 980, minHeight: 740).tint(.accentColor).onAppear { model.scan() }
            .onChange(of: model.page) { _, value in if value == 2 { model.runPreflight() } }
            .onChange(of: model.preflightFingerprint) { _, _ in
                model.preflightReport = nil
                if model.page == 2 { model.runPreflight() }
            }
    }
    var purposeSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("你想用这台 Mac 做什么？").font(.headline)
            Text("可多选。这里仅筛选相关工具，不会替你勾选或开始安装。").font(.callout).foregroundStyle(.secondary)
            Form {
                Section {
                    ForEach(setupPurposes) { purpose in
                        Toggle(isOn: Binding(get: { model.purposes.contains(purpose.id) }, set: { chosen in
                            if chosen { model.purposes.insert(purpose.id) } else { model.purposes.remove(purpose.id) }
                        })) {
                            HStack(spacing: 12) {
                                Image(systemName: purpose.icon).font(.system(size: 18)).foregroundStyle(Color.accentColor).frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(purpose.title).font(.body.weight(.medium))
                                    Text(purpose.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 3)
                        }.toggleStyle(.checkbox)
                    }
                } header: { Text("开发用途") } footer: { Text("可多选；这里只筛选工具，不会自动勾选软件。") }
            }.formStyle(.grouped)

            HStack {
                Text(model.purposes.isEmpty ? "请选择至少一种用途" : "已选：" + model.purposeSummary).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("下一步：选择工具", action: model.continuePurpose).buttonStyle(.borderedProminent).disabled(model.purposes.isEmpty)
            }
            HStack { Text("已经知道需要什么？").font(.caption).foregroundStyle(.secondary); Button("自定义选择工具", action: model.beginCustom) }
            schemeControls
        }
    }
    var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                metric("当前系统", ProcessInfo.processInfo.operatingSystemVersionString, "desktopcomputer")
                metric("芯片架构", architecture, "cpu")
                metric("已检测到", "\(model.detected) / \(catalog.count) 项", "checkmark.circle")
            }
            HStack {
                Text("工具检测结果").font(.headline)
                Spacer()
                if let date = model.scannedAt { Text("更新于 \(date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
            }
            Text("检查常见安装位置及工具响应，不会更改系统。自定义目录、项目虚拟环境及部分版本管理器不在此次检测范围内。").font(.caption).foregroundStyle(.secondary)
            ScrollView { LazyVStack(spacing: 10) { ForEach(catalog) { item in toolRow(item) } } }
            HStack {
                Button("按用途配置") { model.page = 5 }
                Spacer()
                Button("选择需要的环境 →") { model.page = 1 }.buttonStyle(.borderedProminent)
            }
        }
    }
    var architecture: String {
        #if arch(arm64)
        return "Apple Silicon · arm64"
        #else
        return "Intel · x86_64"
        #endif
    }
    func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .semibold)).lineLimit(2)
        }.frame(maxWidth: .infinity, minHeight: 62, alignment: .leading).padding(16).background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
    func toolRow(_ item: Component) -> some View {
        let probe = model.installedResults[item.id]
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon).font(.title3).foregroundStyle(Color.accentColor).frame(width: 28).padding(.top, 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name).fontWeight(.semibold)
                Text(probe?.detail ?? (model.scanning ? "正在检测…" : "尚未检测")).font(.caption).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                if let path = probe?.path, !path.isEmpty { Text(path).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text(probe?.state ?? "待检测").font(.caption).foregroundStyle(probe?.available == true ? Color.accentColor : Color.secondary)
                if let probe, !probe.available {
                    Button(item.id == "clt" || probe.path.isEmpty ? "安装…" : "查看处理方案") { model.selectForInstall([item.id]) }
                        .controlSize(.small).disabled(model.scanning || model.installing || model.bootstrapID != nil)
                }
            }
        }.padding(14).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
    var selection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(model.purposeSummary.isEmpty ? "可自行选择需要的工具" : "当前用途：" + model.purposeSummary).font(.callout)
                Spacer()
                if !model.customMode { Toggle("查看全部工具", isOn: $model.showAllTools).toggleStyle(.switch).controlSize(.small) }
            }
            TextField("搜索组件", text: $model.query).textFieldStyle(.roundedBorder)
            List {
                Group {
                    ForEach(model.visibleTools) { item in
                        let explicit = model.selected.contains(item.id)
                        let dependency = model.required.contains(item.id) && !explicit
                        HStack {
                            Toggle(isOn: Binding(get: { model.required.contains(item.id) }, set: { _ in model.toggle(item.id) })) { EmptyView() }.labelsHidden().toggleStyle(.checkbox).disabled(dependency)
                            Image(systemName: item.icon).foregroundStyle(Color.accentColor).frame(width: 28)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name).fontWeight(.semibold)
                                Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                                if let installed = model.installedResults[item.id], installed.available {
                                    Text("已安装：\(versionString(installed) ?? installed.detail)").font(.caption).foregroundStyle(Color.accentColor)
                                } else { Text(model.scanning ? "检测中…" : "尚未检测到可用安装").font(.caption).foregroundStyle(.secondary) }
                                if model.required.contains(item.id) && versionOptions(item.id).count > 1 {
                                    Picker("目标版本", selection: Binding(get: { model.versions[item.id] ?? "auto" }, set: { model.setVersion(item.id, $0) })) {
                                        ForEach(versionOptions(item.id)) { option in Text(option.label).tag(option.id) }
                                    }.frame(maxWidth: 350).disabled(model.scanning || dependency)
                                }
                                if model.required.contains(item.id) {
                                    Text(versionMatches(model.results[item.id], requested: model.versions[item.id] ?? "auto") ? "所选版本可复用，无需下载" : "所选环境需要安装或处理")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if dependency { Text("依赖自动加入").font(.caption).foregroundStyle(Color.accentColor) }
                        }.padding(.vertical, 8)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            if model.selected.contains("python") { projectEnvironmentControls }
            if model.selected.contains("python") {
                Text("版本按系列选择，不替换系统默认版本。Python 3.10 已结束官方支持，旧项目可按需选择。").font(.caption).foregroundStyle(.secondary)
            }
            if model.selected.contains("git") {
                HStack { Text("Git 用户信息可以稍后设置。").font(.caption).foregroundStyle(.secondary); Button("配置 Git（可选）") { model.page = 4 } }
            }
            HStack {
                Text("手动选择 \(model.selected.count) 项 · 含依赖共 \(model.required.count) 项").foregroundStyle(.secondary)
                Spacer()
                Button("下一步：确认安装") { model.page = 2 }.buttonStyle(.borderedProminent).disabled(model.selected.isEmpty || model.scanning)
            }
            schemeControls
        }
    }
    var plan: some View {
        VStack(alignment: .leading, spacing: 18) {
            planSummary
            Text("只安装你选的工具及必要依赖。安装可能调整依赖版本，不自动回滚。新安装的 AI 工具需自行登录；Docker 首次启动的协议及初始化由你完成。").font(.callout).foregroundStyle(.secondary)
            if model.scannedAt == nil { Text("检测完成后，计划会根据本机结果更新。").foregroundStyle(.orange) }
            preflightPanel
            if model.plan.isEmpty {
                Spacer(); Text("还没有选择组件，请先到“选择环境”添加。").foregroundStyle(.secondary); Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(model.plan.enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(index + 1)").font(.caption.bold()).frame(width: 26, height: 26).background(Color.accentColor.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.name).fontWeight(.semibold)
                                    Text(friendlyAction(item, action: model.actions[item.id], probe: model.results[item.id], version: model.versions[item.id] ?? "auto")).font(.callout).foregroundStyle(.secondary)
                                    if !model.selected.contains(item.id) { Text("必要依赖，自动加入").font(.caption).foregroundStyle(Color.accentColor) }
                                    DisclosureGroup("查看详情") {
                                        Text(actionDescription(model.actions[item.id] ?? .blocked("尚未规划"))).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                                        if let target = model.results[item.id], target.available { Text(target.path).font(.caption).textSelection(.enabled) }
                                    }.font(.caption)
                                }
                                Spacer()
                                Image(systemName: model.results[item.id]?.available == true ? "checkmark.circle" : "circle.dashed").foregroundStyle(Color.accentColor)
                            }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            if model.hasBlocker {
                HStack {
                    Text("请先处理上面的前置条件，再重新检测。").font(.caption).foregroundStyle(.orange)
                    Spacer()
                    Button("Homebrew 官网") { NSWorkspace.shared.open(URL(string: "https://brew.sh")!) }
                    Button("Apple 安装说明") { NSWorkspace.shared.open(URL(string: "https://developer.apple.com/xcode/resources/")!) }
                }
            }
            HStack {
                Button("返回选择") { model.page = 1 }
                Spacer()
                Button(model.copied ? "已复制" : "复制计划") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.report(), forType: .string)
                    model.copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { model.copied = false }
                }.disabled(model.plan.isEmpty || model.scanning)
                Button("导出计划…", action: export).buttonStyle(.borderedProminent).disabled(model.plan.isEmpty || model.scanning)
                Button(model.nextBootstrap != nil ? "安装前置工具…" : (model.installCount == 0 ? (model.wantsProjectEnvironment ? "配置项目环境…" : "验证并复用") : "开始安装…"), action: confirmInstall)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.plan.isEmpty || model.scanning || model.installing || model.bootstrapID != nil || model.hasBlocker || model.scannedAt == nil || !model.preflightPassed)
            }
        }
    }
    var execution: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if model.installing { ProgressView().controlSize(.small) }
                Text(model.summary).font(.headline)
                Spacer()
                if model.installing && model.bootstrapID == nil {
                    Button(model.stopRequested ? "已请求停止" : "当前步骤后停止", action: model.requestStop).disabled(model.stopRequested)
                }
            }
            if model.bootstrapID != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("系统安装步骤").font(.headline)
                    Text("请在 Apple / Homebrew 系统安装器中自行阅读协议并完成授权。关闭安装器窗口不代表安装成功；返回这里验证后，才能继续后续步骤。").font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button(model.scanning ? "正在验证…" : "安装完成，验证并继续", action: model.scan)
                            .buttonStyle(.borderedProminent).disabled(model.installing || model.scanning)
                        Button("结束等待", action: model.endBootstrapWait).disabled(model.installing || model.scanning)
                    }
                }.padding(14).background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            if !model.storageError.isEmpty { Text(model.storageError).font(.caption).foregroundStyle(.orange) }
            if let state = model.states["project-venv"] {
                HStack { Label("Python 项目独立环境", systemImage: "folder"); Spacer(); Text(state).foregroundStyle(.secondary) }
            }
            if let project = model.projectResult { Text("项目解释器：" + project.python.path).font(.caption).textSelection(.enabled) }
            failurePanel
            readinessPanel
            if !model.states.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(catalog.filter { model.states[$0.id] != nil }) { item in
                            HStack { Label(item.name, systemImage: item.icon); Spacer(); Text(model.states[item.id] ?? "").foregroundStyle(.secondary) }
                                .padding(10).background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }.frame(maxHeight: 210)
            }
            if model.taskSucceeded && !model.installing {
                Label("所选工具已安装，运行状态见上方验证", systemImage: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                ForEach(catalog.filter { model.runSelected.contains($0.id) && model.runResults[$0.id]?.available == true }) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        if applicationNames[item.id] != nil, let path = model.runResults[item.id]?.path {
                            Button("打开软件") { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
                        } else if let path = model.runResults[item.id]?.path {
                            Button("复制启动命令") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'", forType: .string)
                            }
                        }
                    }.font(.callout)
                }
                Text("安装成功不代表已登录账号或服务已运行；请在对应软件中完成首次设置。").font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("查看运行日志（遇到问题时展开）") {
                ScrollView {
                    Text(model.log.isEmpty ? "尚无日志。" : model.log)
                        .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.frame(maxHeight: 180).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }.font(.caption)
            Spacer(minLength: 0)
            HStack {
                if model.savedRun != nil && !model.installing && model.bootstrapID == nil {
                    Button("载入上次记录", action: model.restoreRun)
                }
                Spacer()
                Button("导出日志…") {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "环境安装日志.txt"
                    if panel.runModal() == .OK, let url = panel.url {
                        do { try (model.summary + "\n\n" + model.log).write(to: url, atomically: true, encoding: .utf8) }
                        catch { NSAlert(error: error).runModal() }
                    }
                }.disabled(model.log.isEmpty)
                Button(model.taskSucceeded ? "完成，返回首页" : "重新检测并查看计划") {
                    if model.taskSucceeded { model.page = 5 }
                    else { model.reviewAfterFailure() }
                }.buttonStyle(.borderedProminent).disabled(model.installing || model.scanning || model.bootstrapID != nil)
            }
        }
    }
    func confirmInstall() {
        let alert = NSAlert()
        if let id = model.nextBootstrap {
            alert.messageText = id == "clt" ? "安装 Apple 命令行工具？" : "安装 Homebrew？"
            alert.informativeText = id == "clt" ? "将调用 xcode-select --install 打开 Apple 系统安装器。请在安装器中阅读协议并确认安装，完成后返回软件验证。" : "将通过 GitHub 官方发行信息下载 Homebrew 安装包，检查签名后打开系统安装器。可能需要管理员授权；请在安装器内完成。不会保存你的密码。完成后返回软件验证，再继续安装所选工具。"
            alert.addButton(withTitle: "开始引导安装")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn { model.startInstall() }
            return
        }
        alert.messageText = model.installCount == 0 ? (model.wantsProjectEnvironment ? "确认配置项目独立环境？" : "验证并复用现有工具？") : "确认执行以下安装？"
        let changes = model.plan.compactMap { item -> String? in
            guard case .install(let command) = model.actions[item.id] else { return nil }
            return command.display
        }
        let names = model.plan.filter { if case .install = model.actions[$0.id] { return true }; return false }.map { $0.name }.joined(separator: "、")
        let projectNote = model.wantsProjectEnvironment ? "\n\n项目环境：" + URL(fileURLWithPath: model.projectDirectory).appendingPathComponent(".venv").path + "\n将创建或验证并复用此环境，不改写全局 Python。" : ""
        alert.informativeText = (changes.isEmpty ? "将验证并复用已安装的工具。" : "将安装：" + names + "\n\n其他已安装工具会复用。安装可能调整依赖，不支持自动回滚。登录和首次初始化由你完成。停止将在当前步骤完成后生效。") + projectNote
        alert.addButton(withTitle: "确认执行")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn { model.startInstall() }
    }
    func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "环境配置计划.txt"
        if panel.runModal() == .OK, let url = panel.url {
            do { try model.report().write(to: url, atomically: true, encoding: .utf8) }
            catch { let alert = NSAlert(error: error); alert.runModal() }
        }
    }
}

final class InstallAppDelegate: NSObject, NSApplicationDelegate {
    static var busy = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.busy {
            let alert = NSAlert()
            alert.messageText = "安装任务仍在执行"
            alert.informativeText = "请先在执行记录中选择“当前步骤后停止”，等待任务结束后退出。强制退出可能留下部分安装。"
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }
}

struct EnvironmentApp: App {
    @NSApplicationDelegateAdaptor(InstallAppDelegate.self) var delegate
    var body: some Scene {
        Window("环境配置助手", id: "main") { ContentView() }
            .defaultSize(width: 1080, height: 820)
            .windowToolbarStyle(.unified)
            .commands { CommandGroup(replacing: .newItem) {} }
    }
}

@main
enum Launcher {
    static func main() {
        if CommandLine.arguments.contains("--readiness-test") {
            Task.detached {
                do { try await runtimeReadinessTests(); exit(0) }
                catch { fputs("Readiness test failed: \(error)\n", stderr); exit(1) }
            }
            dispatchMain()
        }
        if CommandLine.arguments.contains("--git-config-test") {
            do { try gitConfigurationTests() } catch { fputs("Git test failed: \(error)\n", stderr); exit(1) }
            return
        }
        if CommandLine.arguments.contains("--environment-test") {
            do { try environmentFeatureTests() } catch { fputs("Environment test failed: \(error)\n", stderr); exit(1) }
            return
        }
        if CommandLine.arguments.contains("--expanded-test") {
            do { try expandedCatalogTests() } catch { fputs("Catalog test failed: \(error)\n", stderr); exit(1) }
            return
        }
        if CommandLine.arguments.contains("--installer-test") { installerSelfTests(); installDiagnosticsTests(); bootstrapSelfTests(); versionSelectionTests(); purposeSelfTests(); return }
        if CommandLine.arguments.contains("--self-test") {
            for item in catalog {
                for dependency in item.dependencies {
                    precondition(catalog.firstIndex { $0.id == dependency }! < catalog.firstIndex { $0.id == item.id }!, "Dependency order invalid")
                }
            }
            precondition(dependencyClosure(["pnpm"]) == ["pnpm", "node", "brew", "clt"])
            precondition(dependencyClosure(["python", "ollama"]) == ["python", "ollama", "brew", "clt"])
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(inspect()), let text = String(data: data, encoding: .utf8) { print(text) }
            return
        }
        NSApplication.shared.setActivationPolicy(.regular)
        EnvironmentApp.main()
    }
}
