import SwiftUI
import AppKit

@main struct OpenMTPNativeApp: App {
    @State private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle
    var body: some Scene {
        WindowGroup("OpenMTP Native") {
            MainBrowserView(model: model)
                .preferredColorScheme(launchColorScheme)
                .frame(minWidth: 880, minHeight: 640)
                .task { lifecycle.model = model; await model.start() }
        }
        .defaultLaunchBehavior(.presented)
        .defaultSize(width: 1100, height: 740)
        .commands { AppCommands(model: model) }
        Settings { SettingsView(preferences: model.preferences) }
    }
    private var launchColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--appearance"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1] == "dark" ? .dark : .light
    }
}

struct MainBrowserView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            BrowserSplitView(model: model)
            if !model.transfers.records.isEmpty { TransferTray(queue: model.transfers) }
        }
            .background(WindowConfiguration(model: model))
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button { model.activePane.goUp() } label: { Label("Enclosing folder", systemImage: "arrow.up") }
                        .help("Enclosing folder (⌘↑)")
                    Button { Task { await model.activePane.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                        .help("Refresh (⌘R)")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button { model.requestNewFolder() } label: { Label("New Folder", systemImage: "folder.badge.plus") }
                        .disabled(!model.canActOnPane)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { model.transferAction?() } label: {
                        Label(model.activePaneKind == .local ? "Copy to Device" : "Copy to Mac", systemImage: model.transferSymbol)
                    }
                    .disabled(!model.canTransfer)
                    .help("Copy selected items to the other pane")
                    Menu {
                        Button("Swap panes", systemImage: "arrow.left.arrow.right") { model.preferences.localOnLeft.toggle() }
                        Toggle("Show hidden files", isOn: Binding(get: { model.activePane.showHidden }, set: { model.activePane.showHidden = $0 }))
                        Divider()
                        SettingsLink()
                    } label: { Label("More", systemImage: "ellipsis") }
                }
            }
            .sheet(item: Binding(get: { model.transfers.collisions.pending }, set: { if $0 == nil { model.transfers.collisions.decide(.stop) } })) { item in
                VStack(alignment: .leading, spacing: 18) {
                    Text("An item named “\(item.source.name)” already exists.").font(.headline)
                    Text(item.source.isDirectory && item.destination.isDevice ? "Replace matching files inside this folder? Other items remain." : "Replace the existing item?")
                    if item.destination.isDevice { Text("A failed device transfer may leave a partial copy.").foregroundStyle(.secondary) }
                    HStack {
                        Button("Stop", role: .cancel) { model.transfers.collisions.decide(.stop) }
                        Spacer()
                        Button("Skip") { model.transfers.collisions.decide(.skip) }
                        Button("Replace", role: .destructive) { model.transfers.collisions.decide(.replace) }
                    }
                }.padding(24).frame(width: 430).interactiveDismissDisabled()
            }
            .sheet(isPresented: Binding(get: { model.naming != nil }, set: { if !$0 { model.naming = nil } })) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(model.naming?.title ?? "Name").font(.headline)
                    TextField("Name", text: $model.nameInput).textFieldStyle(.roundedBorder)
                        .onSubmit { model.commitName() }
                    HStack {
                        Spacer()
                        Button("Cancel", role: .cancel) { model.naming = nil }.keyboardShortcut(.cancelAction)
                        Button(model.naming?.title ?? "Save") { model.commitName() }.keyboardShortcut(.defaultAction)
                    }
                }.padding(24).frame(width: 360)
            }
            .confirmationDialog("Delete \(model.pendingDelete.count) items permanently?", isPresented: Binding(get: { !model.pendingDelete.isEmpty }, set: { if !$0 { model.pendingDelete = [] } })) {
                Button("Delete from Device", role: .destructive) { model.confirmDelete() }
                Button("Cancel", role: .cancel) { model.pendingDelete = [] }
            } message: { Text("Device deletion cannot be undone.") }
            .alert("OpenMTP", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
                Button("OK") { model.alert = nil }
            } message: { Text(model.alert ?? "") }
    }
}

struct WindowConfiguration: NSViewRepresentable {
    let model: AppModel
    func makeNSView(context: Context) -> NSView { let marker = WindowMarker(); marker.model = model; return marker }
    func updateNSView(_ view: NSView, context: Context) {}
    private class WindowMarker: NSView {
        weak var model: AppModel?
        private let closeProxy = WindowCloseProxy()
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let arguments = ProcessInfo.processInfo.arguments
            let testing = arguments.contains("--ui-testing")
            window?.setFrameAutosaveName(testing ? "OpenMTPNativeTestWindow" : "OpenMTPNativeMainWindow")
            if arguments.contains("--narrow"), let window {
                DispatchQueue.main.async { [weak window] in
                    window?.setContentSize(NSSize(width: 880, height: 640))
                    window?.center()
                }
            }
            window?.toolbarStyle = .unified
            closeProxy.model = model
            if let window, window.delegate !== closeProxy {
                closeProxy.original = window.delegate
                window.delegate = closeProxy
            }
        }
    }
}
