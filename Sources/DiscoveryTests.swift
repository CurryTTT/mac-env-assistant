import Foundation

func discoveryTests() throws {
    let fm = FileManager.default
    let temporary = fm.temporaryDirectory.appendingPathComponent("MacEnvDiscovery-" + UUID().uuidString)
    try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
    let root = temporary.resolvingSymlinksInPath()
    defer { try? fm.removeItem(at: root) }
    func executable(_ relative: String) throws -> String {
        let path = root.appendingPathComponent(relative)
        try fm.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nprintf 'fixture only\\n'\n".utf8).write(to: path)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path.path)
        return path.path
    }
    func app(_ relative: String, working: Bool) throws -> String {
        let path = root.appendingPathComponent(relative)
        try fm.createDirectory(at: path.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let plist: [String: String] = ["CFBundleExecutable": "Fixture", "CFBundlePackageType": "APPL", "CFBundleIdentifier": "test.discovery." + UUID().uuidString, "CFBundleShortVersionString": "1.2.3"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: path.appendingPathComponent("Contents/Info.plist"))
        if working { _ = try executable(relative + "/Contents/MacOS/Fixture") }
        return path.path
    }
    let context = DiscoveryContext(home: root, applicationRoots: [root.appendingPathComponent("Applications"), root.appendingPathComponent("SystemApplications")], toolboxRoots: [root.appendingPathComponent("Toolbox")], environment: [:])
    let vscode = catalog.first { $0.id == "vscode" }!
    let broken = try app("Applications/Visual Studio Code.app", working: false)
    let valid = try app("SystemApplications/Editors/Visual Studio Code.app", working: true)
    let nested = try app("Toolbox/idea/ch-0/251/IntelliJ IDEA.app", working: true)
    let hiddenInBundle = try app("Applications/Container.app/Contents/Visual Studio Code.app", working: true)
    let outside = try app("Outside/Visual Studio Code.app", working: true)
    try fm.createSymbolicLink(at: root.appendingPathComponent("Applications/Linked"), withDestinationURL: root.appendingPathComponent("Outside"))
    let inventory = (context.applicationRoots.flatMap { discoverAppBundles(root: $0, depth: 2) } + context.toolboxRoots.flatMap { discoverAppBundles(root: $0, depth: 4) }).map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
    precondition(inventory.contains(valid) && inventory.contains(nested), "Inventory: \(inventory); expected \(valid), \(nested)")
    precondition(!inventory.contains(hiddenInBundle) && !inventory.contains(outside))
    precondition(discoverAppBundles(root: root, depth: 5, limit: 0).isEmpty)
    let foundApp = probeApplication(vscode, candidates: applicationCandidates(id: "vscode", context: context, discovered: inventory))
    precondition(foundApp.available && foundApp.path == valid)
    precondition(installAction(for: vscode, probes: ["vscode": foundApp], selectedVersion: "auto") == .reuse)
    let badApp = probeApplication(vscode, candidates: [broken])
    precondition(!badApp.available && badApp.path == broken)
    if case .blocked = installAction(for: vscode, probes: ["vscode": badApp], selectedVersion: "auto") {} else { preconditionFailure("Broken app must not be overwritten") }
    precondition(appFilenameMatches("/mock/PyCharm CE.app", id: "pycharm"))
    precondition(appFilenameMatches("/mock/IntelliJ IDEA 2026.2.app", id: "idea"))
    precondition(!appFilenameMatches("/mock/IntelliJ IDEA Backup.app", id: "idea"))

    let node = catalog.first { $0.id == "node" }!
    let bad = try executable("bad/node"), good = try executable("good/node")
    var calls = [String]()
    let result = probeCommandCandidates(node, paths: [bad, good, good], run: { path, _ in
        calls.append(path); return path == bad ? (1, "broken") : (0, "v24.2.0")
    })
    precondition(result.available && result.path == good && calls == [bad, good])
    let badCLI = probeCommandCandidates(node, paths: [bad], run: { _, _ in (1, "broken") })
    precondition(badCLI.path == bad && !badCLI.available)
    if case .blocked = installAction(for: node, probes: ["node": badCLI], selectedVersion: "auto") {} else { preconditionFailure("Broken executable must block duplicate install") }
    let git = catalog.first { $0.id == "git" }!
    let gitProbe = probeCommandCandidates(git, paths: ["/usr/bin/git"], cltAvailable: false, run: { _, _ in preconditionFailure("Do not invoke developer shim") })
    precondition(!gitProbe.available)

    let node22 = try executable(".nvm/versions/node/v22.4.0/bin/node")
    _ = try executable(".nvm/versions/node/v24.1.0/bin/node")
    _ = try executable(".nvm/versions/node/v220.1.0/bin/node")
    let volta = try executable(".volta/tools/image/node/24.2.0/bin/node")
    let python310 = try executable(".pyenv/versions/3.10.16/bin/python3")
    _ = try executable(".pyenv/versions/3.12.7/bin/python3")
    _ = try executable(".pyenv/versions/my-project/bin/python3")
    precondition(managedRuntimePaths("node", requested: "22", context: context) == [node22])
    precondition(managedRuntimePaths("node", context: context).contains(volta))
    precondition(managedRuntimePaths("pnpm", context: context).isEmpty)
    precondition(managedRuntimePaths("python", requested: "3.1", context: context).isEmpty)
    precondition(managedRuntimePaths("python", requested: "3.10", context: context) == [python310])
    let python = catalog.first { $0.id == "python" }!
    let selected = selectedVersionProbe(python, requested: "3.10", base: [:], context: context, run: { path, _ in path == python310 ? (0, "Python 3.10.16") : (1, "not fixture") })
    precondition(selected.available && selected.path == python310)
    precondition(installAction(for: python, probes: ["python": selected], selectedVersion: "3.10") == .reuse)
    precondition(resolvedDependencies(["python"], probes: ["python": selected], versions: ["python": "3.10"]) == ["python"])
    var custom = context
    custom.environment["NVM_DIR"] = root.appendingPathComponent("custom-nvm").path
    let customNode = try executable("custom-nvm/versions/node/v22.8.0/bin/node")
    precondition(managedRuntimePaths("node", requested: "22", context: custom) == [customNode])
    print("PASS: working-candidate fallback, broken-install protection, bounded app discovery, version-manager reuse and exact series matching")
}
