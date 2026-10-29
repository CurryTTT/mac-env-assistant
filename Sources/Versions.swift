import Foundation

struct VersionOption: Identifiable {
    let id: String
    let label: String
}

func versionOptions(_ id: String) -> [VersionOption] {
    let automatic = VersionOption(id: "auto", label: "优先使用已安装版本，缺失时装稳定版")
    switch id {
    case "python": return [automatic] + ["3.10", "3.11", "3.12", "3.13", "3.14"].map {
        VersionOption(id: $0, label: "Python \($0)" + ($0 == "3.10" ? "（已结束官方支持）" : ($0 == "3.12" ? "（AI 可优先考虑）" : "")))
    }
    case "node": return [automatic] + ["22", "24"].map { VersionOption(id: $0, label: "Node.js \($0).x") }
    case "pnpm": return [automatic] + ["9", "10", "11"].map { VersionOption(id: $0, label: "pnpm \($0).x") }
    default: return expandedVersionOptions(id) ?? [automatic]
    }
}

func versionString(_ probe: Probe?) -> String? {
    guard let detail = probe?.detail,
          let range = detail.range(of: #"\d+\.\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
    return String(detail[range])
}

func versionMatches(_ probe: Probe?, requested: String) -> Bool {
    guard probe?.available == true else { return false }
    if requested == "auto" { return true }
    guard let version = versionString(probe) else { return false }
    return version == requested || version.hasPrefix(requested + ".")
}

func selectedVersionProbe(_ item: Component, requested: String, base: [String: Probe]) -> Probe {
    if let existing = base[item.id], versionMatches(existing, requested: requested) { return existing }
    var candidates = [String]()
    if item.id == "python" {
        candidates = ["/opt/homebrew/bin/python\(requested)", "/usr/local/bin/python\(requested)", "~/.local/bin/python\(requested)"]
        if let uv = base["uv"], uv.available,
           let (code, output) = runProbe(uv.path, ["python", "find", "--managed-python", "--no-python-downloads", requested]), code == 0 {
            candidates.insert(output.trimmingCharacters(in: .whitespacesAndNewlines), at: 0)
        }
    } else {
        let formula = versionedFormulaPrefix(item.id), binary = versionedBinary(item.id)
        candidates = ["/opt/homebrew/opt/\(formula)@\(requested)/bin/\(binary)", "/usr/local/opt/\(formula)@\(requested)/bin/\(binary)"] + extraProbePaths(item.id)
    }
    for raw in candidates {
        let path = NSString(string: raw).expandingTildeInPath
        guard FileManager.default.isExecutableFile(atPath: path), let (code, detail) = runProbe(path, ["--version"]), code == 0 else { continue }
        let probe = Probe(state: "已检测到", detail: detail, path: path)
        if versionMatches(probe, requested: requested) { return probe }
    }
    if item.id == "mysql", let existing = base[item.id], existing.available {
        return Probe(state: "版本冲突", detail: "已有 MySQL \(versionString(existing) ?? "其他版本")，不自动跨系列切换或迁移数据。请使用匹配版本或自行处理数据迁移。", path: existing.path)
    }
    return Probe(state: "所选版本未检测到", detail: "未发现 \(item.name) \(requested)。已有其他版本会保留；新版本单独安装。", path: "")
}

func inspectVersions(_ selections: [String: String], base: [String: Probe]) -> [String: Probe] {
    var result = base
    for item in catalog {
        let requested = selections[item.id] ?? "auto"
        if requested != "auto" { result[item.id] = selectedVersionProbe(item, requested: requested, base: base) }
    }
    return result
}

func versionSelectionTests() {
    let installed = Probe(state: "已检测到", detail: "Python 3.12.15", path: "/mock/python3.12")
    precondition(versionMatches(installed, requested: "3.12"))
    precondition(!versionMatches(installed, requested: "3.1"))
    precondition(!versionMatches(installed, requested: "3.10"))
    let node = Probe(state: "已检测到", detail: "v24.22.1", path: "/mock/node")
    precondition(versionMatches(node, requested: "24"))
    precondition(!versionMatches(node, requested: "22"))
    let python = catalog.first { $0.id == "python" }!
    precondition(installAction(for: python, probes: ["python": installed], selectedVersion: "3.12") == .reuse)
    precondition(resolvedDependencies(["python"], probes: ["python": installed], versions: ["python": "3.12"]) == ["python"])
    let absent = Probe(state: "所选版本未检测到", detail: "", path: "")
    let uv = Probe(state: "已检测到", detail: "uv 0.13.6", path: "/mock/uv")
    let action = installAction(for: python, probes: ["python": absent, "uv": uv], selectedVersion: "3.10")
    precondition(action == .install(.init(executable: "/mock/uv", arguments: ["python", "install", "3.10"])))
    let missing = resolvedDependencies(["python"], probes: ["python": absent], versions: ["python": "3.10"])
    precondition(missing == ["python", "uv", "brew", "clt"])
    print("PASS: version comparison, reuse without download, managed Python installation, version-aware dependencies")
}
