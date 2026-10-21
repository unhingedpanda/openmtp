import Foundation

protocol KalamTransport: Sendable {
    func invoke(_ request: DeviceRequest, onProgress: @Sendable (TransferProgress) -> Void) throws -> DeviceReply
}

final class NativeKalamTransport: KalamTransport, @unchecked Sendable {
    private let handle: UnsafeMutableRawPointer
    init(libraryURL: URL) throws {
        guard let loaded = omtp_open(libraryURL.path) else {
            throw DeviceError(code: "EngineUnavailable", message: "Could not load the device engine. \(String(cString: omtp_error()))")
        }
        handle = loaded
    }
    func invoke(_ request: DeviceRequest, onProgress: @Sendable (TransferProgress) -> Void) throws -> DeviceReply {
        try withoutActuallyEscaping(onProgress) { handler in
            let context = CallbackContext(progress: handler)
            let pointer = Unmanaged.passRetained(context).toOpaque()
            defer { Unmanaged<CallbackContext>.fromOpaque(pointer).release() }
            let input = try request.inputJSON()
            let result = omtp_invoke(handle, request.symbol, input, request.style, { kind, packet, raw in
                guard let packet, let raw else { return }
                let context = Unmanaged<CallbackContext>.fromOpaque(raw).takeUnretainedValue()
                context.receive(kind: kind, data: Data(String(cString: packet).utf8))
            }, pointer)
            guard result == 0, let data = context.finalData else {
                throw DeviceError(code: "InvalidResponse", message: "The device engine returned no result. Try reconnecting.")
            }
            return try request.decode(data)
        }
    }
}

private final class CallbackContext: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Data?
    private let progress: @Sendable (TransferProgress) -> Void
    init(progress: @escaping @Sendable (TransferProgress) -> Void) { self.progress = progress }
    var finalData: Data? { lock.withLock { result } }
    func receive(kind: Int32, data: Data) {
        if kind == 2 { lock.withLock { result = data } }
        if kind == 1, let raw = try? JSONDecoder().decode(Envelope<RawProgress>.self, from: data), let value = raw.data {
            progress(TransferProgress(name: value.name ?? "", sent: value.bulkFileSize?.sent ?? 0,
                                      total: value.bulkFileSize?.total ?? 0, speedMB: value.speed ?? 0))
        }
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let error: String?
    let errorType: String?
    let data: T?
}
private struct ErrorEnvelope: Decodable { let error: String?; let errorType: String? }
private struct RawEntry: Decodable {
    let size: Int64; let isFolder: Bool; let dateAdded: String?; let name: String; let path: String
}
private struct RawStorage: Decodable {
    let Sid: UInt32; let Info: InfoValue
    struct InfoValue: Decodable { let StorageDescription: String }
}
private struct RawDevice: Decodable {
    let mtpDeviceInfo: InfoValue
    struct InfoValue: Decodable { let Model: String?; let Manufacturer: String? }
}
private struct RawExistence: Decodable { let fullpath: String; let exists: Bool }
private struct RawProgress: Decodable {
    let name: String?; let speed: Double?; let bulkFileSize: Size?
    struct Size: Decodable { let sent: Int64; let total: Int64 }
}

extension DeviceRequest {
    var symbol: String {
        switch self {
        case .initialize: "Initialize"
        case .deviceInfo: "FetchDeviceInfo"
        case .storages: "FetchStorages"
        case .dispose: "Dispose"
        case .list: "Walk"
        case .exists: "FileExists"
        case .mkdir: "MakeDirectory"
        case .rename: "RenameFile"
        case .delete: "DeleteFile"
        case .upload: "UploadFiles"
        case .download: "DownloadFiles"
        }
    }
    var style: Int32 {
        switch self {
        case .initialize, .deviceInfo, .storages, .dispose: 0
        case .upload, .download: 2
        default: 1
        }
    }
    func inputJSON() throws -> String {
        let args: [String: Any]
        switch self {
        case .list(let storage, let path):
            args = ["storageId":storage,"fullPath":path,"recursive":false,"skipDisallowedFiles":true,"skipHiddenFiles":false]
        case .exists(let storage, let paths), .delete(let storage, let paths):
            args = ["storageId":storage,"Files":paths]
        case .mkdir(let storage, let path): args = ["storageId":storage,"fullPath":path]
        case .rename(let storage, let path, let name): args = ["storageId":storage,"fullPath":path,"newFileName":name]
        case .upload(let storage, let sources, let destination), .download(let storage, let sources, let destination):
            args = ["storageId":storage,"sources":sources,"destination":destination,"preprocessFiles":true]
        default: args = [:]
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: args), as: UTF8.self)
    }
    func decode(_ data: Data) throws -> DeviceReply {
        let decoder = JSONDecoder()
        let header = try decoder.decode(ErrorEnvelope.self, from: data)
        if let message = header.error, !message.isEmpty {
            throw DeviceError(code: header.errorType ?? "ErrorGeneral", message: message)
        }
        func payload<T: Decodable>(_ type: T.Type) throws -> T {
            guard let value = try decoder.decode(Envelope<T>.self, from: data).data else {
                throw DeviceError(code: "InvalidResponse", message: "The device returned incomplete information. Try reconnecting.")
            }
            return value
        }
        switch self {
        case .initialize, .deviceInfo:
            let value = try payload(RawDevice.self).mtpDeviceInfo
            return .device(DeviceInfo(name: value.Model ?? "MTP device", manufacturer: value.Manufacturer ?? ""))
        case .storages:
            return .storages(try payload([RawStorage].self).map { DeviceStorage(id: $0.Sid, name: $0.Info.StorageDescription) })
        case .list(let storage, _):
            let formatter = ISO8601DateFormatter()
            return .entries(try payload([RawEntry].self).map {
                FileEntry(location: .device(storageID: storage, path: $0.path), name: $0.name,
                          isDirectory: $0.isFolder, byteCount: $0.size, modifiedAt: $0.dateAdded.flatMap(formatter.date))
            })
        case .exists:
            return .existence(Dictionary(try payload([RawExistence].self).map { ($0.fullpath, $0.exists) }, uniquingKeysWith: { _, new in new }))
        default:
            guard try payload(Bool.self) else { throw DeviceError(code: "OperationFailed", message: "The device did not complete this operation.") }
            return .confirmed
        }
    }
}
