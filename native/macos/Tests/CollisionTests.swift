import XCTest

final class CollisionTests: XCTestCase {
    @MainActor func testExistingDestinationRequiresCollisionDecision() async throws {
        let executor = GatedTransferExecutor(collision: true)
        let queue = TransferCoordinator(executor: executor)
        queue.enqueue([transferFixture()])
        for _ in 0..<100 {
            if queue.collisions.pending != nil { break }
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTAssertNotNil(queue.collisions.pending)
        let ids = await executor.started
        XCTAssertTrue(ids.isEmpty)
        queue.collisions.decide(.skip)
        await queue.waitUntilIdle()
        XCTAssertEqual(queue.records.first?.state, .skipped)
    }
    func testFailedCopyPreservesUnrelatedDestinationContent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = directory.appendingPathComponent("source.txt")
        let unrelated = directory.appendingPathComponent("unrelated.txt")
        try Data("old".utf8).write(to: existing)
        try Data("preserved".utf8).write(to: unrelated)
        let transport = RecordingTransport { request in
            if case .download(_, _, let destination) = request {
                try Data("partial".utf8).write(to: URL(fileURLWithPath: destination).appendingPathComponent("source.txt"))
                throw DeviceError(code: "Disconnected", message: "Device disconnected")
            }
            return .confirmed
        }
        let source = FileEntry(location: .device(storageID: 7, path: "/source.txt"), name: "source.txt", isDirectory: false, byteCount: 8, modifiedAt: nil)
        let item = TransferItem(source: source, destination: .local(directory), device: DeviceFileService(session: DeviceSession(transport: transport)))
        do { try await NativeTransferExecutor().execute(item, replacing: true, progress: { _ in }); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(try Data(contentsOf: unrelated), Data("preserved".utf8))
        XCTAssertEqual(try Data(contentsOf: existing), Data("old".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), ["source.txt", "unrelated.txt"])
    }
}
