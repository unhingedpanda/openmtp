import XCTest

final class DeviceBrowsingTests: XCTestCase {
    @MainActor func testDisconnectInvalidatesSelectionAndPendingNavigation() async throws {
        let app = AppModel(session: DeviceSession(transport: RecordingTransport()), monitorUSB: false)
        await app.connect()
        app.devicePane.setSelection(Set(app.devicePane.entries.map(\.id)))
        app.pendingDelete = app.devicePane.entries
        let navigation = Task { await app.devicePane.navigate(to: .device(storageID: 7, path: "/slow")) }
        try await Task.sleep(for: .milliseconds(10))
        await app.disconnect()
        await navigation.value
        XCTAssertTrue(app.devicePane.entries.isEmpty)
        XCTAssertTrue(app.devicePane.selection.isEmpty)
        XCTAssertFalse(app.connected)
        XCTAssertTrue(app.pendingDelete.isEmpty)
    }
    @MainActor func testStorageChangeRejectsOldDirectoryResults() async throws {
        let app = AppModel(session: DeviceSession(transport: RecordingTransport()), monitorUSB: false)
        await app.connect()
        app.devicePane.setSelection(Set(app.devicePane.entries.map(\.id)))
        let navigation = Task { await app.devicePane.navigate(to: .device(storageID: 7, path: "/slow")) }
        try await Task.sleep(for: .milliseconds(10))
        await app.selectStorage(8)
        await navigation.value
        XCTAssertEqual(app.devicePane.location, .device(storageID: 8, path: "/"))
        XCTAssertEqual(app.devicePane.entries.first?.name, "8.txt")
        XCTAssertTrue(app.devicePane.selection.isEmpty)
    }
    @MainActor func testAttachDuringTransferDefersSessionReset() async {
        let transport = RecordingTransport()
        let app = AppModel(session: DeviceSession(transport: transport), monitorUSB: false)
        await app.connect()
        await app.setEngineBusy(true)
        app.usbChanged(attached: true)
        XCTAssertEqual(transport.count("Initialize"), 1)
        XCTAssertEqual(transport.count("Dispose"), 1)
        await app.setEngineBusy(false)
        XCTAssertEqual(transport.count("Initialize"), 2)
        XCTAssertTrue(app.connected)
    }
}
