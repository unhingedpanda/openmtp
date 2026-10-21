import Foundation

actor DeviceSession {
    private static let worker = DispatchQueue(label: "dev.yash.openmtp.device", qos: .userInitiated)
    private let transport: any KalamTransport
    private let validity = SessionValidity()
    init(transport: any KalamTransport) { self.transport = transport }
    func invalidate() { validity.invalidate() }
    func perform(_ request: DeviceRequest, onProgress: @escaping @Sendable (TransferProgress) -> Void = { _ in }) async throws -> DeviceReply {
        let issuedGeneration = validity.current
        let transport = transport
        let validity = validity
        let reply = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DeviceReply, Error>) in
            Self.worker.async {
                do {
                    guard validity.current == issuedGeneration else { throw DeviceError.stale }
                    continuation.resume(returning: try transport.invoke(request, onProgress: onProgress))
                }
                catch { continuation.resume(throwing: error) }
            }
        }
        guard issuedGeneration == validity.current else { throw DeviceError.stale }
        return reply
    }
}

private final class SessionValidity: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = 0
    var current: Int { lock.withLock { generation } }
    func invalidate() { lock.withLock { generation += 1 } }
}
