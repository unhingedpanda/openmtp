import SwiftUI

struct TransferTray: View {
    @Bindable var queue: TransferCoordinator
    @State private var expanded = false
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button { expanded.toggle() } label: { Image(systemName: expanded ? "chevron.down" : "chevron.up") }.buttonStyle(.plain).help("Transfer details")
                if queue.busy { ProgressView().controlSize(.small) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary).font(.callout.weight(.medium)).lineLimit(1)
                    if let progress = queue.progress, progress.total > 0 {
                        ProgressView(value: Double(min(max(0, progress.sent), progress.total)), total: Double(progress.total)).frame(maxWidth: 300)
                    }
                }
                Spacer()
                if let progress = queue.progress {
                    Text("\(ByteCountFormatter.string(fromByteCount: progress.sent, countStyle: .file)) · \(progress.speedMB, specifier: "%.1f") MB/s")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                if queue.busy {
                    Button(queue.stopping ? "Stopping after current item…" : "Stop after current item") { queue.stopAfterCurrentItem() }
                        .disabled(queue.stopping)
                } else { Button("Dismiss") { queue.dismissFinished() } }
            }.padding(.horizontal, 18).padding(.vertical, 12)
            if expanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(queue.records) { record in
                            HStack(alignment: .top) {
                                Image(systemName: symbol(record.state)).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.item.source.name).font(.callout)
                                    Text(status(record.state)).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                                Spacer()
                                if case .failed = record.state { Button("Retry") { queue.retry(record.id) }.disabled(queue.busy) }
                            }
                        }
                    }.padding(.horizontal, 20).padding(.bottom, 14)
                }.frame(maxHeight: 160)
            }
        }.background(.bar)
    }
    private var summary: String {
        if let current = queue.records.first(where: { $0.id == queue.currentID }) { return "Copying \(current.item.source.name)" }
        if queue.collisions.pending != nil { return "Waiting for a collision decision" }
        if queue.records.contains(where: { if case .failed = $0.state { true } else { false } }) { return "Transfer failed. Open details to review." }
        if queue.stopping { return "Transfer queue stopped" }
        return "\(queue.records.filter { $0.state == .completed }.count) items copied"
    }
    private func symbol(_ state: TransferState) -> String {
        switch state {
        case .completed: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        case .running: "arrow.triangle.2.circlepath"
        default: "circle"
        }
    }
    private func status(_ state: TransferState) -> String {
        switch state {
        case .queued: "Queued"
        case .running: "Copying"
        case .completed: "Completed"
        case .skipped: "Skipped"
        case .stopped: "Stopped"
        case .failed(let message): message
        }
    }
}
