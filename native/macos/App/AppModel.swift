import Foundation
import Observation

@MainActor @Observable final class AppModel {
    let preferences: BrowserPreferences
    let localService = LocalFileService()
    let localPane: PaneModel
    let devicePane: PaneModel
    var activePaneKind: PaneKind = .local
    var deviceName = "Device"
    var connected = false
    var connecting = false
    var session: DeviceSession?
    var connectAction: (() -> Void)?
    var transferAction: (() -> Void)?
    var canTransfer = false
    var alert: String?
    var activePane: PaneModel { activePaneKind == .local ? localPane : devicePane }

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--ui-testing")
        preferences = BrowserPreferences(defaults: testing ? UserDefaults(suiteName: "dev.yash.openmtp.native.uitests")! : .standard)
        let root: URL
        if let index = arguments.firstIndex(of: "--directory"), arguments.indices.contains(index + 1) {
            root = URL(fileURLWithPath: arguments[index + 1])
        } else { root = FileManager.default.homeDirectoryForCurrentUser }
        let local = LocalFileService()
        localPane = PaneModel(kind: .local, location: .local(root)) { location in
            guard case .local(let url) = location else { throw DeviceError.stale }
            return try await local.entries(at: url)
        }
        devicePane = PaneModel(kind: .device, location: .device(storageID: 0, path: "/")) { _ in
            throw DeviceError(code: "Disconnected", message: "Connect a device to browse its files.")
        }
        localPane.sortKey = preferences.localSortKey
        localPane.sortAscending = preferences.localSortAscending
        devicePane.sortKey = preferences.deviceSortKey
        devicePane.sortAscending = preferences.deviceSortAscending
        localPane.onSortChanged = { [weak self] in
            guard let self else { return }
            preferences.localSortKey = localPane.sortKey
            preferences.localSortAscending = localPane.sortAscending
        }
        devicePane.onSortChanged = { [weak self] in
            guard let self else { return }
            preferences.deviceSortKey = devicePane.sortKey
            preferences.deviceSortAscending = devicePane.sortAscending
        }
        localPane.viewMode = testing ? .list : preferences.localView
        devicePane.viewMode = preferences.deviceView
        localPane.onFocus = { [weak self] in self?.activePaneKind = .local }
        devicePane.onFocus = { [weak self] in self?.activePaneKind = .device }
    }
    func start() async { await localPane.refresh() }
}
