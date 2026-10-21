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
