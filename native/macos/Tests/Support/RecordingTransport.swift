import Foundation

final class RecordingTransport: KalamTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var symbols: [String] = []
    let handler: @Sendable (DeviceRequest) throws -> DeviceReply
    init(handler: @escaping @Sendable (DeviceRequest) throws -> DeviceReply = { request in
        switch request {
        case .initialize: return .device(DeviceInfo(name: "Test phone", manufacturer: "Fixture"))
        case .storages: return .storages([DeviceStorage(id: 7, name: "Internal"), DeviceStorage(id: 8, name: "SD card")])
        case .list(let storage, let path):
            if path == "/slow" { Thread.sleep(forTimeInterval: 0.08) }
            return .entries([FileEntry(location: .device(storageID: storage, path: "/\(storage).txt"), name: "\(storage).txt", isDirectory: false, byteCount: 4, modifiedAt: nil)])
        case .exists(_, let paths): return .existence(Dictionary(uniqueKeysWithValues: paths.map { ($0, false) }))
        default: return .confirmed
        }
    }) { self.handler = handler }
    func invoke(_ request: DeviceRequest, onProgress: @Sendable (TransferProgress) -> Void) throws -> DeviceReply {
        lock.withLock { symbols.append(request.symbol) }
        return try handler(request)
    }
    func count(_ symbol: String) -> Int { lock.withLock { symbols.filter { $0 == symbol }.count } }
}
