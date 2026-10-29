import Foundation
import Darwin

struct HistoryReadResult {
    var records: [InstallSnapshot]
    var unreadable: Int
}

// Only files named with our run UUIDs are archived or pruned. Tests use an
// injected temporary root and never touch the user's actual task records.
struct RunHistoryStore {
    let root: URL
    var latestURL: URL { root.appendingPathComponent("last-run.json") }
    var archiveURL: URL { root.appendingPathComponent("Runs", isDirectory: true) }
    static let limit = 20

    func read(_ url: URL) throws -> InstallSnapshot {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else { throw SetupError.message("记录不是普通文件。") }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let data = try handle.read(upToCount: 2_000_001) ?? Data()
        guard data.count <= 2_000_000 else { throw SetupError.message("记录超过读取上限。") }
        return try JSONDecoder().decode(InstallSnapshot.self, from: data)
    }
    private func ownedFiles() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: archiveURL, includingPropertiesForKeys: nil).filter {
            $0.pathExtension == "json" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil
        }
    }
    func load() -> HistoryReadResult {
        var records = [InstallSnapshot](), unreadable = 0
        do {
            for file in try ownedFiles() {
                do {
                    let record = try read(file)
                    guard record.runID?.uuidString.lowercased() == file.deletingPathExtension().lastPathComponent.lowercased() else { unreadable += 1; continue }
                    records.append(record)
                } catch { unreadable += 1 }
            }
        } catch { unreadable += 1 }
        // Old versions stored only last-run.json. Keep it accessible until a
        // newly started task migrates it into the archive.
        if FileManager.default.fileExists(atPath: latestURL.path) {
            if let latest = try? read(latestURL) {
                if !records.contains(where: { $0.historyKey == latest.historyKey }) { records.append(latest) }
            } else { unreadable += 1 }
        }
        records.sort { $0.date == $1.date ? $0.historyKey < $1.historyKey : $0.date > $1.date }
        return .init(records: Array(records.prefix(Self.limit)), unreadable: unreadable)
    }
    private func privateWrite(_ data: Data, to destination: URL) throws {
        let temporary = destination.deletingLastPathComponent().appendingPathComponent("." + UUID().uuidString + ".tmp")
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw SetupError.message("无法创建任务记录。") }
        defer { try? FileManager.default.removeItem(at: temporary) }
        let handle = try FileHandle(forWritingTo: temporary)
        do { try handle.write(contentsOf: data); try handle.synchronize(); try handle.close() }
        catch { try? handle.close(); throw error }
        guard Darwin.rename(temporary.path, destination.path) == 0 else { throw SetupError.message("无法原子保存任务记录：\(errno)") }
    }
    func save(_ record: InstallSnapshot) throws {
        guard let id = record.runID else { throw SetupError.message("任务缺少记录编号。") }
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: archiveURL.path)
        let data = try JSONEncoder().encode(record)
        guard data.count <= 2_000_000 else { throw SetupError.message("任务记录过大，未覆盖原记录。") }
        try privateWrite(data, to: archiveURL.appendingPathComponent(id.uuidString + ".json"))
        try privateWrite(data, to: latestURL)
        let records = try ownedFiles().compactMap { file -> (URL, InstallSnapshot)? in
            guard let record = try? read(file), record.runID?.uuidString.lowercased() == file.deletingPathExtension().lastPathComponent.lowercased() else { return nil }
            return (file, record)
        }.sorted { $0.1.date == $1.1.date ? $0.1.historyKey < $1.1.historyKey : $0.1.date > $1.1.date }
        for (file, _) in records.dropFirst(Self.limit) { try FileManager.default.removeItem(at: file) }
    }
    func migrateLegacyLatest() throws {
        guard FileManager.default.fileExists(atPath: latestURL.path) else { return }
        var record = try read(latestURL)
        guard record.runID == nil else { return }
        record.runID = UUID()
        try save(record)
    }
}

extension InstallSnapshot {
    var historyKey: String { runID?.uuidString ?? "legacy-\(date.timeIntervalSinceReferenceDate)" }
}

func runHistoryTests() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("envsetup-history-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = RunHistoryStore(root: root)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let old = InstallSnapshot(date: Date(timeIntervalSince1970: 1), selected: ["python"], states: ["python": "失败"], summary: "legacy", log: "old", versions: ["python": "3.12"])
    try JSONEncoder().encode(old).write(to: store.latestURL)
    try store.migrateLegacyLatest()
    precondition(store.load().records.count == 1 && store.load().records[0].versions?["python"] == "3.12")
    var last = old
    for n in 0..<22 {
        last = InstallSnapshot(date: Date(timeIntervalSince1970: Double(n + 10)), selected: ["uv"], states: ["uv": "已复用"], summary: "run \(n)", log: "sample", runID: UUID(), readiness: [.init(id: "uv", title: "uv", level: "ok", detail: "ready")])
        try store.save(last)
    }
    precondition(store.load().records.count == 20 && store.load().records.first?.runID == last.runID)
    last.summary = "updated"
    try store.save(last)
    precondition(store.load().records.count == 20 && store.load().records.first?.summary == "updated")
    let restored = try store.read(store.latestURL)
    precondition(restored.readiness?.first?.level == "ok")
    let permissions = try FileManager.default.attributesOfItem(atPath: store.latestURL.path)[.posixPermissions] as! NSNumber
    precondition(permissions.intValue & 0o777 == 0o600)
    let unrelated = store.archiveURL.appendingPathComponent("user-note.json")
    try Data("keep".utf8).write(to: unrelated)
    let corrupt = store.archiveURL.appendingPathComponent(UUID().uuidString + ".json")
    try Data("broken".utf8).write(to: corrupt)
    try store.save(last)
    precondition(FileManager.default.fileExists(atPath: unrelated.path) && store.load().unreadable == 1)
    let link = store.archiveURL.appendingPathComponent(UUID().uuidString + ".json")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: store.latestURL)
    precondition(store.load().unreadable == 2)
    let oversized = root.appendingPathComponent("oversized.json")
    try Data(repeating: 32, count: 2_000_001).write(to: oversized)
    do { _ = try store.read(oversized); preconditionFailure("Must reject oversized records") } catch {}
    print("PASS: history migration, retention, same-run updates, readiness persistence, private permissions, corrupt/symlink/oversized handling, unrelated-file preservation (temporary root only)")
}
