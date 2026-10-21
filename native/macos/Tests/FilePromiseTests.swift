import AppKit
import XCTest

final class FilePromiseTests: XCTestCase {
    @MainActor func testPromiseCompletesOnlyAfterDestinationFileExists() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("receiver-renamed.txt")
        let bytes = Data("promised bytes".utf8)
        let delegate = FilePromiseDelegate(entry: transferFixture().source) { url in
            try await Task.sleep(for: .milliseconds(20))
            try bytes.write(to: url)
        }
        let provider = delegate.makeProvider()
        let error = await write(provider, to: output)
        XCTAssertNil(error)
        XCTAssertEqual(try Data(contentsOf: output), bytes)
    }
    @MainActor func testPromiseSurvivesSourceWindowClosure() async throws {
        _ = NSApplication.shared
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }
        var delegate: FilePromiseDelegate? = FilePromiseDelegate(entry: transferFixture().source) { url in
            try await Task.sleep(for: .milliseconds(20))
            try Data("retained".utf8).write(to: url)
        }
        weak let retained = delegate
        let provider = delegate!.makeProvider()
        var sourceWindow: NSWindow? = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: .titled, backing: .buffered, defer: true)
        sourceWindow?.isReleasedWhenClosed = false
        sourceWindow?.close()
        sourceWindow = nil
        delegate = nil
        XCTAssertNotNil(retained)
        let error = await write(provider, to: output)
        XCTAssertNil(error)
        XCTAssertEqual(try Data(contentsOf: output), Data("retained".utf8))
    }
    @MainActor func testPromiseReportsDisconnectFailure() async {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = DeviceFileService(session: DeviceSession(transport: RecordingTransport()))
        await service.invalidate()
        let entry = FileEntry(location: .device(storageID: 7, path: "/file.txt"), name: "file.txt", isDirectory: false, byteCount: 4, modifiedAt: nil)
        let delegate = FilePromiseDelegate(entry: entry) { url in
            try await NativeTransferExecutor().execute(TransferItem(source: entry, destination: .local(url.deletingLastPathComponent()), device: service, destinationName: url.lastPathComponent), replacing: false, progress: { _ in })
        }
        let error = await write(delegate.makeProvider(), to: output)
        XCTAssertNotNil(error)
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }
    @MainActor func testDropUsesTheTargetPaneAndItsCurrentLocation() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("file".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let target = EntryLocation.device(storageID: 8, path: "/current")
        let items = try await DropCoordinator().accept(urls: [source], references: [], destination: target, generation: UUID(), device: DeviceFileService(session: DeviceSession(transport: RecordingTransport())))
        XCTAssertEqual(items.first?.destination, target)
        XCTAssertEqual(items.first?.source.location, .local(source))
    }
    @MainActor func testStaleDeviceReferenceCannotStartExport() async {
        let reference = DeviceDragReference(generation: UUID(), entry: FileEntry(location: .device(storageID: 7, path: "/file.txt"), name: "file.txt", isDirectory: false, byteCount: 4, modifiedAt: nil))
        do {
            _ = try await DropCoordinator().accept(urls: [], references: [reference], destination: .local(FileManager.default.temporaryDirectory), generation: UUID(), device: DeviceFileService(session: DeviceSession(transport: RecordingTransport())))
            XCTFail("Must reject the stale reference")
        } catch { XCTAssertEqual((error as? DeviceError)?.code, "StaleSession") }
    }
    @MainActor private func write(_ provider: NSFilePromiseProvider, to url: URL) async -> Error? {
        await withCheckedContinuation { continuation in
            provider.delegate!.filePromiseProvider(provider, writePromiseTo: url) { continuation.resume(returning: $0) }
        }
    }
}
