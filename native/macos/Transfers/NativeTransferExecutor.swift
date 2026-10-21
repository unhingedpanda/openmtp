import Foundation

struct NativeTransferExecutor: TransferExecuting {
    func destinationExists(_ item: TransferItem) async throws -> Bool {
        try FileActionController.validateName(item.source.name)
        try FileActionController.validateName(item.targetName)
        switch item.destination {
        case .local(let directory):
            return FileManager.default.fileExists(atPath: directory.appendingPathComponent(item.targetName).path)
        case .device(let storage, let path):
            guard let device = item.device else { throw DeviceError.stale }
            return try await device.exists(storage: storage, path: path.appendingPathComponent(item.targetName))
        }
    }
    func execute(_ item: TransferItem, replacing: Bool, progress: @escaping @Sendable (TransferProgress) -> Void) async throws {
        try FileActionController.validateName(item.source.name)
        try FileActionController.validateName(item.targetName)
        switch (item.source.location, item.destination) {
        case (.local(let source), .device(let storage, let path)):
            guard let device = item.device else { throw DeviceError.stale }
            let values = try source.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw DeviceError(code: "UnsupportedFile", message: "The device engine does not transfer symbolic links.")
            }
            if try await destinationExists(item) && !replacing { throw FileActionController.collision }
            _ = try await device.perform(.upload(storage: storage, sources: [source.path], destination: path), progress: progress)
        case (_, .local(let directory)):
            if case .local(let source) = item.source.location {
                let normalized = source.resolvingSymlinksInPath().standardizedFileURL.path
                let target = directory.appendingPathComponent(item.targetName).resolvingSymlinksInPath().standardizedFileURL.path
                guard target != normalized, !target.hasPrefix(normalized + "/") else {
                    throw DeviceError(code: "InvalidDestination", message: "Choose a destination outside the source item.")
                }
            }
            let staging = directory.appendingPathComponent(".openmtp-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
            var preserveStaging = false
            defer { if !preserveStaging { try? FileManager.default.removeItem(at: staging) } }
            switch item.source.location {
            case .device(let storage, let path):
                guard let device = item.device else { throw DeviceError.stale }
                _ = try await device.perform(.download(storage: storage, sources: [path], destination: staging.path), progress: progress)
            case .local(let source):
                try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.copyItem(at: source, to: staging.appendingPathComponent(item.source.name))
                }.value
            }
            let output = staging.appendingPathComponent(item.source.name)
            var directoryFlag: ObjCBool = false
            guard FileManager.default.fileExists(atPath: output.path, isDirectory: &directoryFlag), directoryFlag.boolValue == item.source.isDirectory else {
                throw DeviceError(code: "MissingOutput", message: "The transfer finished without the expected destination item.")
            }
            if !item.source.isDirectory {
                let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize
                guard Int64(size ?? -1) == item.source.byteCount else {
                    throw DeviceError(code: "PartialCopy", message: "The copied file size does not match the source.")
                }
            }
            let destination = directory.appendingPathComponent(item.targetName)
            if FileManager.default.fileExists(atPath: destination.path) {
                guard replacing else { throw FileActionController.collision }
                let backup = staging.appendingPathComponent("previous-" + UUID().uuidString)
                try FileManager.default.moveItem(at: destination, to: backup)
                do { try FileManager.default.moveItem(at: output, to: destination) }
                catch {
                    do { try FileManager.default.moveItem(at: backup, to: destination) }
                    catch {
                        // Leave this owned directory intact if restoring the original failed.
                        preserveStaging = true
                        let recovery = directory.appendingPathComponent("OpenMTP Recovery " + UUID().uuidString)
                        let recoveryURL: URL
                        do { try FileManager.default.moveItem(at: staging, to: recovery); recoveryURL = recovery }
                        catch { recoveryURL = staging }
                        throw DeviceError(code: "RestoreFailed", message: "The original item could not be restored. Recovery files: \(recoveryURL.path)")
                    }
                    throw error
                }
            } else { try FileManager.default.moveItem(at: output, to: destination) }
        default:
            throw DeviceError(code: "InvalidDestination", message: "Copy between your Mac and the device.")
        }
    }
}
