import AppKit
import UniformTypeIdentifiers

@MainActor final class FilePromiseDelegate: NSObject, NSFilePromiseProviderDelegate {
    nonisolated let entry: FileEntry
    nonisolated private let writer: @Sendable (URL) async throws -> Void
    init(entry: FileEntry, write: @escaping @Sendable (URL) async throws -> Void) {
        self.entry = entry
        writer = write
    }
    func makeProvider(reference: DeviceDragReference? = nil) -> NSFilePromiseProvider {
        let type = entry.isDirectory ? UTType.folder.identifier : (UTType(filenameExtension: (entry.name as NSString).pathExtension) ?? .data).identifier
        let provider = DeviceFilePromiseProvider(type: type, delegate: self, referenceData: reference.flatMap { try? JSONEncoder().encode($0) })
        // AppKit's delegate property is weak. userInfo keeps the writer alive for the entire promise.
        provider.userInfo = self
        return provider
    }
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String { entry.name }
    nonisolated func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        let completion = PromiseCompletion(completionHandler)
        let writer = writer
        Task {
            do {
                try await writer(url)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw DeviceError(code: "MissingOutput", message: "The promised file was not created.")
                }
                completion.finish(nil)
            } catch { completion.finish(error) }
        }
    }
}

private final class DeviceFilePromiseProvider: NSFilePromiseProvider {
    let referenceData: Data?
    init(type: String, delegate: any NSFilePromiseProviderDelegate, referenceData: Data?) {
        self.referenceData = referenceData
        super.init()
        fileType = type
        self.delegate = delegate
    }
    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        let standard = super.writableTypes(for: pasteboard)
        return referenceData == nil ? standard : standard + [BrowserPasteboard.deviceType]
    }
    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == BrowserPasteboard.deviceType { return referenceData }
        return super.pasteboardPropertyList(forType: type)
    }
}

private final class PromiseCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: ((Error?) -> Void)?
    init(_ callback: @escaping (Error?) -> Void) { self.callback = callback }
    func finish(_ error: Error?) {
        let next = lock.withLock { let next = callback; callback = nil; return next }
        next?(error)
    }
}
