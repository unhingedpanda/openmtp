import AppKit
import Foundation

struct DeviceDragReference: Codable, Sendable {
    let generation: UUID
    let location: EntryLocation
    let name: String
    let isDirectory: Bool
    let byteCount: Int64
    init(generation: UUID, entry: FileEntry) {
        self.generation = generation
        location = entry.location
        name = entry.name
        isDirectory = entry.isDirectory
        byteCount = entry.byteCount
    }
    var entry: FileEntry { FileEntry(location: location, name: name, isDirectory: isDirectory, byteCount: byteCount, modifiedAt: nil) }
}

@MainActor struct DropCoordinator {
    func accept(urls: [URL], references: [DeviceDragReference], destination: EntryLocation, generation: UUID, device: DeviceFileService?) async throws -> [TransferItem] {
        guard !urls.isEmpty || !references.isEmpty else { return [] }
        guard urls.isEmpty || references.isEmpty else { throw DeviceError(code: "InvalidDrop", message: "Drop one kind of source at a time.") }
        if destination.isDevice && device == nil { throw DeviceError.stale }
        if !references.isEmpty {
            guard !destination.isDevice else { throw DeviceError(code: "InvalidDrop", message: "Drag device files to your Mac.") }
            for reference in references {
                guard reference.generation == generation, device != nil,
                      case .device(_, let path) = reference.location, path.hasPrefix("/"),
                      (path as NSString).lastPathComponent == reference.name,
                      (path as NSString).standardizingPath == path, reference.byteCount >= 0 else { throw DeviceError.stale }
                try FileActionController.validateName(reference.name)
            }
            return references.map { TransferItem(source: $0.entry, destination: destination, device: device) }
        }
        let entries = try await Task.detached(priority: .userInitiated) {
            try urls.map { url in
                guard url.isFileURL else { throw DeviceError(code: "InvalidDrop", message: "Drop local files or folders.") }
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                return FileEntry(location: .local(url), name: url.lastPathComponent, isDirectory: values.isDirectory ?? false,
                                 byteCount: Int64(values.fileSize ?? 0), modifiedAt: values.contentModificationDate)
            }
        }.value
        return entries.map { TransferItem(source: $0, destination: destination, device: device) }
    }
}

@MainActor enum BrowserPasteboard {
    nonisolated static let deviceType = NSPasteboard.PasteboardType("dev.yash.openmtp.native.device-file")
    nonisolated static let types: [NSPasteboard.PasteboardType] = [.fileURL, deviceType]
    static func read(_ pasteboard: NSPasteboard) -> (urls: [URL], references: [DeviceDragReference]) {
        let references = (pasteboard.pasteboardItems ?? []).compactMap { item in
            item.data(forType: deviceType).flatMap { try? JSONDecoder().decode(DeviceDragReference.self, from: $0) }
        }
        if !references.isEmpty { return ([], references) }
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return (urls, [])
    }
    static func canRead(_ pasteboard: NSPasteboard) -> Bool { pasteboard.availableType(from: types) != nil }
}
