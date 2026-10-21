import Foundation
import Observation
import AppKit

enum PaneKind: String, Sendable { case local, device }
enum BrowserViewMode: String, CaseIterable, Codable, Sendable { case list, grid }
enum BrowserSortKey: String, Sendable { case name, size, modified }

@MainActor @Observable final class PaneModel {
    let kind: PaneKind
    var location: EntryLocation
    private(set) var entries: [FileEntry] = []
    private(set) var visibleEntries: [FileEntry] = []
    private(set) var contentRevision = 0
    var selection: Set<EntryLocation> = []
    var error: String?
    var viewMode: BrowserViewMode = .list
    var showHidden = false { didSet { rebuild() } }
    var sortKey: BrowserSortKey = .name { didSet { rebuild(); onSortChanged?() } }
    var sortAscending = true { didSet { rebuild(); onSortChanged?() } }
    var onSortChanged: (() -> Void)?
    var loading = false
    var onFocus: (() -> Void)?
    var onActivate: ((FileEntry) -> Void)?
    var onRename: ((FileEntry, String) -> Void)?
    var onDelete: (() -> Void)?
    var onNewFolder: (() -> Void)?
    var onRenameRequested: (() -> Void)?
    var onDrop: (([URL], [EntryLocation]) -> Void)?
    var onExport: ((FileEntry) -> NSFilePromiseProvider?)?
    var loader: @Sendable (EntryLocation) async throws -> [FileEntry]
    private var requestGeneration = 0
    init(kind: PaneKind, location: EntryLocation, loader: @escaping @Sendable (EntryLocation) async throws -> [FileEntry]) {
        self.kind = kind; self.location = location; self.loader = loader
    }
    var selectedEntries: [FileEntry] { visibleEntries.filter { selection.contains($0.id) } }
    func setSelection(_ value: Set<EntryLocation>) {
        selection = value.intersection(Set(visibleEntries.map(\.id)))
        onFocus?()
    }
    func navigate(to destination: EntryLocation) async {
        requestGeneration += 1
        let generation = requestGeneration
        loading = true
        error = nil
        do {
            let result = try await loader(destination)
            guard generation == requestGeneration else { return }
            if destination != location { selection.removeAll() }
            location = destination
            entries = result
            rebuild()
        } catch {
            guard generation == requestGeneration else { return }
            self.error = error.localizedDescription
        }
        loading = false
    }
    func refresh() async { await navigate(to: location) }
    func clear() {
        requestGeneration += 1
        entries = []; selection = []; error = nil; loading = false
        rebuild()
    }
    func activate(_ entry: FileEntry) {
        onFocus?()
        if entry.isDirectory { Task { await navigate(to: entry.location) } }
        else { onActivate?(entry) }
    }
    func goUp() {
        switch location {
        case .local(let url): Task { await navigate(to: .local(url.deletingLastPathComponent())) }
        case .device(let storage, let path):
            let parent = (path as NSString).deletingLastPathComponent
            Task { await navigate(to: .device(storageID: storage, path: parent.isEmpty ? "/" : parent)) }
        }
    }
    private func rebuild() {
        visibleEntries = entries.filter { showHidden || !$0.name.hasPrefix(".") }.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            let result: ComparisonResult
            switch sortKey {
            case .name: result = a.name.localizedStandardCompare(b.name)
            case .size: result = a.byteCount == b.byteCount ? a.name.localizedStandardCompare(b.name) : (a.byteCount < b.byteCount ? .orderedAscending : .orderedDescending)
            case .modified: result = (a.modifiedAt ?? .distantPast).compare(b.modifiedAt ?? .distantPast)
            }
            return sortAscending ? result == .orderedAscending : result == .orderedDescending
        }
        selection.formIntersection(Set(visibleEntries.map(\.id)))
        contentRevision += 1
    }
}
