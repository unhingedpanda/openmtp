import Foundation
import Observation
import AppKit

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
    let transfers = TransferCoordinator()
    var canTransfer: Bool { connected && !engineBusy && !transfers.busy && !activePane.selection.isEmpty }
    let fileActions = FileActionController()
    var storages: [DeviceStorage] = []
    var selectedStorageID: UInt32?
    var connectionMessage: String?
    private(set) var engineBusy = false
    private var pendingReconnect = false
    private var connectionEpoch = 0
    private(set) var connectionToken = UUID()
    private var monitor: USBMonitor?
    private let monitorUSB: Bool
    private var started = false
    var naming: NamingOperation?
    var nameInput = ""
    var pendingDelete: [FileEntry] = []
    var alert: String?
    var transferSymbol: String { (activePaneKind == .local) == preferences.localOnLeft ? "arrow.right" : "arrow.left" }
    var activePane: PaneModel { activePaneKind == .local ? localPane : devicePane }

    init(session: DeviceSession? = nil, monitorUSB: Bool = true) {
        self.session = session
        self.monitorUSB = monitorUSB
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--ui-testing")
        let defaults = testing ? UserDefaults(suiteName: "dev.yash.openmtp.native.uitests")! : .standard
        if testing { defaults.removePersistentDomain(forName: "dev.yash.openmtp.native.uitests") }
        preferences = BrowserPreferences(defaults: defaults)
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
        connectAction = { [weak self] in Task { await self?.connect() } }
        for pane in [localPane, devicePane] {
            pane.onCopy = { [weak self, weak pane] in
                guard let self, let pane else { return }
                activePaneKind = pane.kind
                copySelection()
            }
            pane.onDrop = { [weak self, weak pane] urls, references in
                guard let self, let pane, !engineBusy else { return }
                let destination = pane.location
                let generation = connectionToken
                let device = fileActions.device
                Task {
                    do {
                        let items = try await DropCoordinator().accept(urls: urls, references: references, destination: destination, generation: generation, device: device)
                        transfers.enqueue(items)
                    } catch { alert = error.localizedDescription }
                }
            }
            pane.onExport = { [weak self, weak pane] entry in
                guard let self, let pane, connected, !engineBusy, pane.entries.contains(entry), let device = fileActions.device else { return nil }
                let queue = transfers
                let reference = DeviceDragReference(generation: connectionToken, entry: entry)
                let delegate = FilePromiseDelegate(entry: entry) { url in
                    try await queue.enqueueAndWait(TransferItem(source: entry, destination: .local(url.deletingLastPathComponent()), device: device, destinationName: url.lastPathComponent))
                }
                return delegate.makeProvider(reference: reference)
            }
            pane.onRename = { [weak self, weak pane] entry, name in
                guard let self, let pane, pane.entries.contains(entry), pane.kind == .local || connected else { return }
                runMutation(pane: pane) { try await self.fileActions.rename(entry, to: name) }
            }
            pane.onDelete = { [weak self, weak pane] in
                guard let self, let pane else { return }
                activePaneKind = pane.kind
                requestDelete()
            }
            pane.onNewFolder = { [weak self, weak pane] in
                guard let self, let pane else { return }
                activePaneKind = pane.kind
                requestNewFolder()
            }
            pane.onRenameRequested = { [weak self, weak pane] in
                guard let self, let pane else { return }
                activePaneKind = pane.kind
                requestRename()
            }
        }
        transferAction = { [weak self] in self?.copySelection() }
        transfers.activityChanged = { [weak self] busy in
            guard let self else { return }
            await setEngineBusy(busy)
            if !busy {
                await localPane.refresh()
                if connected { await devicePane.refresh() }
            }
        }
        localPane.onActivate = { entry in
            if case .local(let url) = entry.location { NSWorkspace.shared.open(url) }
        }
    }
    func start() async {
        guard !started else { return }
        started = true
        if monitorUSB { monitor = USBMonitor { [weak self] attached in self?.usbChanged(attached: attached) } }
        await localPane.refresh()
        await connect()
    }
    func connect() async {
        guard !engineBusy, !connecting else { pendingReconnect = true; return }
        connecting = true
        connectionEpoch += 1
        let epoch = connectionEpoch
        clearDevice()
        defer { if epoch == connectionEpoch { connecting = false } }
        do {
            if session == nil {
                guard let resources = Bundle.main.resourceURL else { throw DeviceError.stale }
                let url = resources.appendingPathComponent("Engine/kalam-seg5.dylib")
                let transport = try await Task.detached { try NativeKalamTransport(libraryURL: url) }.value
                session = DeviceSession(transport: transport)
            }
            guard let session else { throw DeviceError.stale }
            await fileActions.device?.invalidate()
            await session.invalidate()
            _ = try await session.perform(.dispose)
            guard case .device(let info) = try await session.perform(.initialize),
                  case .storages(let values) = try await session.perform(.storages), let first = values.first else {
                throw DeviceError(code: "ErrorNoStorage", message: "Unlock the device and allow storage access.")
            }
            guard epoch == connectionEpoch else { return }
            let service = DeviceFileService(session: session)
            fileActions.device = service
            devicePane.loader = { location in
                guard case .device(let storage, let path) = location else { throw DeviceError.stale }
                return try await service.entries(storage: storage, path: path)
            }
            deviceName = info.name
            storages = values
            connected = true
            connectionMessage = nil
            await selectStorage(first.id)
        } catch {
            guard epoch == connectionEpoch else { return }
            clearDevice()
            connectionMessage = Self.connectionExplanation(error)
        }
    }
    func disconnect() async {
        connectionEpoch += 1
        connecting = false
        clearDevice()
        await fileActions.device?.invalidate()
        fileActions.device = nil
        await session?.invalidate()
        if !engineBusy { _ = try? await session?.perform(.dispose) }
    }
    private func clearDevice() {
        connected = false
        connectionToken = UUID()
        deviceName = "Device"
        storages = []
        selectedStorageID = nil
        devicePane.clear()
        pendingDelete = []
        if case .rename(let entry) = naming, case .device = entry.location { naming = nil }
        if case .newFolder(.device) = naming { naming = nil }
    }
    func selectStorage(_ id: UInt32) async {
        guard connected, storages.contains(where: { $0.id == id }), !engineBusy else { return }
        devicePane.clear()
        selectedStorageID = id
        await devicePane.navigate(to: .device(storageID: id, path: "/"))
    }
    func setEngineBusy(_ busy: Bool) async {
        engineBusy = busy
        if !busy && pendingReconnect {
            pendingReconnect = false
            await connect()
        }
    }
    func usbChanged(attached: Bool) {
        if engineBusy {
            pendingReconnect = true
            if !attached {
                clearDevice()
                Task { await fileActions.device?.invalidate() }
            }
            return
        }
        Task {
            if !attached { await disconnect() }
            await connect()
        }
    }
    static func connectionExplanation(_ error: Error) -> String {
        guard let error = error as? DeviceError else { return error.localizedDescription }
        switch error.code {
        case "ErrorMtpDetectFailed": return "No device found. Connect a USB cable and choose File Transfer on the device."
        case "ErrorMultipleDevice": return "The engine supports one device at a time. Disconnect other MTP devices, then retry."
        case "ErrorAllowStorageAccess", "ErrorDeviceLocked", "ErrorFilePermission": return "Unlock your device and allow file access, then retry."
        case "ErrorDeviceSetup": return "This device could not start an MTP session. Check File Transfer mode and retry."
        default: return error.message
        }
    }
    var canActOnPane: Bool { !engineBusy && !transfers.busy && (activePaneKind == .local || connected) }
    func copySelection() {
        guard canTransfer else { return }
        let destination = activePaneKind == .local ? devicePane.location : localPane.location
        let items = activePane.selectedEntries.map { TransferItem(source: $0, destination: destination, device: fileActions.device) }
        transfers.enqueue(items)
    }
    func requestNewFolder() {
        guard canActOnPane else { return }
        naming = .newFolder(activePane.location)
        nameInput = "untitled folder"
    }
    func requestRename() {
        guard canActOnPane, let entry = activePane.selectedEntries.only else { return }
        if let beginRename = activePane.beginRename { beginRename(); return }
        naming = .rename(entry)
        nameInput = entry.name
    }
    func commitName() {
        guard let operation = naming else { return }
        let pane = activePane
        let name = nameInput
        naming = nil
        runMutation(pane: pane) {
            switch operation {
            case .newFolder(let location): try await self.fileActions.makeDirectory(at: location, name: name)
            case .rename(let entry): try await self.fileActions.rename(entry, to: name)
            }
        }
    }
    func requestDelete() {
        guard canActOnPane, !activePane.selection.isEmpty else { return }
        let entries = activePane.selectedEntries
        if activePaneKind == .device { pendingDelete = entries }
        else { runMutation(pane: localPane) { try await self.fileActions.delete(entries, confirmed: false) } }
    }
    func confirmDelete() {
        let entries = pendingDelete
        pendingDelete = []
        guard connected else { return }
        runMutation(pane: devicePane) { try await self.fileActions.delete(entries, confirmed: true) }
    }
    func runMutation(pane: PaneModel, action: @escaping @MainActor () async throws -> Void) {
        guard !engineBusy else { return }
        engineBusy = true
        Task {
            do { try await action() }
            catch { alert = error.localizedDescription }
            if pane.kind == .local || connected { await pane.refresh() }
            await setEngineBusy(false)
        }
    }
}

enum NamingOperation {
    case newFolder(EntryLocation), rename(FileEntry)
    var title: String { if case .newFolder = self { "New Folder" } else { "Rename" } }
}
extension Array {
    var only: Element? { count == 1 ? first : nil }
}
