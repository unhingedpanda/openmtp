import SwiftUI
import AppKit

struct BrowserPane: View {
    @Bindable var pane: PaneModel
    @Bindable var model: AppModel
    private var available: Bool { pane.kind == .local || model.connected }
    private var active: Bool { model.activePaneKind == pane.kind }
    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 0) {
                navigation
                Divider()
                ZStack {
                    Color(nsColor: .textBackgroundColor)
                    if !available {
                        ConnectionStatusView(model: model)
                    } else {
                        if pane.viewMode == .list { FileTableView(pane: pane).disabled(pane.kind == .device && model.engineBusy) }
                        else { FileGridView(pane: pane).disabled(pane.kind == .device && model.engineBusy) }
                        if pane.visibleEntries.isEmpty && !pane.loading {
                            VStack(spacing: 8) {
                                Image(systemName: "folder").font(.system(size: 36, weight: .light)).foregroundStyle(.secondary)
                                Text("This folder is empty").font(.callout).foregroundStyle(.secondary)
                            }.allowsHitTesting(false)
                        }
                    }
                }
                if let error = pane.error {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error).font(.callout)
                        Spacer()
                        Button("Retry") { Task { await pane.refresh() } }
                    }.padding(12).foregroundStyle(.secondary)
                }
                Divider()
                footer
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(.rect(cornerRadius: BrowserStyle.canvasRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BrowserStyle.canvasRadius)
                    .strokeBorder(active ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.10), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, BrowserStyle.gutter / 2)
        .padding(.bottom, BrowserStyle.gutter)
        .background(Color(nsColor: .windowBackgroundColor))
        .onTapGesture { pane.onFocus?() }
        .onChange(of: pane.viewMode) { _, value in
            if pane.kind == .local { model.preferences.localView = value }
            else { model.preferences.deviceView = value }
        }
    }
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: pane.kind == .local ? "laptopcomputer" : "externaldrive")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(pane.kind == .local || model.connected ? Color.accentColor : Color.secondary)
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.045), in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(pane.kind == .local ? "This Mac" : model.deviceName)
                    .font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(pane.kind == .local ? "Local files" : (model.connected ? (model.engineBusy ? "Busy" : "Connected over USB") : "Not connected"))
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if pane.loading { ProgressView().controlSize(.small) }
            if available {
                Picker("View", selection: $pane.viewMode) {
                    Label("List", systemImage: "list.bullet").labelStyle(.iconOnly).tag(BrowserViewMode.list)
                    Label("Icons", systemImage: "square.grid.2x2").labelStyle(.iconOnly).tag(BrowserViewMode.grid)
                }
                .pickerStyle(.segmented).controlSize(.regular).frame(width: 76).labelsHidden()
                .accessibilityLabel(pane.kind == .local ? "Mac view" : "Device view")
                .accessibilityIdentifier("\(pane.kind.rawValue)-view-mode")
            }
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 14)
        .frame(height: 76)
    }
    private var navigation: some View {
        HStack(spacing: 8) {
            if available {
                Button { pane.onFocus?(); pane.goUp() } label: { Label("Enclosing folder", systemImage: "chevron.up") }
                    .labelStyle(.iconOnly).buttonStyle(.borderless).help("Enclosing folder (⌘↑)")
                    .disabled(pane.kind == .device && model.engineBusy)
                BrowserPathBar(pane: pane).frame(maxWidth: .infinity).frame(height: 24)
                    .disabled(pane.kind == .device && model.engineBusy)
                if pane.kind == .device {
                    Picker("Storage", selection: Binding(get: { model.selectedStorageID ?? 0 }, set: { id in Task { await model.selectStorage(id) } })) {
                        ForEach(model.storages) { Text($0.name).tag($0.id) }
                    }.labelsHidden().lineLimit(1).truncationMode(.middle).frame(width: 140)
                        .disabled(model.engineBusy).accessibilityLabel("Device storage")
                        .help(model.storages.first(where: { $0.id == model.selectedStorageID })?.name ?? "Device storage")
                }
                Button { pane.onFocus?(); Task { await pane.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .labelStyle(.iconOnly).buttonStyle(.borderless).help("Refresh (⌘R)")
                    .disabled(pane.kind == .device && model.engineBusy)
            } else {
                Label("USB file transfer", systemImage: "cable.connector")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 12).frame(height: 40)
        .background(.bar)
    }
    private var footer: some View {
        HStack(spacing: 8) {
            Text(pane.selection.isEmpty ? "\(pane.visibleEntries.count) \(pane.visibleEntries.count == 1 ? "item" : "items")" : "\(pane.selection.count) selected")
                .accessibilityIdentifier("\(pane.kind.rawValue)-selection-status")
            Spacer()
            if !pane.selection.isEmpty {
                Text(pane.kind == .local ? "On this Mac" : "On device")
            }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .padding(.horizontal, 14).frame(height: 30).background(.bar)
    }
}

struct BrowserSplitView: NSViewRepresentable {
    let model: AppModel
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSSplitView {
        let split = BalancedBrowserSplit()
        split.isVertical = true
        split.dividerStyle = .thin
        split.delegate = context.coordinator
        split.autosaveName = LaunchConfiguration.current.isUITesting ? "OpenMTPNativeTestSplitV2" : "OpenMTPNativeBrowserSplitV2"
        for pane in [model.localPane, model.devicePane] {
            let host = NSHostingView(rootView: BrowserPane(pane: pane, model: model))
            host.sizingOptions = []
            split.addArrangedSubview(host)
        }
        return split
    }
    func updateNSView(_ split: NSSplitView, context: Context) {
        let panes = model.preferences.localOnLeft ? [model.localPane, model.devicePane] : [model.devicePane, model.localPane]
        for (index, pane) in panes.enumerated() {
            (split.arrangedSubviews[index] as? NSHostingView<BrowserPane>)?.rootView = BrowserPane(pane: pane, model: model)
        }
    }
    @MainActor final class Coordinator: NSObject, NSSplitViewDelegate {
        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat { 400 }
        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat { splitView.bounds.width - 400 }
        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool { false }
    }
}

@MainActor private final class BalancedBrowserSplit: NSSplitView {
    private var positioned = false
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        if !positioned && bounds.width > 0 {
            positioned = true
            setPosition(bounds.width / 2, ofDividerAt: 0)
        }
    }
}
