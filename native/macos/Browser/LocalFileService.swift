import Foundation

struct LocalFileService: Sendable {
    func entries(at url: URL) async throws -> [FileEntry] {
        try await Task.detached(priority: .userInitiated) {
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys)).map { child in
                let values = try child.resourceValues(forKeys: keys)
                return FileEntry(location: .local(child), name: child.lastPathComponent,
                                 isDirectory: values.isDirectory ?? false, byteCount: Int64(values.fileSize ?? 0),
                                 modifiedAt: values.contentModificationDate)
            }
        }.value
    }
}

extension LocalFileService {
    func trash(_ url: URL) async throws -> URL {
        try await Task.detached {
            var result: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &result)
            guard let result else { throw CocoaError(.fileWriteUnknown) }
            return result as URL
        }.value
    }
    func makeDirectory(_ url: URL) async throws {
        try await Task.detached {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }.value
    }
    func rename(_ url: URL, to name: String) async throws {
        try await Task.detached {
            let destination = url.deletingLastPathComponent().appendingPathComponent(name)
            guard !FileManager.default.fileExists(atPath: destination.path) else { throw FileActionController.collision }
            try FileManager.default.moveItem(at: url, to: destination)
        }.value
    }
}
