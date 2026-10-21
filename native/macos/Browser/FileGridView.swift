import SwiftUI
import AppKit

struct FileGridView: NSViewRepresentable {
    let pane: PaneModel
    func makeCoordinator() -> Coordinator { Coordinator(pane: pane) }
    func makeNSView(context: Context) -> NSScrollView {
        let collection = BrowserCollection()
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 110, height: 104)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 10
        layout.sectionInset = NSEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        collection.collectionViewLayout = layout
        collection.backgroundColors = [.textBackgroundColor]
        collection.isSelectable = true
        collection.allowsMultipleSelection = true
        collection.focus = { context.coordinator.pane.onFocus?() }
        collection.renameSelection = { context.coordinator.pane.onRenameRequested?() }
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
    @MainActor final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        var pane: PaneModel
        var rows: [FileEntry] = []
        var revision = -1
        var updating = false
        weak var collection: NSCollectionView?
        init(pane: PaneModel) { self.pane = pane }
        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { rows.count }
        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("file"), for: indexPath) as! FileGridItem
            let entry = rows[indexPath.item]
            item.imageView?.image = FilePresentation.icon(entry)
            item.textField?.stringValue = entry.name
            item.view.toolTip = entry.name
            item.activate = { [weak self] in self?.pane.activate(entry) }
            return item
        }
        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) { sync(collectionView) }
        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) { sync(collectionView) }
        func menu() -> NSMenu {
            pane.onFocus?()
            let menu = NSMenu()
            for (title, selector) in [("Rename", #selector(renameSelected)), ("New Folder", #selector(newFolder)), (pane.kind == .local ? "Move to Trash" : "Delete from Device…", #selector(deleteSelected))] {
                let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }
            return menu
        }
        @objc private func renameSelected() { pane.onRenameRequested?() }
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
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 7
        let image = NSImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingMiddle
        container.addSubview(image); container.addSubview(label)
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: container.topAnchor, constant: 9),
            image.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            image.widthAnchor.constraint(equalToConstant: 46), image.heightAnchor.constraint(equalToConstant: 46),
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
        view.layer?.backgroundColor = (isSelected ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18) : .clear).cgColor
    }
}
