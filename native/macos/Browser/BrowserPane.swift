import SwiftUI
import AppKit

struct BrowserPane: View {
    @Bindable var pane: PaneModel
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: pane.kind == .local ? "laptopcomputer" : "externaldrive")
                    .font(.title3).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pane.kind == .local ? "This Mac" : model.deviceName).font(.headline)
                    Text(pane.kind == .local ? "Local files" : (model.connected ? (model.engineBusy ? "Busy" : "Connected over USB") : "Not connected"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if pane.kind == .device && model.connected {
                    Picker("Storage", selection: Binding(get: { model.selectedStorageID ?? 0 }, set: { id in Task { await model.selectStorage(id) } })) {
                        ForEach(model.storages) { Text($0.name).tag($0.id) }
                    }.labelsHidden().fixedSize().disabled(model.engineBusy).accessibilityLabel("Device storage")
                }
                if pane.loading { ProgressView().controlSize(.small) }
                Picker("View", selection: $pane.viewMode) {
                    Image(systemName: "list.bullet").tag(BrowserViewMode.list)
                    Image(systemName: "square.grid.2x2").tag(BrowserViewMode.grid)
                }
                .pickerStyle(.segmented).frame(width: 70).labelsHidden()
                .accessibilityLabel(pane.kind == .local ? "Mac view" : "Device view")
            }
            .padding(.horizontal, 18).padding(.vertical, 15)
            if pane.kind == .local || model.connected {
                HStack(spacing: 7) {
                    Button { pane.goUp() } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.plain).help("Enclosing folder")
                    Text(pane.location.path).lineLimit(1).truncationMode(.head)
                        .font(.callout).textSelection(.enabled)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary).padding(.horizontal, 18).padding(.bottom, 12)
            }
            Divider()
            ZStack {
                Color(nsColor: .textBackgroundColor)
                if pane.kind == .device && !model.connected {
                    ConnectionStatusView(model: model)
                } else {
                    if pane.viewMode == .list { FileTableView(pane: pane).disabled(pane.kind == .device && model.engineBusy) }
                    else { FileGridView(pane: pane).disabled(pane.kind == .device && model.engineBusy) }
                    if pane.visibleEntries.isEmpty && !pane.loading {
                        Text("This folder is empty").foregroundStyle(.secondary).allowsHitTesting(false)
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
            HStack {
                Text(pane.selection.isEmpty ? "\(pane.visibleEntries.count) items" : "\(pane.selection.count) selected")
                    .accessibilityIdentifier("\(pane.kind.rawValue)-selection-status")
                Spacer()
                if pane.kind == .device && !model.connected { Text("USB file transfer") }
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onTapGesture { pane.onFocus?() }
        .onChange(of: pane.viewMode) { _, value in
            if pane.kind == .local { model.preferences.localView = value }
            else { model.preferences.deviceView = value }
        }
    }
}

struct BrowserSplitView: NSViewRepresentable {
    let model: AppModel
    func makeNSView(context: Context) -> NSSplitView {
        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.autosaveName = "OpenMTPNativeBrowserSplit"
        for _ in 0..<2 {
            let host = NSHostingView(rootView: BrowserPane(pane: model.localPane, model: model))
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
}
