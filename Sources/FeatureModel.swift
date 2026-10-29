import SwiftUI
import AppKit

extension Model {
    var wantsProjectEnvironment: Bool { selected.contains("python") && projectEnvironmentEnabled }
    var preflightFingerprint: String {
        let versionPart = versions.sorted { $0.key < $1.key }.map { $0.key + "=" + $0.value }.joined(separator: ";")
        let probePart = plan.map { $0.id + ":" + (results[$0.id]?.state ?? "") + ":" + (results[$0.id]?.path ?? "") + ":" + (versionString(results[$0.id]) ?? "") }.joined(separator: ";")
        return configHash(Data((selected.sorted().joined(separator: ",") + "|" + versionPart + "|" + probePart + "|" + String(wantsProjectEnvironment) + "|" + (wantsProjectEnvironment ? projectDirectory : "")).utf8))
    }
    var preflightPassed: Bool {
        guard let report = preflightReport else { return false }
        return !preflightBusy && !report.blocked && report.fingerprint == preflightFingerprint && Date().timeIntervalSince(report.date) < 300
    }
    func runPreflight() {
        guard !preflightBusy && !installing && !scanning && !plan.isEmpty else { return }
        preflightBusy = true
        preflightReport = nil
        let key = preflightFingerprint
        let steps = plan, approved = actions, choices = versions, current = results, base = installedResults
        let wantsProject = wantsProjectEnvironment
        let project = wantsProject && !projectDirectory.isEmpty ? URL(fileURLWithPath: projectDirectory) : nil
        Task {
            var report = await Task.detached { await performPreflight(fingerprint: key, components: steps, actions: approved, versions: choices, probes: current, base: base, project: project) }.value
            if wantsProject && project == nil {
                report = PreflightReport(fingerprint: key, date: report.date, items: report.items + [.init(id: "project", title: "选择项目", level: "blocked", detail: "已开启项目虚拟环境，请返回选择工具页面指定项目目录。")])
            }
            preflightBusy = false
            if key == preflightFingerprint { preflightReport = report }
            else if page == 2 { runPreflight() }
        }
    }
    func verifyReadiness() {
        guard !readinessBusy && !installing && !runSelected.isEmpty else { return }
        readinessBusy = true
        let generation = UUID()
        readinessGeneration = generation
        let ids = runSelected, project = projectResult
        let choices = runVersions
        let missingProject = states["project-venv"] != nil && project == nil
        Task {
            let verified = await Task.detached {
                let fresh = inspectVersions(choices, base: inspect())
                let checks = await readinessChecks(ids: ids, probes: fresh, project: project)
                return (fresh, checks)
            }.value
            var checks = verified.1
            guard generation == readinessGeneration else { return }
            if missingProject { checks.append(.init(id: "project-not-ready", title: "项目独立环境", level: "blocked", detail: "项目虚拟环境尚未创建或验证。全局 Python 可运行不代表项目环境已就绪。")) }
            readiness = checks
            readinessDate = Date()
            readinessIsHistorical = false
            runResults = verified.0
            readinessBusy = false
            saveRun()
        }
    }
    func resetReadiness() {
        readinessGeneration = UUID(); readinessBusy = false; readiness = []; readinessDate = nil; readinessIsHistorical = false
    }
    func chooseProject() {
        let panel = NSOpenPanel()
        panel.title = "选择需要独立 Python 环境的项目目录"
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url { projectDirectory = url.resolvingSymlinksInPath().path }
    }
    func saveScheme() {
        guard !selected.isEmpty && !installing else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "环境配置方案.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = String(url.deletingPathExtension().lastPathComponent.prefix(120))
        let custom = customMode || !selected.isSubset(of: toolsForPurposes(purposes))
        let scheme = ConfigurationScheme(schemaVersion: 1, name: name, purposes: purposes.sorted(), customMode: custom, tools: selected.sorted(), versions: versions.filter { selected.contains($0.key) }, projectVirtualEnvironment: wantsProjectEnvironment)
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(scheme).write(to: url, options: .atomic)
            schemeMessage = "方案已保存，包含工具、版本及项目环境选项；不包含项目路径、Git 身份或账号凭据。"
        } catch { schemeMessage = "保存失败：" + error.localizedDescription }
    }
    func importScheme() {
        guard !installing && bootstrapID == nil else { return }
        let panel = NSOpenPanel(); panel.title = "导入环境配置方案"; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
            let data = try handle.read(upToCount: 512_001) ?? Data()
            let scheme = try decodeScheme(data)
            let names = scheme.tools.compactMap { id in catalog.first { $0.id == id }?.name }.joined(separator: "、")
            let alert = NSAlert(); alert.messageText = "载入配置方案：\(scheme.name)？"
            alert.informativeText = "所选工具：\(names)\n\n将替换当前选择，不会立即安装。项目目录需要在这台电脑上重新选择。"
            alert.addButton(withTitle: "载入选择"); alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            selected = Set(scheme.tools); versions = scheme.versions; purposes = Set(scheme.purposes)
            customMode = scheme.customMode; showAllTools = scheme.customMode; query = ""
            projectEnvironmentEnabled = scheme.projectVirtualEnvironment; projectDirectory = ""
            schemeMessage = "已载入方案。请检查本机状态及所选版本，再确认安装。"
            preflightReport = nil; page = 1
            if !scanning { scan() }
        } catch { schemeMessage = "导入失败：" + error.localizedDescription }
    }
}

extension ContentView {
    var schemeControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("导入配置方案…", action: model.importScheme)
                Button("保存当前方案…", action: model.saveScheme).disabled(model.selected.isEmpty)
                Spacer()
            }.disabled(model.installing || model.bootstrapID != nil)
            if !model.schemeMessage.isEmpty { Text(model.schemeMessage).font(.caption).foregroundStyle(.secondary) }
        }
    }
    var projectEnvironmentControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("为项目创建独立 Python 环境（.venv）", isOn: $model.projectEnvironmentEnabled)
            if model.projectEnvironmentEnabled {
                HStack {
                    Text(model.projectDirectory.isEmpty ? "请选择项目目录" : model.projectDirectory).font(.caption).textSelection(.enabled).lineLimit(2)
                    Spacer()
                    Button("选择项目…", action: model.chooseProject)
                }
                Text("兼容的现有环境会复用；版本冲突或未知 .venv 会停止，不覆盖。只验证解释器与 pip，不自动运行项目业务代码。").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(12).background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
    var preflightPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("安装前检查").font(.headline)
                if model.preflightBusy { ProgressView().controlSize(.small) }
                Spacer()
                Button(model.preflightBusy ? "检查中…" : "重新检查", action: model.runPreflight).disabled(model.preflightBusy || model.installing || model.scanning)
            }
            if let report = model.preflightReport {
                Text(report.blocked ? "有阻断项，请先处理。" : "阻断检查通过。黄色提醒请在安装前确认。").font(.caption).foregroundStyle(report.blocked ? .orange : .secondary)
                ScrollView { VStack(alignment: .leading, spacing: 10) { ForEach(report.items) { checkRow($0) } } }.frame(maxHeight: 155)
                if !model.preflightPassed && !report.blocked { Text("检查已过期，请重新检查。").font(.caption).foregroundStyle(.orange) }
            } else {
                Text(model.preflightBusy ? "正在检查版本入口、空间、项目环境及下载源连通性…" : "安装前需完成检查。可用结果保留 5 分钟。").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(12).background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
    func checkRow(_ item: CheckItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.level == "ok" ? "checkmark.circle.fill" : (item.level == "blocked" ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"))
                .foregroundStyle(item.level == "ok" ? Color.accentColor : (item.level == "blocked" ? Color.red : Color.orange))
            VStack(alignment: .leading, spacing: 4) { Text(item.title).font(.caption.bold()); Text(item.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
        }
    }
    var readinessPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.runSelected.isEmpty && !model.installing {
                HStack { Text("运行状态验证").font(.headline); if model.readinessBusy { ProgressView().controlSize(.small) }; Spacer(); Button("重新验证", action: model.verifyReadiness).disabled(model.readinessBusy) }
                readinessSummary
                if let date = model.readinessDate { Text((model.readinessIsHistorical ? "历史验证（请重新验证当前状态）：" : "验证时间：") + date.formatted()).font(.caption2).foregroundStyle(.secondary) }
                if model.readiness.isEmpty { Text("尚未完成运行状态验证。").font(.caption).foregroundStyle(.secondary) }
                ScrollView { VStack(alignment: .leading, spacing: 10) { ForEach(model.readiness) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        checkRow(item)
                        if !model.readinessIsHistorical { readinessActions(item) }
                    }
                } } }.frame(maxHeight: 155)
            }
        }
    }
}
