import Foundation

actor DeviceSession {
    private static let worker = DispatchQueue(label: "dev.yash.openmtp.device", qos: .userInitiated)
    private let transport: any KalamTransport
    private var generation = 0
    init(transport: any KalamTransport) { self.transport = transport }
    func invalidate() { generation += 1 }
    func perform(_ request: DeviceRequest, onProgress: @escaping @Sendable (TransferProgress) -> Void = { _ in }) async throws -> DeviceReply {
        let issuedGeneration = generation
        let transport = transport
        let reply = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DeviceReply, Error>) in
            Self.worker.async {
                do { continuation.resume(returning: try transport.invoke(request, onProgress: onProgress)) }
                catch { continuation.resume(throwing: error) }
            }
        }
        guard issuedGeneration == generation else { throw DeviceError.stale }
        return reply
    }
}
