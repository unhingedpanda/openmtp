import Foundation

final class ScriptedTransport: KalamTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private(set) var maximumActive = 0
    private(set) var ranOnMain = false
    var started: (@Sendable () -> Void)?

    func invoke(_ request: DeviceRequest, onProgress: @Sendable (TransferProgress) -> Void) throws -> DeviceReply {
        lock.lock()
        active += 1
        maximumActive = max(active, maximumActive)
        ranOnMain = ranOnMain || Thread.isMainThread
        lock.unlock()
        started?()
        Thread.sleep(forTimeInterval: 0.06)
        lock.lock()
        active -= 1
        lock.unlock()
        return .confirmed
    }
}
