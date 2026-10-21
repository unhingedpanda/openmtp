import XCTest

final class TransferSafetyTests: XCTestCase {
    func testFolderUploadCannotReplaceNestedDeviceDirectoryWithFile() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source/Photos")
        let deviceRoot = root.appendingPathComponent("device/Photos/Archive")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: deviceRoot, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: source.appendingPathComponent("Archive"))
        let keep = deviceRoot.appendingPathComponent("keep.jpg")
        try Data("preserved".utf8).write(to: keep)
        let transport = RecordingTransport { request in
            switch request {
            case .exists(_, let paths): return .existence(Dictionary(uniqueKeysWithValues: paths.map { ($0, true) }))
            case .list(let storage, let path):
                if path == "/" { return .entries([deviceEntry("Photos", directory: true, storage: storage)]) }
                if path == "/Photos" { return .entries([deviceEntry("Photos/Archive", directory: true, storage: storage)]) }
                return .entries([])
            case .upload:
                // Model the unchanged engine's file-over-directory replacement against disposable files.
                try FileManager.default.removeItem(at: deviceRoot)
                try Data("new".utf8).write(to: deviceRoot)
                return .confirmed
            default: return .confirmed
            }
        }
        let item = TransferItem(source: FileEntry(location: .local(source), name: "Photos", isDirectory: true, byteCount: 0, modifiedAt: nil), destination: .device(storageID: 7, path: "/"), device: DeviceFileService(session: DeviceSession(transport: transport)))
        do {
            try await NativeTransferExecutor().execute(item, replacing: true, progress: { _ in })
            XCTFail("A nested type conflict must reject the entire upload")
        } catch { XCTAssertEqual((error as? DeviceError)?.code, "UnsafeReplacement") }
        XCTAssertEqual(try Data(contentsOf: keep), Data("preserved".utf8))
    }

    func testFolderDownloadRejectsNamesThatAliasOnTheDestinationVolume() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let values = try directory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey])
        try XCTSkipIf(values.volumeSupportsCaseSensitiveNames == true, "This regression needs a case-insensitive volume")
        let transport = RecordingTransport { request in
            switch request {
            case .list(let storage, _): return .entries([deviceEntry("Photos/photo.jpg", size: 3, storage: storage), deviceEntry("Photos/PHOTO.jpg", size: 3, storage: storage)])
            case .download(_, _, let path):
                let folder = URL(fileURLWithPath: path).appendingPathComponent("Photos")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data("one".utf8).write(to: folder.appendingPathComponent("photo.jpg"))
                try Data("two".utf8).write(to: folder.appendingPathComponent("PHOTO.jpg"))
                return .confirmed
            default: return .confirmed
            }
        }
        let item = TransferItem(source: deviceEntry("Photos", directory: true), destination: .local(directory), device: DeviceFileService(session: DeviceSession(transport: transport)))
        do {
            try await NativeTransferExecutor().execute(item, replacing: false, progress: { _ in })
            XCTFail("Case-distinct source files must never collapse silently")
        } catch { XCTAssertEqual((error as? DeviceError)?.code, "DestinationNameCollision") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Photos").path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }

    func testEmptyDeviceFolderDownloadProducesItsPromisedDirectory() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let transport = RecordingTransport { request in
            if case .list = request { return .entries([]) }
            return .confirmed
        }
        let item = TransferItem(source: deviceEntry("Empty", directory: true), destination: .local(directory), device: DeviceFileService(session: DeviceSession(transport: transport)))
        try await NativeTransferExecutor().execute(item, replacing: false, progress: { _ in })
        let output = directory.appendingPathComponent("Empty")
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: output.path), [])
    }
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func deviceEntry(_ path: String, directory: Bool = false, size: Int64 = 0, storage: UInt32 = 7) -> FileEntry {
    FileEntry(location: .device(storageID: storage, path: "/" + path), name: (path as NSString).lastPathComponent, isDirectory: directory, byteCount: size, modifiedAt: nil)
}
