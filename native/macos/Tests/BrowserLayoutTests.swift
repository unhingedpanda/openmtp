import AppKit
import SwiftUI
import XCTest

final class BrowserLayoutTests: XCTestCase {
    @MainActor func testMetadataColumnsRemainVisibleAtMinimumPaneWidth() {
        _ = NSApplication.shared
        let pane = PaneModel(kind: .local, location: .local(FileManager.default.temporaryDirectory)) { _ in [] }
        let host = NSHostingView(rootView: FileTableView(pane: pane))
        host.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 500), styleMask: .titled, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        for width in [440.0, 550.0, 440.0] {
            window.setContentSize(NSSize(width: width, height: 500))
            host.layoutSubtreeIfNeeded()
            guard let table = findTable(host), let scroll = table.enclosingScrollView else { return XCTFail("The file table was not created") }
            XCTAssertEqual(table.tableColumns.count, 3)
            XCTAssertLessThanOrEqual(table.rect(ofColumn: 2).maxX, scroll.contentView.bounds.width + 1, "Modified must fit at pane width \(width)")
            XCTAssertGreaterThanOrEqual(table.tableColumns[0].width, 150)
        }
    }
    @MainActor private func findTable(_ view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for child in view.subviews { if let table = findTable(child) { return table } }
        return nil
    }
}
