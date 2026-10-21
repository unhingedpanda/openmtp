import Foundation

struct TransferItem: Identifiable, Sendable {
    let id = UUID()
    let source: FileEntry
    let destination: EntryLocation
    var device: DeviceFileService? = nil
    var destinationName: String? = nil
    var targetName: String { destinationName ?? source.name }
}
enum TransferState: Equatable { case queued, running, completed, skipped, stopped, failed(String) }
struct TransferRecord: Identifiable {
    let item: TransferItem
    var state: TransferState = .queued
    var id: UUID { item.id }
}
enum CollisionDecision { case replace, skip, stop }
protocol TransferExecuting: Sendable {
    func destinationExists(_ item: TransferItem) async throws -> Bool
    func execute(_ item: TransferItem, replacing: Bool, progress: @escaping @Sendable (TransferProgress) -> Void) async throws
}
