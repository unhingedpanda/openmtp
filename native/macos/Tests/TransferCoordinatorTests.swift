import XCTest

actor GatedTransferExecutor: TransferExecuting {
    let collision: Bool
    var started: [UUID] = []
    var progressCallbacks: [@Sendable (TransferProgress) -> Void] = []
    private var pending: CheckedContinuation<Void, Error>?
    init(collision: Bool = false) { self.collision = collision }
    func destinationExists(_ item: TransferItem) async throws -> Bool { collision }
    func execute(_ item: TransferItem, replacing: Bool, progress: @escaping @Sendable (TransferProgress) -> Void) async throws {
        started.append(item.id)
        progressCallbacks.append(progress)
        try await withCheckedThrowingContinuation { pending = $0 }
    }
    func finish(error: Error? = nil) { let next = pending; pending = nil; if let error { next?.resume(throwing: error) } else { next?.resume() } }
    func sendProgress(index: Int, sent: Int64) {
        guard progressCallbacks.indices.contains(index) else { return }
        progressCallbacks[index](TransferProgress(name: "file", sent: sent, total: 100, speedMB: 1))
    }
    func waitForStart(_ count: Int) async -> Bool {
        for _ in 0..<100 {
            if started.count >= count { return true }
            try? await Task.sleep(for: .milliseconds(2))
        }
        return false
    }
}

func transferFixture(_ name: String = "file.txt", isDirectory: Bool = false) -> TransferItem {
    TransferItem(source: FileEntry(location: .local(URL(fileURLWithPath: "/tmp/" + name)), name: name, isDirectory: isDirectory, byteCount: 100, modifiedAt: nil), destination: .device(storageID: 7, path: "/"))
}

final class TransferCoordinatorTests: XCTestCase {
    @MainActor func testStopAfterCurrentItemDoesNotStartRemainingItems() async {
        let executor = GatedTransferExecutor()
        let queue = TransferCoordinator(executor: executor)
        let first = transferFixture("folder", isDirectory: true)
        let second = transferFixture("second")
        queue.enqueue([first, second])
        let started = await executor.waitForStart(1)
        XCTAssertTrue(started)
        queue.stopAfterCurrentItem()
        await executor.finish()
        await queue.waitUntilIdle()
        XCTAssertEqual(queue.records.filter { $0.state == .completed }.map(\.id), [first.id])
        XCTAssertEqual(queue.records.last?.state, .stopped)
        let ids = await executor.started
        XCTAssertEqual(ids, [first.id])
    }
    @MainActor func testTerminalErrorNeverProducesCompletedState() async {
        let executor = GatedTransferExecutor()
        let queue = TransferCoordinator(executor: executor)
        queue.enqueue([transferFixture()])
        _ = await executor.waitForStart(1)
        await executor.finish(error: DeviceError(code: "StorageFull", message: "Storage is full"))
        await queue.waitUntilIdle()
        guard case .failed(let message) = queue.records.first?.state else { return XCTFail("Expected retained failure") }
        XCTAssertTrue(message.contains("Storage is full"))
    }
    @MainActor func testProgressFromPreviousItemCannotUpdateNextItem() async throws {
        let executor = GatedTransferExecutor()
        let queue = TransferCoordinator(executor: executor)
        queue.enqueue([transferFixture("first"), transferFixture("second")])
        _ = await executor.waitForStart(1)
        await executor.finish()
        let nextStarted = await executor.waitForStart(2)
        XCTAssertTrue(nextStarted)
        await executor.sendProgress(index: 1, sent: 20)
        try await Task.sleep(for: .milliseconds(10))
        await executor.sendProgress(index: 0, sent: 99)
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertEqual(queue.progress?.sent, 20)
        await executor.finish()
        await queue.waitUntilIdle()
    }
    @MainActor func testCloseDuringTransferRequiresExplicitDecision() async {
        let executor = GatedTransferExecutor()
        let queue = TransferCoordinator(executor: executor)
        queue.enqueue([transferFixture()])
        _ = await executor.waitForStart(1)
        XCTAssertFalse(queue.canClose)
        queue.stopAfterCurrentItem()
        XCTAssertFalse(queue.canClose)
        await executor.finish()
        await queue.waitUntilIdle()
        XCTAssertTrue(queue.canClose)
    }
}
