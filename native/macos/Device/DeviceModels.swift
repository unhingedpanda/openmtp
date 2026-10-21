import Foundation

struct DeviceStorage: Identifiable, Equatable, Sendable {
    let id: UInt32
    let name: String
}

struct DeviceInfo: Equatable, Sendable {
    let name: String
    let manufacturer: String
    var usb: USBDeviceIdentity? = nil
}

struct USBDeviceIdentity: Equatable, Sendable {
    let vendor: UInt16
    let product: UInt16
    var serial: String? = nil
}

struct DeviceError: Error, LocalizedError, Equatable, Sendable {
    let code: String
    let message: String
    var errorDescription: String? { message }
    static let stale = DeviceError(code: "StaleSession", message: "The device connection changed. Please reconnect.")
    static let unimplemented = DeviceError(code: "NotImplemented", message: "Native bridge is not implemented.")
}

struct TransferProgress: Equatable, Sendable {
    let name: String
    let sent: Int64
    let total: Int64
    let speedMB: Double
}

enum DeviceRequest: Sendable {
    case initialize, deviceInfo, storages, dispose
    case list(storage: UInt32, path: String)
    case exists(storage: UInt32, paths: [String])
    case mkdir(storage: UInt32, path: String)
    case rename(storage: UInt32, path: String, name: String)
    case delete(storage: UInt32, paths: [String])
    case upload(storage: UInt32, sources: [String], destination: String)
    case download(storage: UInt32, sources: [String], destination: String)
}

enum DeviceReply: Sendable {
    case device(DeviceInfo)
    case storages([DeviceStorage])
    case entries([FileEntry])
    case existence([String: Bool])
    case confirmed
}
