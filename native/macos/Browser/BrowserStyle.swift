import SwiftUI
import AppKit

/// Shared dimensions for the two file browsers. Colors stay with the system appearance.
enum BrowserStyle {
    static let gutter: CGFloat = 12
    static let canvasRadius: CGFloat = 14
    static let gridItem = NSSize(width: 112, height: 116)
    static let gridIcon: CGFloat = 64
}

struct BrowserPathBar: NSViewRepresentable {
    let pane: PaneModel
    func makeCoordinator() -> Coordinator { Coordinator(pane: pane) }
    func makeNSView(context: Context) -> NSPathControl {
        let control = NSPathControl()
        control.pathStyle = .standard
        control.isEditable = false
        control.delegate = context.coordinator
        control.backgroundColor = .clear
        control.controlSize = .small
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.target = context.coordinator
        control.doubleAction = #selector(Coordinator.navigate(_:))
        control.setAccessibilityLabel(pane.kind == .local ? "Mac folder path" : "Device folder path")
        return control
    }
    func updateNSView(_ control: NSPathControl, context: Context) {
        context.coordinator.pane = pane
        control.isEnabled = context.environment.isEnabled
        guard context.coordinator.shown != pane.location else { return }
        context.coordinator.shown = pane.location
        switch pane.location {
        case .local(let url): control.url = url
        case .device(_, let path):
            control.url = URL(fileURLWithPath: path, isDirectory: true)
            // AppKit creates the immutable component URLs. Replace only their presentation.
            for (index, item) in control.pathItems.enumerated() {
                if index == 0 { item.title = "Device" }
                item.image = NSImage(systemSymbolName: index == 0 ? "externaldrive" : "folder", accessibilityDescription: nil)
            }
        }
        control.toolTip = pane.location.path
    }
    @MainActor final class Coordinator: NSObject, NSPathControlDelegate {
        var shown: EntryLocation?
        var pane: PaneModel
        init(pane: PaneModel) { self.pane = pane }
        func pathControl(_ pathControl: NSPathControl, shouldDrag pathItem: NSPathControlItem, with pasteboard: NSPasteboard) -> Bool {
            pane.kind == .local
        }
        @objc func navigate(_ control: NSPathControl) {
            guard control.isEnabled else { return }
            guard let url = control.clickedPathItem?.url else { return }
            pane.onFocus?()
            let destination: EntryLocation
            switch pane.location {
            case .local: destination = .local(url)
            case .device(let storage, _): destination = .device(storageID: storage, path: url.path)
            }
            Task { await pane.navigate(to: destination) }
        }
    }
}
