import Foundation

actor DeviceFileService {
    let session: DeviceSession
    private var active = true
    init(session: DeviceSession) { self.session = session }
    func invalidate() async { active = false; await session.invalidate() }
    func perform(_ request: DeviceRequest, progress: @escaping @Sendable (TransferProgress) -> Void = { _ in }) async throws -> DeviceReply {
        guard active else { throw DeviceError.stale }
        let reply = try await session.perform(request, onProgress: progress)
        guard active else { throw DeviceError.stale }
        return reply
    }
    func entries(storage: UInt32, path: String) async throws -> [FileEntry] {
        guard case .entries(let entries) = try await perform(.list(storage: storage, path: path)) else { throw DeviceError.stale }
        return entries
    }
    func exists(storage: UInt32, path: String) async throws -> Bool {
        guard case .existence(let values) = try await perform(.exists(storage: storage, paths: [path])), let exists = values[path] else {
            throw DeviceError(code: "InvalidResponse", message: "The device did not confirm whether the destination exists.")
        }
        return exists
    }
    func makeDirectory(storage: UInt32, path: String) async throws {
        guard try await !exists(storage: storage, path: path) else { throw FileActionController.collision }
        _ = try await perform(.mkdir(storage: storage, path: path))
    }
    func rename(storage: UInt32, path: String, name: String) async throws {
        let destination = (path as NSString).deletingLastPathComponent.appendingPathComponent(name)
        guard try await !exists(storage: storage, path: destination) else { throw FileActionController.collision }
        _ = try await perform(.rename(storage: storage, path: path, name: name))
    }
    func delete(storage: UInt32, paths: [String]) async throws { _ = try await perform(.delete(storage: storage, paths: paths)) }
}
