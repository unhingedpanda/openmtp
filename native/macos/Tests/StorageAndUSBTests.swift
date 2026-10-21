import XCTest

final class StorageAndUSBTests: XCTestCase {
    @MainActor func testStorageSwitchCannotCopyToPreviousStorage() async throws {
        let transport = RecordingTransport { request in
            switch request {
            case .initialize: return .device(DeviceInfo(name: "Phone", manufacturer: "Fixture"))
            case .storages: return .storages([DeviceStorage(id: 7, name: "Internal"), DeviceStorage(id: 8, name: "SD")])
            case .list(let storage, _):
                if storage == 8 { Thread.sleep(forTimeInterval: 0.08); throw DeviceError(code: "StorageUnavailable", message: "SD is unavailable") }
                return .entries([])
            default: return .confirmed
            }
        }
        let app = AppModel(session: DeviceSession(transport: transport), monitorUSB: false)
        await app.connect()
        let local = transferFixture().source
        app.localPane.loader = { _ in [local] }
        await app.localPane.refresh()
        app.localPane.setSelection([local.id])
        let change = Task { await app.selectStorage(8) }
        for _ in 0..<100 {
            if app.devicePane.loading { break }
            await Task.yield()
        }
        XCTAssertTrue(app.devicePane.loading)
        XCTAssertFalse(app.canTransfer)
        app.copySelection()
        XCTAssertTrue(app.transfers.records.isEmpty)
        await change.value
        XCTAssertEqual(app.selectedStorageID, 7)
        XCTAssertEqual(app.devicePane.location, .device(storageID: 7, path: "/"))
        XCTAssertFalse(app.canTransfer)
    }

    @MainActor func testUnrelatedUSBDetachPreservesActivePhoneAndLease() async throws {
        let phone = USBDeviceIdentity(vendor: 0x18d1, product: 0x4ee1, serial: "phone")
        let transport = RecordingTransport { request in
            switch request {
            case .initialize: return .device(DeviceInfo(name: "Phone", manufacturer: "Fixture", usb: phone))
            case .storages: return .storages([DeviceStorage(id: 7, name: "Internal")])
            case .list: return .entries([transferFixture().source])
            default: return .confirmed
            }
        }
        let app = AppModel(session: DeviceSession(transport: transport), monitorUSB: false)
        await app.connect()
        await app.setEngineBusy(true)
        let before = app.devicePane.entries
        app.usbChanged(attached: false, identity: USBDeviceIdentity(vendor: 0x1234, product: 0xabcd, serial: "accessory"))
        await Task.yield()
        XCTAssertTrue(app.connected)
        XCTAssertEqual(app.devicePane.entries, before)
        let service = try XCTUnwrap(app.fileActions.device)
        _ = try await service.entries(storage: 7, path: "/")
        app.usbChanged(attached: false, identity: phone)
        XCTAssertFalse(app.connected)
        XCTAssertTrue(app.devicePane.entries.isEmpty)
    }
}
