import Foundation
import Observation

@MainActor @Observable final class TransferCoordinator {
    private(set) var records: [TransferRecord] = []
    private(set) var progress: TransferProgress?
    private(set) var busy = false
    private(set) var stopping = false
    private(set) var currentID: UUID?
    var canClose: Bool { !busy }
    let collisions = CollisionResolver()
    var activityChanged: (@MainActor (Bool) async -> Void)?
    private let executor: any TransferExecuting
    private var runner: Task<Void, Never>?
    init(executor: any TransferExecuting = NativeTransferExecutor()) { self.executor = executor }
    func enqueue(_ items: [TransferItem]) {
        guard !items.isEmpty else { return }
        records += items.map { TransferRecord(item: $0) }
        guard !busy else { return }
        busy = true
        stopping = false
        runner = Task { await run() }
    }
    func stopAfterCurrentItem() {
        stopping = true
        if collisions.pending != nil { collisions.decide(.stop) }
    }
    func waitUntilIdle() async { await runner?.value }
    func dismissFinished() { guard !busy else { return }; records.removeAll() }
    func retry(_ id: UUID) {
        guard !busy, let record = records.first(where: { $0.id == id }), case .failed = record.state else { return }
        enqueue([TransferItem(source: record.item.source, destination: record.item.destination, device: record.item.device)])
    }
    private func run() async {
        await activityChanged?(true)
        while let index = records.firstIndex(where: { $0.state == .queued }) {
            if stopping { records[index].state = .stopped; continue }
            let item = records[index].item
            do {
                var replace = false
                if try await executor.destinationExists(item) {
                    switch await collisions.resolve(item) {
                    case .replace: replace = true
                    case .skip: records[index].state = .skipped; continue
                    case .stop: stopping = true; records[index].state = .stopped; continue
                    }
                }
                if stopping { records[index].state = .stopped; continue }
                currentID = item.id
                progress = nil
                records[index].state = .running
                try await executor.execute(item, replacing: replace) { [weak self] value in
                    Task { @MainActor in
                        guard let self, self.currentID == item.id else { return }
                        self.progress = value
                    }
                }
                records[index].state = .completed
            } catch {
                records[index].state = .failed(error.localizedDescription + " Check the destination for a partial copy.")
                stopping = true
            }
            currentID = nil
            progress = nil
        }
        currentID = nil
        progress = nil
        busy = false
        await activityChanged?(false)
    }
}
