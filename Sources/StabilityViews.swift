import SwiftUI

extension ContentView {
    var planSummary: some View {
        let actions = Array(model.actions.values)
        let reuse = actions.filter { if case .reuse = $0 { return true }; return false }.count
        let install = actions.filter { if case .install = $0 { return true }; return false }.count
        let prerequisites = actions.filter { switch $0 { case .bootstrap, .awaitingPrerequisite: return true; default: return false } }.count
        let blocked = actions.filter { if case .blocked = $0 { return true }; return false }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                Label("安装 \(install) 项", systemImage: "arrow.down.circle")
                Label("复用 \(reuse) 项", systemImage: "checkmark.circle")
                Label("等待前置条件 \(prerequisites) 项", systemImage: "clock")
                Label("需处理 \(blocked) 项", systemImage: "exclamationmark.triangle")
            }.font(.callout.weight(.medium))
            Text("你选择了 \(model.selected.count) 项，另有 \(model.plan.filter { !model.selected.contains($0.id) }.count) 项必要依赖。检测和前置工具安装后，计划会重新计算。").font(.caption).foregroundStyle(.secondary)
        }
    }
    var failurePanel: some View {
        Group {
            if !model.installing && !model.issues.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.issues) { issue in
                            VStack(alignment: .leading, spacing: 5) {
                                Label(issue.title, systemImage: "exclamationmark.triangle").font(.callout.bold()).foregroundStyle(.orange)
                                Text(issue.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                Text(issue.suggestion).font(.callout).textSelection(.enabled)
                            }
                        }
                        Text("重新检测只更新计划，不会立即安装。处理问题后需再次完成安装前检查并确认。").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.frame(maxHeight: 165).background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    var readinessSummary: some View {
        let ok = model.readiness.filter { $0.level == "ok" }.count
        let warning = model.readiness.filter { $0.level == "warning" }.count
        let blocked = model.readiness.filter { $0.level == "blocked" }.count
        return Group {
            if !model.readiness.isEmpty && !model.readinessBusy {
                Text("\(ok) 项通过 · \(warning) 项待确认 · \(blocked) 项未就绪。安装完成与运行就绪分别记录。").font(.caption).foregroundStyle(blocked > 0 ? Color.orange : Color.secondary)
            }
        }
    }
}
