import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor enum FilePresentation {
    static func icon(_ entry: FileEntry) -> NSImage {
        if entry.isDirectory { return NSWorkspace.shared.icon(for: .folder) }
        let ext = (entry.name as NSString).pathExtension
        return NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data)
    }
    static func size(_ entry: FileEntry) -> String {
        entry.isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: entry.byteCount, countStyle: .file)
    }
}

struct FileTableView: NSViewRepresentable {
    let pane: PaneModel
    func makeCoordinator() -> Coordinator { Coordinator(pane: pane) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let table = BrowserTable()
        table.focus = { pane.onFocus?() }
        table.setAccessibilityIdentifier("\(pane.kind.rawValue)-file-list")
        table.style = .inset
        table.rowHeight = 28
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        for (id, title, width) in [("name", "Name", 300.0), ("size", "Size", 85.0), ("modified", "Modified", 120.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = width
            column.minWidth = id == "name" ? 150 : 65
            column.sortDescriptorPrototype = NSSortDescriptor(key: id, ascending: true)
            table.addTableColumn(column)
        }
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.target = context.coordinator
        table.doubleAction = #selector(Coordinator.openRow(_:))
        context.coordinator.table = table
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.pane = pane
        guard let table = scroll.documentView as? NSTableView else { return }
        coordinator.updating = true
        if coordinator.revision != pane.contentRevision {
            coordinator.revision = pane.contentRevision
            coordinator.rows = pane.visibleEntries
            table.reloadData()
        }
        let selected = IndexSet(coordinator.rows.indices.filter { pane.selection.contains(coordinator.rows[$0].id) })
        if table.selectedRowIndexes != selected { table.selectRowIndexes(selected, byExtendingSelection: false) }
        coordinator.updating = false
    }

    @MainActor final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var pane: PaneModel
        var rows: [FileEntry] = []
        var revision = -1
        var updating = false
        weak var table: NSTableView?
        init(pane: PaneModel) { self.pane = pane }
        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard rows.indices.contains(row), let column = tableColumn else { return nil }
            let entry = rows[row]
            let id = column.identifier
            if let cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
                fill(cell, entry: entry, column: id.rawValue)
                return cell
            }
            let cell = NSTableCellView()
            cell.identifier = id
            let label = NSTextField(labelWithString: "")
            label.font = .systemFont(ofSize: 13)
            label.lineBreakMode = .byTruncatingMiddle
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            if id.rawValue == "name" {
                let image = NSImageView()
                image.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(image); cell.imageView = image
                NSLayoutConstraint.activate([
                    image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                    image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    image.widthAnchor.constraint(equalToConstant: 18), image.heightAnchor.constraint(equalToConstant: 18),
                    label.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 8)
                ])
            } else {
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3).isActive = true
                label.textColor = .secondaryLabelColor
                if id.rawValue == "size" { label.alignment = .right }
            }
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            fill(cell, entry: entry, column: id.rawValue)
            return cell
        }
        private func fill(_ cell: NSTableCellView, entry: FileEntry, column: String) {
            cell.toolTip = entry.name
            switch column {
            case "name": cell.textField?.stringValue = entry.name; cell.imageView?.image = FilePresentation.icon(entry)
            case "size": cell.textField?.stringValue = FilePresentation.size(entry)
            default: cell.textField?.stringValue = entry.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? "—"
            }
        }
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !updating, let table else { return }
            pane.setSelection(Set(table.selectedRowIndexes.compactMap { rows.indices.contains($0) ? rows[$0].id : nil }))
        }
        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let descriptor = tableView.sortDescriptors.first else { return }
            pane.sortKey = BrowserSortKey(rawValue: descriptor.key ?? "") ?? .name
            pane.sortAscending = descriptor.ascending
        }
        @objc func openRow(_ sender: NSTableView) {
            guard rows.indices.contains(sender.clickedRow) else { return }
            pane.activate(rows[sender.clickedRow])
        }
    }
}

@MainActor final class BrowserTable: NSTableView {
    var focus: (() -> Void)?
    override func becomeFirstResponder() -> Bool { focus?(); return super.becomeFirstResponder() }
    override func mouseDown(with event: NSEvent) { focus?(); super.mouseDown(with: event) }
}
