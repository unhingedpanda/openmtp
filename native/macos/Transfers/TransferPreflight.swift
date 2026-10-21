import Foundation

struct ExpectedDownload: Sendable {
    let url: URL
    let directory: Bool
    let bytes: Int64
}

struct TransferPreflight {
    func validateUpload(source: URL, storage: UInt32, parent: String, device: DeviceFileService) async throws {
        let siblings = try await device.entries(storage: storage, path: parent)
        try await validateUpload(source: source, storage: storage, parent: parent, siblings: siblings, device: device)
    }

    private func validateUpload(source: URL, storage: UInt32, parent: String, siblings: [FileEntry], device: DeviceFileService) async throws {
        let values = try source.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey])
        guard values.isSymbolicLink != true, values.isDirectory == true || values.isRegularFile == true else {
            throw DeviceError(code: "UnsupportedFile", message: "The device engine transfers regular files and folders, without symbolic links.")
        }
        let existing = siblings.first { $0.name == source.lastPathComponent }
        let directory = values.isDirectory == true
        if let existing, existing.isDirectory != directory {
            throw DeviceError(code: "UnsafeReplacement", message: "A file and folder share the name “\(source.lastPathComponent)”. Rename one before copying to preserve its contents.")
        }
        guard directory else { return }
        let destination = parent.appendingPathComponent(source.lastPathComponent)
        let children: [FileEntry]
        if existing != nil { children = try await device.entries(storage: storage, path: destination) }
        else { children = [] }
        let sources = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for child in sources {
            try await validateUpload(source: child, storage: storage, parent: destination, siblings: children, device: device)
        }
    }

    func prepareDownload(storage: UInt32, source: String, output: URL, device: DeviceFileService) async throws -> [ExpectedDownload] {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        var expected = [ExpectedDownload(url: output, directory: true, bytes: 0)]
        for entry in try await device.entries(storage: storage, path: source) {
            try FileActionController.validateName(entry.name)
            guard entry.location == .device(storageID: storage, path: source.appendingPathComponent(entry.name)), entry.byteCount >= 0 else {
                throw DeviceError(code: "InvalidResponse", message: "The device returned an invalid folder entry.")
            }
            let destination = output.appendingPathComponent(entry.name)
            do {
                // Exclusive creation applies this actual volume's case and normalization rules.
                if entry.isDirectory {
                    expected += try await prepareDownload(storage: storage, source: source.appendingPathComponent(entry.name), output: destination, device: device)
                } else {
                    try Data().write(to: destination, options: .withoutOverwriting)
                    expected.append(ExpectedDownload(url: destination, directory: false, bytes: entry.byteCount))
                }
            } catch {
                if FileManager.default.fileExists(atPath: destination.path),
                   (error as NSError).code == CocoaError.Code.fileWriteFileExists.rawValue {
                    throw DeviceError(code: "DestinationNameCollision", message: "Two device names map to the same name on this Mac. Rename one on the device before copying.")
                }
                throw error
            }
        }
        return expected
    }

    func validateDownload(_ expected: [ExpectedDownload]) throws {
        for item in expected {
            let values = try item.url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true, values.isDirectory == item.directory,
                  item.directory || Int64(values.fileSize ?? -1) == item.bytes else {
                throw DeviceError(code: "PartialCopy", message: "The downloaded folder does not match the source. The destination was left unchanged.")
            }
        }
    }
}
