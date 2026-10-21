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
