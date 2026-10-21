import SwiftUI
import AppKit

struct FileGridView: NSViewRepresentable {
    let pane: PaneModel
    func makeCoordinator() -> Coordinator { Coordinator(pane: pane) }
    func makeNSView(context: Context) -> NSScrollView {
        let collection = BrowserCollection()
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = BrowserStyle.gridItem
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        collection.collectionViewLayout = layout
        collection.backgroundColors = [.textBackgroundColor]
        collection.isSelectable = true
        collection.allowsMultipleSelection = true
        collection.registerForDraggedTypes(BrowserPasteboard.types)
        collection.setDraggingSourceOperationMask(.copy, forLocal: true)
        collection.setDraggingSourceOperationMask(.copy, forLocal: false)
        collection.focus = { context.coordinator.pane.onFocus?() }
        collection.renameSelection = { context.coordinator.beginRename() }
        collection.contextMenu = { context.coordinator.menu() }
        collection.setAccessibilityIdentifier("\(pane.kind.rawValue)-file-grid")
        collection.register(FileGridItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("file"))
        collection.dataSource = context.coordinator
        collection.delegate = context.coordinator
        context.coordinator.collection = collection
        let scroll = NSScrollView()
        scroll.documentView = collection
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.pane !== pane { coordinator.revision = -1 }
        coordinator.pane = pane
        pane.beginRename = { [weak coordinator] in coordinator?.beginRename() }
        guard let collection = scroll.documentView as? NSCollectionView else { return }
        collection.setAccessibilityIdentifier("\(pane.kind.rawValue)-file-grid")
        coordinator.updating = true
        if coordinator.revision != pane.contentRevision {
            coordinator.revision = pane.contentRevision
            coordinator.rows = pane.visibleEntries
            collection.reloadData()
        }
        collection.selectionIndexPaths = Set(coordinator.rows.indices.filter { pane.selection.contains(coordinator.rows[$0].id) }.map { IndexPath(item: $0, section: 0) })
        coordinator.updating = false
    }
    @MainActor final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate, NSTextFieldDelegate {
        var pane: PaneModel
        var rows: [FileEntry] = []
        var revision = -1
        var updating = false
        weak var collection: NSCollectionView?
        var editingEntry: FileEntry?
        var editingRevision = -1
        init(pane: PaneModel) { self.pane = pane }
        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { rows.count }
        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("file"), for: indexPath) as! FileGridItem
            let entry = rows[indexPath.item]
            item.imageView?.image = FilePresentation.icon(entry)
            item.textField?.stringValue = entry.name
            item.textField?.delegate = self
            item.view.toolTip = entry.name
            item.activate = { [weak self] in self?.pane.activate(entry) }
            return item
        }
        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) { sync(collectionView) }
        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) { sync(collectionView) }
        func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
            guard rows.indices.contains(indexPath.item) else { return nil }
            let entry = rows[indexPath.item]
            if case .local(let url) = entry.location { return url as NSURL }
            return pane.onExport?(entry)
        }
        func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
            guard BrowserPasteboard.canRead(draggingInfo.draggingPasteboard), pane.onDrop != nil else { return [] }
            dropOperation.pointee = .before
            return .copy
        }
        func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
            let sources = BrowserPasteboard.read(draggingInfo.draggingPasteboard)
            guard !sources.urls.isEmpty || !sources.references.isEmpty else { return false }
            pane.onDrop?(sources.urls, sources.references)
            return true
        }
        func beginRename() {
            guard let collection, collection.selectionIndexPaths.count == 1, let path = collection.selectionIndexPaths.first,
                  rows.indices.contains(path.item), let field = collection.item(at: path)?.textField else { return }
            editingEntry = rows[path.item]
            editingRevision = pane.contentRevision
            field.isEditable = true
            field.isSelectable = true
            collection.window?.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
        }
        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField, let entry = editingEntry else { return }
            editingEntry = nil
            field.isEditable = false
            field.isSelectable = false
            let movement = (notification.userInfo?["NSTextMovement"] as? NSNumber)?.intValue
            guard movement != NSTextMovement.cancel.rawValue, editingRevision == pane.contentRevision else {
                field.stringValue = entry.name
                return
            }
            pane.onRename?(entry, field.stringValue)
        }
        func menu() -> NSMenu {
            pane.onFocus?()
            let menu = NSMenu()
            for (title, selector) in [("Rename", #selector(renameSelected)), (pane.kind == .local ? "Copy to Device" : "Copy to Mac", #selector(copySelected)), ("New Folder", #selector(newFolder)), (pane.kind == .local ? "Move to Trash" : "Delete from Device…", #selector(deleteSelected))] {
                let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }
            return menu
        }
        @objc private func renameSelected() { beginRename() }
        @objc private func copySelected() { pane.onCopy?() }
        @objc private func newFolder() { pane.onNewFolder?() }
        @objc private func deleteSelected() { pane.onDelete?() }
        private func sync(_ collection: NSCollectionView) {
            guard !updating else { return }
            pane.setSelection(Set(collection.selectionIndexPaths.compactMap { rows.indices.contains($0.item) ? rows[$0.item].id : nil }))
        }
    }
}

@MainActor final class BrowserCollection: NSCollectionView {
    var focus: (() -> Void)?
    var renameSelection: (() -> Void)?
    var contextMenu: (() -> NSMenu)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { renameSelection?() } else { super.keyDown(with: event) }
    }
    override func menu(for event: NSEvent) -> NSMenu? { contextMenu?() }
    override func becomeFirstResponder() -> Bool { focus?(); return super.becomeFirstResponder() }
    override func mouseDown(with event: NSEvent) { focus?(); super.mouseDown(with: event) }
}

@MainActor final class FileGridItem: NSCollectionViewItem {
    var activate: (() -> Void)?
    override var isSelected: Bool { didSet { updateSelection() } }
    override func loadView() {
        let container = FileGridSelectionView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        let image = NSImageView()
        image.imageScaling = .scaleProportionallyUpOrDown
        image.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingMiddle
        container.addSubview(image); container.addSubview(label)
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            image.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            image.widthAnchor.constraint(equalToConstant: BrowserStyle.gridIcon), image.heightAnchor.constraint(equalToConstant: BrowserStyle.gridIcon),
            label.topAnchor.constraint(equalTo: image.bottomAnchor, constant: 7),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5)
        ])
        view = container; imageView = image; textField = label
    }
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.clickCount == 2 { activate?() }
    }
    private func updateSelection() {
        (view as? FileGridSelectionView)?.selected = isSelected
    }
}

@MainActor private final class FileGridSelectionView: NSView {
    var selected = false { didSet { needsDisplay = true } }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer?.backgroundColor = (selected ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18) : .clear).cgColor
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
