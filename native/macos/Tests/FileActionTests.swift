import XCTest

final class FileActionTests: XCTestCase {
    @MainActor func testDeviceDeleteRequiresConfirmation() async throws {
        let transport = RecordingTransport()
        let actions = FileActionController()
        actions.device = DeviceFileService(session: DeviceSession(transport: transport))
        let entry = FileEntry(location: .device(storageID: 7, path: "/test.txt"), name: "test.txt", isDirectory: false, byteCount: 1, modifiedAt: nil)
        do { try await actions.delete([entry], confirmed: false); XCTFail("Must require confirmation") }
        catch { XCTAssertEqual((error as? DeviceError)?.code, "ConfirmationRequired") }
        XCTAssertEqual(transport.count("DeleteFile"), 0)
        try await actions.delete([entry], confirmed: true)
        XCTAssertEqual(transport.count("DeleteFile"), 1)
    }
    func testLocalDeleteUsesTrash() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("OpenMTP-trash-" + UUID().uuidString)
        try Data("disposable".utf8).write(to: source)
        let trashURL = try await LocalFileService().trash(source)
        defer { try? FileManager.default.removeItem(at: trashURL) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: trashURL), Data("disposable".utf8))
    }
    @MainActor func testRenameRejectsPathSeparatorsAndNameCollisions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.txt")
        let existing = directory.appendingPathComponent("existing.txt")
        try Data("source".utf8).write(to: source)
        try Data("preserved".utf8).write(to: existing)
        let entry = FileEntry(location: .local(source), name: source.lastPathComponent, isDirectory: false, byteCount: 6, modifiedAt: nil)
        let actions = FileActionController()
        for name in ["../escape", "sub/file", "existing.txt"] {
            do { try await actions.rename(entry, to: name); XCTFail("Must reject \(name)") } catch {}
        }
        XCTAssertEqual(try Data(contentsOf: existing), Data("preserved".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        try await actions.rename(entry, to: "旅行.txt")
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("旅行.txt")), Data("source".utf8))
    }
}
