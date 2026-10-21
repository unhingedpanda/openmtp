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
    @MainActor func testDevicePathKeepsDeviceIdentityAndDoesNotExportALocalURL() {
        _ = NSApplication.shared
        let pane = PaneModel(kind: .device, location: .device(storageID: 7, path: "/Documents/Inbox")) { _ in [] }
        let host = NSHostingView(rootView: BrowserPathBar(pane: pane).disabled(true))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 80), styleMask: .titled, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        guard let control = findPath(host), let item = control.pathItems.last else { return XCTFail("The device path was not created") }
        XCTAssertEqual(control.pathItems.map(\.title), ["Device", "Documents", "Inbox"])
        XCTAssertEqual(item.url?.path, "/Documents/Inbox")
        XCTAssertFalse(control.isEnabled)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        XCTAssertEqual(control.delegate?.pathControl?(control, shouldDrag: item, with: pasteboard), false)
    }
    @MainActor private func findPath(_ view: NSView) -> NSPathControl? {
        if let control = view as? NSPathControl { return control }
        for child in view.subviews { if let control = findPath(child) { return control } }
        return nil
    }
    @MainActor private func findTable(_ view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for child in view.subviews { if let table = findTable(child) { return table } }
        return nil
    }
}
