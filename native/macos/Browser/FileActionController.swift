import Foundation

@MainActor final class FileActionController {
    var device: DeviceFileService?
    nonisolated static let collision = DeviceError(code: "NameCollision", message: "An item with this name already exists. Choose another name.")
    nonisolated static func validateName(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name != ".", name != "..", !name.contains("/"), !name.contains("\\"), !name.contains("\0") else {
            throw DeviceError(code: "InvalidName", message: "Enter a name without path separators.")
        }
    }
    func makeDirectory(at location: EntryLocation, name: String) async throws {
        try Self.validateName(name)
        switch location {
        case .local(let url): try await LocalFileService().makeDirectory(url.appendingPathComponent(name))
        case .device(let storage, let path):
            guard let device else { throw DeviceError.stale }
            try await device.makeDirectory(storage: storage, path: path.appendingPathComponent(name))
        }
    }
    func rename(_ entry: FileEntry, to name: String) async throws {
        try Self.validateName(name)
        if name == entry.name { return }
        switch entry.location {
        case .local(let url): try await LocalFileService().rename(url, to: name)
        case .device(let storage, let path):
            guard let device else { throw DeviceError.stale }
            try await device.rename(storage: storage, path: path, name: name)
        }
    }
    func delete(_ entries: [FileEntry], confirmed: Bool) async throws {
        if entries.contains(where: { if case .device = $0.location { true } else { false } }) && !confirmed {
            throw DeviceError(code: "ConfirmationRequired", message: "Device deletion is permanent and requires confirmation.")
        }
        for entry in entries {
            switch entry.location {
            case .local(let url): _ = try await LocalFileService().trash(url)
            case .device(let storage, let path):
                guard let device else { throw DeviceError.stale }
                try await device.delete(storage: storage, paths: [path])
            }
        }
    }
}

extension String {
    func appendingPathComponent(_ component: String) -> String { (self as NSString).appendingPathComponent(component) }
}
