import Foundation

enum EntryLocation: Hashable, Codable, Sendable {
    case local(URL)
    case device(storageID: UInt32, path: String)

    var path: String {
        switch self {
        case .local(let url): url.path
        case .device(_, let path): path
        }
    }
}

struct FileEntry: Identifiable, Hashable, Sendable {
    var id: EntryLocation { location }
    let location: EntryLocation
    let name: String
    let isDirectory: Bool
    let byteCount: Int64
    let modifiedAt: Date?
}
