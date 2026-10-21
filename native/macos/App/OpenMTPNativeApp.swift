import SwiftUI
import AppKit

@main struct OpenMTPNativeApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup("OpenMTP Native") {
            MainBrowserView(model: model)
                .frame(minWidth: 880, minHeight: 640)
                .task { await model.start() }
        }
        .defaultSize(width: 1100, height: 740)
        .commands { AppCommands(model: model) }
        Settings { SettingsView(preferences: model.preferences) }
    }
}

struct MainBrowserView: View {
    @Bindable var model: AppModel
    var body: some View {
        BrowserSplitView(model: model)
            .background(WindowConfiguration())
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button { model.activePane.goUp() } label: { Label("Enclosing folder", systemImage: "arrow.up") }
                        .help("Enclosing folder (⌘↑)")
                    Button { Task { await model.activePane.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                        .help("Refresh (⌘R)")
                }
                ToolbarItem(placement: .principal) { Text("OpenMTP").font(.headline) }
                ToolbarItem(placement: .primaryAction) {
                    Button { model.requestNewFolder() } label: { Label("New Folder", systemImage: "folder.badge.plus") }
                        .disabled(!model.canActOnPane)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { model.transferAction?() } label: {
                        Label(model.activePaneKind == .local ? "Copy to Device" : "Copy to Mac", systemImage: model.activePaneKind == .local ? "arrow.right" : "arrow.left")
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
    func makeNSView(context: Context) -> NSView { WindowMarker() }
    func updateNSView(_ view: NSView, context: Context) {}
    private class WindowMarker: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.setFrameAutosaveName("OpenMTPNativeMainWindow")
            window?.toolbarStyle = .unified
        }
    }
}
