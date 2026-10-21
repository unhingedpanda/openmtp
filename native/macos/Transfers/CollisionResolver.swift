import Foundation
import Observation

@MainActor @Observable final class CollisionResolver {
    private(set) var pending: TransferItem?
    private var continuation: CheckedContinuation<CollisionDecision, Never>?
    func resolve(_ item: TransferItem) async -> CollisionDecision {
        pending = item
        return await withCheckedContinuation { continuation = $0 }
    }
    func decide(_ value: CollisionDecision) {
        let next = continuation
        continuation = nil
        pending = nil
        next?.resume(returning: value)
    }
}
