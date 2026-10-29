import SwiftUI
import AppKit
import CryptoKit
import Darwin

struct GitConfigPlan {
    let target: URL
    let before: Data?
    let git: String
    let name: String
    let email: String
}

struct GitConfigReceipt: Codable {
    let target: URL
    let backup: URL?
    let afterHash: String
}

let gitBackupRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("EnvSetupAssistant/GitBackups")

func configHash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

func gitExecutable() throws -> String {
    for path in ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"] where FileManager.default.isExecutableFile(atPath: path) {
        if path == "/usr/bin/git" && runProbe("/usr/bin/xcode-select", ["-p"])?.0 != 0 { continue }
        if runProbe(path, ["--version"])?.0 == 0 { return path }
    }
    throw SetupError.message("请先在选择环境中安装 Git。")
}

func configData(_ target: URL) throws -> Data? {
    guard FileManager.default.fileExists(atPath: target.path) else { return nil }
    let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular else { throw SetupError.message("配置路径不是普通文件，暂不自动修改符号链接或其他特殊文件。") }
    return try Data(contentsOf: target)
}

func gitConfigTarget(scope: String, project: String, git: String) throws -> URL {
    if scope == "global" {
        let environment = ProcessInfo.processInfo.environment
        if let override = environment["GIT_CONFIG_GLOBAL"], !override.isEmpty {
            guard override.hasPrefix("/") else { throw SetupError.message("GIT_CONFIG_GLOBAL 使用了相对路径，请先调整为绝对路径。") }
            return URL(fileURLWithPath: override)
        }
        let standard = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gitconfig")
        let xdg = environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
        let alternative = xdg.appendingPathComponent("git/config")
        return !FileManager.default.fileExists(atPath: standard.path) && FileManager.default.fileExists(atPath: alternative.path) ? alternative : standard
    }
    guard scope == "project", !project.isEmpty else { throw SetupError.message("请选择用户级或项目级范围；项目级还需要选择 Git 仓库目录。") }
    guard let (code, path) = runProbe(git, ["-C", project, "rev-parse", "--path-format=absolute", "--git-path", "config"]), code == 0, path.hasPrefix("/") else {
        throw SetupError.message("所选目录不是可用的 Git 仓库。")
    }
    return URL(fileURLWithPath: path)
}

func makeGitConfigPlan(target: URL, git: String, name: String, email: String) throws -> GitConfigPlan {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanName.isEmpty, !cleanName.contains(where: { $0.isNewline || $0 == "\0" }),
          cleanEmail.contains("@"), !cleanEmail.contains(where: { $0.isWhitespace || $0 == "\0" }) else {
        throw SetupError.message("请填写有效的用户名与邮箱，不能包含换行或空字符。")
    }
    return .init(target: target, before: try configData(target), git: git, name: cleanName, email: cleanEmail)
}

func lockedConfigWrite(target: URL, expected: Data?, replacement: Data?) throws {
    let lockPath = target.path + ".lock"
    let descriptor = Darwin.open(lockPath, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else { throw SetupError.message("无法取得配置写入锁，请确认没有其他 Git 操作，且目录可写。") }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    var ownsLock = true
    defer { try? handle.close(); if ownsLock { Darwin.unlink(lockPath) } }
    guard try configData(target) == expected else { throw SetupError.message("配置文件已发生变化，请重新读取、预览后再保存。") }
    if let replacement {
        try handle.write(contentsOf: replacement)
        try handle.synchronize()
        guard Darwin.rename(lockPath, target.path) == 0 else { throw SetupError.message("无法提交配置文件。") }
        ownsLock = false
    } else if expected != nil {
        guard Darwin.unlink(target.path) == 0 else { throw SetupError.message("无法恢复原先不存在配置文件的状态。") }
    }
}

func applyGitConfig(_ plan: GitConfigPlan, backupRoot: URL = gitBackupRoot, persist: Bool = true) throws -> GitConfigReceipt {
    let folder = backupRoot.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let stage = folder.appendingPathComponent("staged.config")
    try (plan.before ?? Data()).write(to: stage)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stage.path)
    defer { try? FileManager.default.removeItem(at: stage) }
    for (key, value) in [("user.name", plan.name), ("user.email", plan.email)] {
        guard let response = runProbe(plan.git, ["config", "--file", stage.path, "--replace-all", key, value]), response.0 == 0 else { throw SetupError.message("Git 无法生成新配置，原文件未修改。") }
    }
    let updated = try Data(contentsOf: stage)
    let backup = plan.before == nil ? nil : folder.appendingPathComponent("original.config")
    if let before = plan.before, let backup {
        try before.write(to: backup)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
    }
    let receipt = GitConfigReceipt(target: plan.target, backup: backup, afterHash: configHash(updated))
    // Persist recovery metadata before modifying the user's file.
    if persist { try JSONEncoder().encode(receipt).write(to: backupRoot.appendingPathComponent("last.json"), options: .atomic) }
    try lockedConfigWrite(target: plan.target, expected: plan.before, replacement: updated)
    return receipt
}

func restoreGitConfig(_ receipt: GitConfigReceipt) throws {
    guard let current = try configData(receipt.target), configHash(current) == receipt.afterHash else { throw SetupError.message("配置在保存后已被修改，已停止恢复，避免覆盖后续变更。") }
    let previous = try receipt.backup.map { try Data(contentsOf: $0) }
    try lockedConfigWrite(target: receipt.target, expected: current, replacement: previous)
}

@MainActor
final class GitForm: ObservableObject {
    @Published var scope = "choose"
    @Published var project = ""
    @Published var name = ""
    @Published var email = ""
    @Published var status = "请自行选择配置范围并填写信息。"
    @Published var busy = false
    @Published var receipt: GitConfigReceipt?
}

struct GitConfigurationView: View {
    @StateObject private var form = GitForm()
    var scope: String { get { form.scope } nonmutating set { form.scope = newValue } }
    var project: String { get { form.project } nonmutating set { form.project = newValue } }
    var name: String { get { form.name } nonmutating set { form.name = newValue } }
    var email: String { get { form.email } nonmutating set { form.email = newValue } }
    var status: String { get { form.status } nonmutating set { form.status = newValue } }
    var busy: Bool { get { form.busy } nonmutating set { form.busy = newValue } }
    var receipt: GitConfigReceipt? { get { form.receipt } nonmutating set { form.receipt = newValue } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("作用范围", selection: $form.scope) {
                Text("请选择范围").tag("choose")
                Text("用户级（当前用户所有仓库）").tag("global")
                Text("项目级（所选 Git 仓库）").tag("project")
            }.pickerStyle(.menu)
            if scope == "project" {
                HStack {
                    Text(project.isEmpty ? "尚未选择项目" : project).font(.caption).textSelection(.enabled)
                    Button("选择仓库…") {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url { project = url.path }
                    }
                }
            }
            TextField("Git 用户名（user.name）", text: $form.name).textFieldStyle(.roundedBorder)
            TextField("Git 邮箱（user.email）", text: $form.email).textFieldStyle(.roundedBorder)
            Text("用户名和邮箱会写入今后的提交记录；可填写代码托管平台提供的隐私邮箱。此处不登录账号，也不配置密码、Token 或 SSH 密钥。").font(.callout).foregroundStyle(.secondary)
            Text("项目范围以预览中的实际配置文件为准，同一仓库的多个 worktree 可能共享配置。修改前保存备份，若文件后来被其他操作修改，恢复会停止。").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("读取当前配置", action: readCurrent).disabled(scope == "choose")
                Spacer()
                Button("预览并保存…", action: preview).buttonStyle(.borderedProminent).disabled(scope == "choose" || name.isEmpty || email.isEmpty)
            }
            Divider()
            if busy { ProgressView().controlSize(.small) }
            Text(status).font(.callout).textSelection(.enabled)
            if let receipt {
                Text("最近保存：\(receipt.target.path)").font(.caption).textSelection(.enabled)
                Button("恢复上次修改…") {
                    let alert = NSAlert(); alert.messageText = "恢复上次 Git 配置？"; alert.informativeText = receipt.target.path
                    alert.addButton(withTitle: "恢复"); alert.addButton(withTitle: "取消")
                    if alert.runModal() == .alertFirstButtonReturn {
                        do { try restoreGitConfig(receipt); self.receipt = nil; status = "已恢复修改前的配置。" }
                        catch { status = error.localizedDescription }
                    }
                }
            }
            Spacer()
        }.disabled(busy).onAppear {
            if receipt == nil, let data = try? Data(contentsOf: gitBackupRoot.appendingPathComponent("last.json")) { receipt = try? JSONDecoder().decode(GitConfigReceipt.self, from: data) }
        }
    }
    func readCurrent() {
        do {
            let git = try gitExecutable()
            let target = try gitConfigTarget(scope: scope, project: project, git: git)
            _ = try configData(target)
            name = runProbe(git, ["config", "--file", target.path, "--get", "user.name"]).flatMap { $0.0 == 0 ? $0.1 : nil } ?? ""
            email = runProbe(git, ["config", "--file", target.path, "--get", "user.email"]).flatMap { $0.0 == 0 ? $0.1 : nil } ?? ""
            status = "读取的是将修改的这个文件：\(target.path)；未展开其他 include 文件。"
        } catch { status = error.localizedDescription }
    }
    func preview() {
        do {
            let git = try gitExecutable()
            let target = try gitConfigTarget(scope: scope, project: project, git: git)
            let plan = try makeGitConfigPlan(target: target, git: git, name: name, email: email)
            let alert = NSAlert(); alert.messageText = "确认保存 Git 身份信息？"
            alert.informativeText = "配置文件：\(target.path)\n\nuser.name = \(plan.name)\nuser.email = \(plan.email)\n\n会备份现有文件，并保留其他配置项。不会改写已有提交。"
            alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            busy = true
            Task {
                do {
                    let saved = try await Task.detached { try applyGitConfig(plan) }.value
                    receipt = saved; status = "已保存。备份已保存在本机，可恢复上次修改。"
                } catch { status = error.localizedDescription }
                busy = false
            }
        } catch { status = error.localizedDescription }
    }
}

func gitConfigurationTests() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("envsetup-git-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let target = folder.appendingPathComponent("config")
    let original = Data("[alias]\n\tco = checkout\n[user]\n\tname = Before\n\temail = before@example.test\n".utf8)
    try original.write(to: target)
    let git = try gitExecutable()
    let plan = try makeGitConfigPlan(target: target, git: git, name: "After", email: "after@example.test")
    let receipt = try applyGitConfig(plan, backupRoot: folder.appendingPathComponent("backups"), persist: false)
    precondition(runProbe(git, ["config", "--file", target.path, "--get", "alias.co"])?.1 == "checkout")
    precondition(runProbe(git, ["config", "--file", target.path, "--get", "user.email"])?.1 == "after@example.test")
    try restoreGitConfig(receipt)
    let restored = try Data(contentsOf: target)
    precondition(restored == original)
    let stale = try makeGitConfigPlan(target: target, git: git, name: "Other", email: "other@example.test")
    let changed = Data("[user]\nname = Concurrent\n".utf8); try changed.write(to: target)
    do { _ = try applyGitConfig(stale, backupRoot: folder.appendingPathComponent("backups"), persist: false); preconditionFailure("Must not overwrite concurrent changes") } catch {}
    let retained = try Data(contentsOf: target)
    precondition(retained == changed)
    print("PASS: Git config preserves other keys, backups, restore, concurrent edit protection (temporary files only)")
}
