import XCTest
import Foundation

final class BridgeDecodingTests: XCTestCase {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/libfixture.dylib")
    }

    func testPreservesUnicodeNamesAndInt64Sizes() throws {
        let transport = try NativeKalamTransport(libraryURL: fixtureURL)
        let reply = try transport.invoke(.list(storage: 7, path: "/"), onProgress: { _ in })
        guard case .entries(let entries) = reply else { return XCTFail("Expected entries") }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "旅行📷.jpg")
        XCTAssertEqual(entries[0].byteCount, 9_007_199_254_740_993)
        XCTAssertEqual(entries[0].location, .device(storageID: 7, path: "/旅行📷.jpg"))
    }

    func testRejectsMalformedOrErrorCallbackResults() throws {
        let transport = try NativeKalamTransport(libraryURL: fixtureURL)
        XCTAssertThrowsError(try transport.invoke(.list(storage: 7, path: "/broken"), onProgress: { _ in }))
        XCTAssertThrowsError(try transport.invoke(.list(storage: 7, path: "/denied"), onProgress: { _ in })) { error in
            XCTAssertEqual((error as? DeviceError)?.code, "ErrorFilePermission")
        }
    }

    func testDecodesStorageAndDeviceMetadata() throws {
        let transport = try NativeKalamTransport(libraryURL: fixtureURL)
        guard case .storages(let storages) = try transport.invoke(.storages, onProgress: { _ in }) else {
            return XCTFail("Expected storages")
        }
        XCTAssertEqual(storages, [DeviceStorage(id: 7, name: "Internal storage")])
        guard case .device(let device) = try transport.invoke(.initialize, onProgress: { _ in }) else {
            return XCTFail("Expected device")
        }
        XCTAssertEqual(device.name, "Fixture Phone")
    }

    func testCopiesCallbackStringsAcrossRepeatedOperations() throws {
        let transport = try NativeKalamTransport(libraryURL: fixtureURL)
        for _ in 0..<1000 {
            guard case .entries(let entries) = try transport.invoke(.list(storage: 7, path: "/"), onProgress: { _ in }) else {
                return XCTFail("Expected entries")
            }
            XCTAssertEqual(entries.first?.name, "旅行📷.jpg")
        }
    }

    func testFinishesOnlyAfterForeignReturn() throws {
        let transport = try NativeKalamTransport(libraryURL: fixtureURL)
        let start = ContinuousClock.now
        _ = try transport.invoke(.list(storage: 7, path: "/delayed-return"), onProgress: { _ in })
        XCTAssertGreaterThanOrEqual(start.duration(to: .now), .milliseconds(90))
    }

    func testMissingLibraryProducesUsefulError() {
        XCTAssertThrowsError(try NativeKalamTransport(libraryURL: URL(fileURLWithPath: "/missing/kalam.dylib")))
    }
}
