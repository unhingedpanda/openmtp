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
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    init(executor: any TransferExecuting = NativeTransferExecutor()) { self.executor = executor }
    func enqueue(_ items: [TransferItem]) {
        guard !items.isEmpty else { return }
        records += items.map { TransferRecord(item: $0) }
        guard !busy else { return }
        busy = true
        stopping = false
        runner = Task { await run() }
    }
    func enqueueAndWait(_ item: TransferItem) async throws {
        try await withCheckedThrowingContinuation { continuation in
            waiters[item.id] = continuation
            enqueue([item])
        }
    }
    private func finish(_ index: Int, state: TransferState) {
        records[index].state = state
        guard let continuation = waiters.removeValue(forKey: records[index].id) else { return }
        switch state {
        case .completed: continuation.resume()
        case .failed(let message): continuation.resume(throwing: DeviceError(code: "TransferFailed", message: message))
        default: continuation.resume(throwing: DeviceError(code: "TransferStopped", message: "The file export did not complete."))
        }
    }
    func stopAfterCurrentItem() {
        stopping = true
        if collisions.pending != nil { collisions.decide(.stop) }
    }
    func waitUntilIdle() async { await runner?.value }
    func dismissFinished() { guard !busy else { return }; records.removeAll() }
    func retry(_ id: UUID) {
        guard !busy, let record = records.first(where: { $0.id == id }), case .failed = record.state else { return }
        enqueue([TransferItem(source: record.item.source, destination: record.item.destination, device: record.item.device, destinationName: record.item.destinationName, collisionPolicy: record.item.collisionPolicy)])
    }
    private func run() async {
        await activityChanged?(true)
        while let index = records.firstIndex(where: { $0.state == .queued }) {
            if stopping { finish(index, state: .stopped); continue }
            let item = records[index].item
            do {
                var replace = false
                let exists = try await executor.destinationExists(item)
                if stopping { finish(index, state: .stopped); continue }
                if exists {
                    if item.collisionPolicy == .fail { throw FileActionController.collision }
                    switch await collisions.resolve(item) {
                    case .replace: replace = true
                    case .skip: finish(index, state: .skipped); continue
                    case .stop: stopping = true; finish(index, state: .stopped); continue
                    }
                }
                if stopping { finish(index, state: .stopped); continue }
                currentID = item.id
                progress = nil
                records[index].state = .running
                try await executor.execute(item, replacing: replace) { [weak self] value in
                    Task { @MainActor in
                        guard let self, self.currentID == item.id else { return }
                        self.progress = value
                    }
                }
                finish(index, state: .completed)
            } catch {
                finish(index, state: .failed(error.localizedDescription + " Check the destination for a partial copy."))
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
