import Foundation

struct HomebrewRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: String
    }
    let assets: [Asset]
}

enum SetupError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

func homebrewPackageURL(from data: Data) throws -> URL {
    let release = try JSONDecoder().decode(HomebrewRelease.self, from: data)
    for asset in release.assets where asset.name.hasPrefix("Homebrew-") && asset.name.hasSuffix(".pkg") {
        guard let url = URL(string: asset.browser_download_url), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil, url.port == nil,
              url.path.hasPrefix("/Homebrew/brew/releases/download/"), url.lastPathComponent == asset.name,
              url.query == nil, url.fragment == nil else { continue }
        return url
    }
    throw SetupError.message("官方发行信息中未找到可用的 Homebrew 安装包。请稍后重试。")
}

func downloadHomebrewPackage() async throws -> URL {
    guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15 else {
        throw SetupError.message("当前 Homebrew 官方支持 macOS 15 及以上版本，请先升级系统或自行评估旧系统安装方式。")
    }
    #if !arch(arm64)
    throw SetupError.message("此 Homebrew 官方安装包仅支持 Apple Silicon。")
    #else
    var request = URLRequest(url: URL(string: "https://api.github.com/repos/Homebrew/brew/releases/latest")!)
    request.setValue("EnvSetupAssistant", forHTTPHeaderField: "User-Agent")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 30
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let (data, response) = try await session.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SetupError.message("无法读取 Homebrew 官方发行信息，可能是网络故障或 GitHub 请求限额。") }
    let source = try homebrewPackageURL(from: data)
    let (temporary, downloadResponse) = try await session.download(from: source)
    guard let http = downloadResponse as? HTTPURLResponse, http.statusCode == 200,
          let host = http.url?.host, ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"].contains(host),
          http.url?.scheme == "https" else { throw SetupError.message("安装包下载未成功，或下载来源不符合预期。") }
    let size = (try FileManager.default.attributesOfItem(atPath: temporary.path)[.size] as? NSNumber)?.intValue ?? 0
    guard size > 0 && size < 300_000_000 else { throw SetupError.message("安装包大小异常，已停止。") }
    let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("EnvSetupAssistant/Packages/" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let destination = folder.appendingPathComponent(source.lastPathComponent)
    try FileManager.default.moveItem(at: temporary, to: destination)
    let signature = runProbe("/usr/sbin/pkgutil", ["--check-signature", destination.path])
    guard signature?.0 == 0 else {
        try? FileManager.default.removeItem(at: destination)
        throw SetupError.message("安装包签名检查未通过，未打开安装器。\n" + (signature?.1 ?? "无法检查签名"))
    }
    return destination
    #endif
}

func resolvedDependencies(_ selected: Set<String>, probes: [String: Probe], versions: [String: String] = [:]) -> Set<String> {
    var result = Set<String>()
    func visit(_ id: String) {
        guard result.insert(id).inserted else { return }
        if versionMatches(probes[id], requested: versions[id] ?? "auto") { return }
        let dependencies = id == "python" && (versions[id] ?? "auto") != "auto" ? ["uv"] : catalog.first(where: { $0.id == id })?.dependencies ?? []
        for dependency in dependencies { visit(dependency) }
    }
    for id in selected { visit(id) }
    return result
}

func bootstrapSelfTests() {
    let valid = "{\"assets\":[{\"name\":\"Homebrew-7.0.0.pkg\",\"browser_download_url\":\"https://github.com/Homebrew/brew/releases/download/7.0.0/Homebrew-7.0.0.pkg\"}]}"
    precondition((try! homebrewPackageURL(from: Data(valid.utf8))).host == "github.com")
    for invalid in [valid.replacingOccurrences(of: "https://github.com", with: "https://evil.example"), valid.replacingOccurrences(of: "/Homebrew/brew/", with: "/other/repository/"), valid.replacingOccurrences(of: "https://", with: "http://")] {
        do { _ = try homebrewPackageURL(from: Data(invalid.utf8)); preconditionFailure("Unexpected download origin") } catch {}
    }
    let good = Probe(state: "已检测到", detail: "", path: "/mock")
    precondition(resolvedDependencies(["git"], probes: ["git": good]) == ["git"])
    precondition(resolvedDependencies(["pnpm"], probes: [:]) == ["pnpm", "node", "brew", "clt"])
    let clt = catalog.first { $0.id == "clt" }!
    let brew = catalog.first { $0.id == "brew" }!
    let absent = Probe(state: "未在常见位置发现", detail: "", path: "")
    precondition(installAction(for: clt, probes: ["clt": absent]) == .bootstrap("clt"))
    precondition(installAction(for: brew, probes: ["brew": absent]) == .bootstrap("brew"))
    let broken = Probe(state: "需要检查", detail: "", path: "/opt/homebrew/bin/brew")
    if case .blocked = installAction(for: brew, probes: ["brew": broken]) {} else { preconditionFailure("Broken Homebrew must not be overwritten") }
    print("PASS: bootstrap source validation, prerequisite planning, installed dependency reuse, broken Homebrew protection")
}
