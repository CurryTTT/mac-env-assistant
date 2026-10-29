import Foundation

struct InstallIssue: Codable, Identifiable {
    let componentID: String
    let title: String
    let detail: String
    let suggestion: String
    var id: String { componentID }
}

// A hint from installer output, never a claim to know the complete cause.
// Failed package-manager commands are not retried automatically: they may have
// changed the machine before failing. A new plan must inspect it again.
func diagnoseInstallFailure(componentID: String, status: Int32, output: String) -> InstallIssue {
    let text = output.lowercased()
    let title: String, suggestion: String
    if status == -1 {
        title = "安装程序未能启动"
        suggestion = "重新检测工具入口和必要依赖，确认安装程序仍存在并可执行，再查看新计划。"
    } else if text.contains("no space left on device") || text.contains("disk full") {
        title = "日志提示磁盘空间不足"
        suggestion = "检查安装盘及下载缓存所在磁盘的可用空间。释放空间后重新检测；不要删除不确定用途的目录。"
    } else if text.contains("permission denied") || text.contains("not writable") || text.contains("operation not permitted") {
        title = "日志提示权限受限"
        suggestion = "检查日志指出的文件或目录权限；涉及系统安装器时，在系统窗口中完成授权。不要直接对未知目录批量修改权限。"
    } else if text.contains("checksum mismatch") || text.contains("sha256 mismatch") || text.contains("signature verification failed") || text.contains("certificate problem") {
        title = "日志提示下载校验或证书问题"
        suggestion = "核对系统时间、网络代理及官方下载源，再使用对应包管理器处理失败的下载。保留校验检查后重新检测并重试。"
    } else if text.contains("could not resolve host") || text.contains("failed to connect") || text.contains("connection timed out") || text.contains("operation timed out") || text.contains("connection reset") || text.contains("curl: (28)") || text.contains("curl: (6)") || text.contains("curl: (7)") {
        title = "日志提示下载连接失败"
        suggestion = "检查网络、VPN 或代理设置，稍后重新检测并运行安装前检查。已可用的工具会复用，下载缓存是否复用由包管理器决定。"
    } else if text.contains("already a file at") || text.contains("already an app at") || text.contains("conflicts with") || text.contains("would be overwritten") {
        title = "日志提示已有文件或版本冲突"
        suggestion = "核对冲突路径与已有安装，再决定保留哪个版本。软件不会自动删除冲突文件；处理后重新检测。"
    } else if text.contains("no available formula") || text.contains("no formulae found") || text.contains("no available cask") || text.contains("has been disabled") {
        title = "日志提示所选安装项不可用"
        suggestion = "返回选择页面，核对工具与版本是否仍由安装源提供。可以选择其他受支持版本后重新检查。"
    } else {
        title = "安装未完成"
        suggestion = "展开运行日志查看首个错误。处理后重新检测并确认计划；失败的命令可能已安装部分内容，不要直接重复执行。"
    }
    return .init(componentID: componentID, title: title, detail: "退出码 \(status)。这是根据安装输出提供的排查提示，具体原因请结合日志确认。", suggestion: suggestion)
}

func installDiagnosticsTests() {
    let cases: [(String, String)] = [
        ("curl: (6) Could not resolve host: example.invalid", "下载连接失败"),
        ("Error: No space left on device", "磁盘空间不足"),
        ("Permission denied: /test/path", "权限受限"),
        ("SHA256 mismatch", "校验或证书问题"),
        ("Error: There is already an App at /test/App.app", "文件或版本冲突"),
        ("Error: No available formula with the name abc", "安装项不可用")
    ]
    for (output, title) in cases {
        precondition(diagnoseInstallFailure(componentID: "uv", status: 1, output: output).title.contains(title))
    }
    precondition(diagnoseInstallFailure(componentID: "uv", status: 1, output: "Downloading network toolkit; unknown failure").title == "安装未完成")
    precondition(diagnoseInstallFailure(componentID: "uv", status: -1, output: "").title == "安装程序未能启动")
    let good = Probe(state: "已检测到", detail: "version", path: "/mock/bin/tool")
    let absent = Probe(state: "未在常见位置发现", detail: "", path: "")
    var probes = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, good) })
    probes["uv"] = absent; probes["ollama"] = absent
    let steps = catalog.filter { ["uv", "ollama"].contains($0.id) }
    let approved = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, installAction(for: $0, probes: probes)) })
    var calls = 0
    let failed = executeInstall(components: steps, approved: approved, control: InstallControl(), probe: { probes }, run: { _, output in
        calls += 1; output("curl: (6) Could not "); output("resolve host: example.invalid\n")
        // Package managers may install something before exiting unsuccessfully.
        probes["uv"] = good
        return 1
    }, event: { _, _, _ in })
    precondition(calls == 1 && failed.issues.first?.title.contains("下载连接失败") == true)
    precondition(failed.states["ollama"] == "未执行")
    let reviewed = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, installAction(for: $0, probes: probes)) })
    precondition(reviewed["uv"] == .reuse)
    let retried = executeInstall(components: steps, approved: reviewed, control: InstallControl(), probe: { probes }, run: { _, _ in
        calls += 1; probes["ollama"] = good; return 0
    }, event: { _, _, _ in })
    precondition(calls == 2 && retried.states["uv"] == "已复用" && retried.states["ollama"] == "已安装并验证" && retried.issues.isEmpty)
    let old = Data(#"{"selected":["uv"],"states":{"uv":"失败"},"summary":"old","log":"old","date":0}"#.utf8)
    precondition((try! JSONDecoder().decode(InstallSnapshot.self, from: old)).issues == nil)
    let snapshot = InstallSnapshot(selected: ["uv"], states: failed.states, summary: failed.summary, log: "test", issues: failed.issues)
    precondition((try! JSONDecoder().decode(InstallSnapshot.self, from: JSONEncoder().encode(snapshot))).issues?.first?.componentID == "uv")
    print("PASS: diagnostic hints, split output, no automatic retry, partial-install reuse after review, compatible history")
}
