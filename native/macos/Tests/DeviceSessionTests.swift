import XCTest
import Foundation

final class DeviceSessionTests: XCTestCase {
    func testInvalidationPreventsAQueuedDestructiveCallFromExecuting() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("preserved".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let started = expectation(description: "The worker is occupied")
        let release = DispatchSemaphore(value: 0)
        let transport = RecordingTransport { request in
            if case .list = request {
                started.fulfill()
                _ = release.wait(timeout: .now() + 3)
                return .entries([])
            }
            if case .delete = request { try FileManager.default.removeItem(at: file) }
            return .confirmed
        }
        let session = DeviceSession(transport: transport)
        let first = Task { try await session.perform(.list(storage: 7, path: "/")) }
        await fulfillment(of: [started], timeout: 2)
        let deletion = Task { try await session.perform(.delete(storage: 7, paths: ["/file.txt"])) }
        try await Task.sleep(for: .milliseconds(30))
        await session.invalidate()
        release.signal()
        _ = try? await first.value
        do {
            _ = try await deletion.value
            XCTFail("The queued operation belongs to an invalidated connection")
        } catch { XCTAssertEqual((error as? DeviceError)?.code, "StaleSession") }
        XCTAssertEqual(try Data(contentsOf: file), Data("preserved".utf8))
    }

    func testNeverRunsBlockingTransportOnMainThread() async throws {
        let transport = ScriptedTransport()
        let session = DeviceSession(transport: transport)
        _ = try await session.perform(.storages)
        XCTAssertFalse(transport.ranOnMain)
    }

    func testSerializesOverlappingRequests() async throws {
        let transport = ScriptedTransport()
        let session = DeviceSession(transport: transport)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask { _ = try await session.perform(.storages) }
            }
            try await group.waitForAll()
        }
        XCTAssertEqual(transport.maximumActive, 1)
    }

    func testRejectsOldSessionEntriesAfterDisconnect() async throws {
        let started = expectation(description: "Foreign call started")
        let transport = ScriptedTransport()
        transport.started = { started.fulfill() }
        let session = DeviceSession(transport: transport)
        let pending = Task { try await session.perform(.storages) }
        await fulfillment(of: [started], timeout: 2)
        await session.invalidate()
        do {
            _ = try await pending.value
            XCTFail("A stale operation must not return a visible result")
        } catch {
            XCTAssertEqual((error as? DeviceError)?.code, "StaleSession")
        }
    }
}
