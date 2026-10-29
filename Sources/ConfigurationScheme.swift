import Foundation

struct ConfigurationScheme: Codable {
    let schemaVersion: Int
    let name: String
    let purposes: [String]
    let customMode: Bool
    let tools: [String]
    let versions: [String: String]
    let projectVirtualEnvironment: Bool
}

func decodeScheme(_ data: Data) throws -> ConfigurationScheme {
    guard data.count <= 512_000 else { throw SetupError.message("配置方案超过大小限制。") }
    let scheme = try JSONDecoder().decode(ConfigurationScheme.self, from: data)
    guard scheme.schemaVersion == 1 else { throw SetupError.message("不支持此配置方案版本。") }
    guard scheme.name.count <= 120, scheme.tools.count <= catalog.count,
          Set(scheme.tools).count == scheme.tools.count,
          Set(scheme.tools).isSubset(of: Set(catalog.map(\.id))),
          Set(scheme.purposes).isSubset(of: Set(setupPurposes.map(\.id))) else { throw SetupError.message("方案包含未知工具、用途或无效内容，请检查文件。") }
    for (id, value) in scheme.versions {
        guard scheme.tools.contains(id), versionOptions(id).contains(where: { $0.id == value }) else { throw SetupError.message("方案中的工具版本不受当前软件支持：\(id)。") }
    }
    guard !scheme.projectVirtualEnvironment || scheme.tools.contains("python") else { throw SetupError.message("项目虚拟环境方案需要选择 Python。") }
    return scheme
}

func environmentFeatureTests() throws {
    let start = Date()
    let detachedChild = limitedProcess("/bin/sh", ["-c", "/bin/sleep 2 & exit 0"], timeout: 1)
    precondition(detachedChild.code == 0 && Date().timeIntervalSince(start) < 1.8)
    let timeout = limitedProcess("/bin/sleep", ["2"], timeout: 0.1)
    precondition(timeout.timedOut && timeout.code != 0)
    let scheme = ConfigurationScheme(schemaVersion: 1, name: "AI project", purposes: ["local-ai"], customMode: false, tools: ["python", "ollama"], versions: ["python": "3.12"], projectVirtualEnvironment: true)
    let encoded = try JSONEncoder().encode(scheme)
    let decoded = try decodeScheme(encoded)
    precondition(decoded.versions["python"] == "3.12" && decoded.projectVirtualEnvironment)
    let invalid = ConfigurationScheme(schemaVersion: 1, name: "bad", purposes: [], customMode: true, tools: ["unknown;command"], versions: [:], projectVirtualEnvironment: false)
    do { _ = try decodeScheme(JSONEncoder().encode(invalid)); preconditionFailure("Must reject unknown tools") } catch {}
    precondition(spaceCheck(id: "x", title: "x", available: 100_000_000, suggested: 2_000_000_000).level == "blocked")
    precondition(spaceCheck(id: "x", title: "x", available: 1_000_000_000, suggested: 2_000_000_000).level == "warning")
    precondition(spaceCheck(id: "x", title: "x", available: 4_000_000_000, suggested: 2_000_000_000).level == "ok")
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("envsetup-project-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let python = inspect()["python"]!
    guard python.available else { throw SetupError.message("项目环境测试需要已有 Python。") }
    let first = try createProjectEnvironment(project: folder, interpreter: python)
    precondition(!first.reused)
    let health = try pythonHealth(first.python.path)
    precondition(health.isolated)
    let second = try createProjectEnvironment(project: folder, interpreter: python)
    precondition(second.reused)
    let mismatched = projectCheck(folder, expectedVersion: "0.0")
    precondition(mismatched.level == "blocked")
    let marker = folder.appendingPathComponent(".venv/do-not-overwrite.txt")
    try Data("keep".utf8).write(to: marker)
    _ = try createProjectEnvironment(project: folder, interpreter: python)
    precondition(FileManager.default.fileExists(atPath: marker.path))
    let unknownProject = folder.appendingPathComponent("unknown")
    try FileManager.default.createDirectory(at: unknownProject.appendingPathComponent(".venv"), withIntermediateDirectories: true)
    let userFile = unknownProject.appendingPathComponent(".venv/user-file")
    try Data("preserve".utf8).write(to: userFile)
    do { _ = try createProjectEnvironment(project: unknownProject, interpreter: python); preconditionFailure("Unknown venv must not be overwritten") } catch {}
    precondition(FileManager.default.fileExists(atPath: userFile.path))
    print("PASS: scheme validation, disk thresholds, real isolated venv creation/reuse, version conflict, preservation of existing files (temporary project only)")
}

func runtimeReadinessTests() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("envsetup-runtime-test-" + UUID().uuidString)
    let app = folder.appendingPathComponent("Docker.app")
    let binary = app.appendingPathComponent("Contents/Resources/bin/docker")
    try FileManager.default.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let script = "#!/bin/sh\nif [ \"$1\" != \"--context\" ] || [ \"$2\" != \"desktop-linux\" ] || [ \"$3\" != \"info\" ]; then exit 2; fi\nprintf '99.0.0\\n'\n"
    try script.write(to: binary, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: binary.path)
    let installed = Probe(state: "已检测到", detail: "Docker test", path: app.path)
    let ready = await readinessChecks(ids: ["docker"], probes: ["docker": installed], project: nil)
    precondition(ready.first?.level == "ok")
    try "#!/bin/sh\nexit 1\n".write(to: binary, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: binary.path)
    let stopped = await readinessChecks(ids: ["docker"], probes: ["docker": installed], project: nil)
    precondition(stopped.first?.level == "warning")
    let missing = await readinessChecks(ids: ["docker"], probes: [:], project: nil)
    precondition(missing.first?.level == "blocked")
    let assistant = await readinessChecks(ids: ["codex"], probes: ["codex": installed], project: nil)
    precondition(assistant.first?.level == "warning")
    let existing = Probe(state: "已检测到", detail: "version", path: "/mock/tool")
    let component = catalog.first { $0.id == "git" }!
    let reuse = await performPreflight(fingerprint: "test", components: [component], actions: ["git": .reuse], versions: [:], probes: ["git": existing], base: ["git": existing], project: nil)
    precondition(!reuse.blocked && reuse.items.contains { $0.id == "reuse" })
    let blocked = await performPreflight(fingerprint: "test", components: [component], actions: ["git": .blocked("test conflict")], versions: [:], probes: [:], base: [:], project: nil)
    precondition(blocked.blocked)
    await MainActor.run {
        let model = Model()
        model.selected = ["git"]; model.results = ["git": existing]
        model.preflightReport = PreflightReport(fingerprint: model.preflightFingerprint, date: Date(), items: [])
        precondition(model.preflightPassed)
        model.selected = ["python"]
        precondition(!model.preflightPassed)
        model.preflightReport = PreflightReport(fingerprint: model.preflightFingerprint, date: Date().addingTimeInterval(-600), items: [])
        precondition(!model.preflightPassed)
    }
    print("PASS: installed versus running Docker, missing installation, unknown account status, preflight reuse/conflict (fake executables, no services started)")
}
