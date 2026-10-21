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
        .defaultSize(width: 1180, height: 760)
        .commands { AppCommands(model: model) }
        Settings { SettingsView(preferences: model.preferences) }
    }
    private var launchColorScheme: ColorScheme? {
        guard let appearance = LaunchConfiguration.current.appearance else { return nil }
        return appearance == .dark ? .dark : .light
    }
}

struct MainBrowserView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            BrowserSplitView(model: model)
            if !model.transfers.records.isEmpty { TransferTray(queue: model.transfers) }
        }
            .padding(.horizontal, 6)
            .background(Color(nsColor: .windowBackgroundColor))
            .background(WindowConfiguration(model: model))
            .navigationTitle("OpenMTP")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Menu {
                        ForEach(MacPlace.allCases) { place in
                            Button(place.title, systemImage: place.symbol) {
                                model.localPane.onFocus?()
                                Task { await model.localPane.navigate(to: .local(place.url)) }
                            }
                        }
                    } label: { Label("Locations", systemImage: "folder") }
                    .labelStyle(.titleAndIcon)
                    .help("Go to a folder on this Mac")
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
                    .labelStyle(.titleAndIcon)
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
            let configuration = LaunchConfiguration.current
            let testing = configuration.isUITesting
            window?.setFrameAutosaveName(testing ? "OpenMTPNativeTestWindow" : "OpenMTPNativeMainWindow")
            if configuration.narrow, let window {
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

enum MacPlace: String, CaseIterable, Identifiable {
    case home, desktop, documents, downloads, pictures, music, movies
    var id: Self { self }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .home: "house"
        case .desktop: "desktopcomputer"
        case .documents: "doc"
        case .downloads: "arrow.down.circle"
        case .pictures: "photo"
        case .music: "music.note"
        case .movies: "film"
        }
    }
    var url: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return self == .home ? home : home.appendingPathComponent(title, isDirectory: true)
    }
}
