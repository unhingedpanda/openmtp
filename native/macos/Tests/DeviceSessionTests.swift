import XCTest
import Foundation

final class DeviceSessionTests: XCTestCase {
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
