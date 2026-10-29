import SwiftUI
import AppKit

struct RunHistoryView: View {
    @ObservedObject var model: Model
    var selected: InstallSnapshot? { model.historyRecords.first { $0.historyKey == model.historySelectedKey } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("安装历史").font(.title2.bold()); Spacer(); Button("关闭") { model.historyPresented = false }.keyboardShortcut(.cancelAction) }
            Text("保留最近 20 次任务，仅存本机。载入只恢复选择与记录，需重新检测和确认后才会安装。").font(.callout).foregroundStyle(.secondary)
            if !model.historyWarning.isEmpty { Text(model.historyWarning).font(.caption).foregroundStyle(.orange) }
            if model.historyRecords.isEmpty {
                ContentUnavailableView("暂无安装记录", systemImage: "clock", description: Text("开始配置后会自动保存任务记录。"))
            } else {
                HSplitView {
                    List(selection: $model.historySelectedKey) {
                        ForEach(model.historyRecords, id: \.historyKey) { record in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(record.date.formatted()).font(.callout.bold())
                                Text(record.summary).font(.caption).lineLimit(2)
                                Text("\(record.selected.count) 项所选工具").font(.caption2).foregroundStyle(.secondary)
                            }.padding(.vertical, 4).tag(record.historyKey)
                        }
                    }.frame(minWidth: 240, idealWidth: 270)
                    ScrollView {
                        if let record = selected {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(record.summary).font(.headline)
                                ForEach(catalog.filter { record.selected.contains($0.id) }) { item in
                                    HStack(alignment: .top) {
                                        Text(item.name)
                                        Spacer()
                                        Text((record.versions?[item.id] ?? "auto") + " · " + (record.states[item.id] ?? "未执行")).foregroundStyle(.secondary)
                                    }.font(.callout)
                                }
                                if let issues = record.issues { ForEach(issues) { issue in Text(issue.title + "：" + issue.suggestion).font(.caption).foregroundStyle(.orange) } }
                                if let checks = record.readiness {
                                    Divider(); Text("当时的运行验证（不代表当前状态）").font(.callout.bold())
                                    ForEach(checks) { check in Text(check.title + "：" + check.detail).font(.caption).foregroundStyle(.secondary) }
                                }
                                DisclosureGroup("查看任务日志") { Text(record.log).font(.system(size: 11, design: .monospaced)).textSelection(.enabled) }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        } else { Text("选择一条任务记录查看详情。").foregroundStyle(.secondary).padding() }
                    }.frame(minWidth: 340)
                }
            }
            HStack {
                Text("日志可能包含本机路径，分享前请检查。").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("载入并重新检测") { if let record = selected { model.restoreRun(record) } }
                    .buttonStyle(.borderedProminent).disabled(selected == nil || model.installing || model.scanning || model.bootstrapID != nil)
            }
        }.padding(20).frame(width: 820, height: 560)
            .onAppear { model.historySelectedKey = model.historyRecords.first?.historyKey }
    }
}

func shellQuoted(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

extension ContentView {
    @ViewBuilder
    func readinessActions(_ item: CheckItem) -> some View {
        if let probe = model.runResults[item.id], probe.available {
            if applicationNames[item.id] != nil {
                Button("打开软件处理") { NSWorkspace.shared.open(URL(fileURLWithPath: probe.path)) }.font(.caption)
            } else if item.id == "ollama", item.level != "ok" {
                Button("复制服务启动命令") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(shellQuoted(probe.path) + " serve", forType: .string)
                }.font(.caption).help("仅复制命令；在终端执行会启动本机 Ollama 服务。")
            } else if item.id == "python", let project = model.projectResult {
                Button("在 Finder 查看项目") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.project.path) }.font(.caption)
            }
        }
    }
}
