import AppKit
import XCTest

final class NativeRenameTests: XCTestCase {
    @MainActor func testEscapeAndStaleEditsCannotRenameFiles() async {
        _ = NSApplication.shared
        let entry = transferFixture().source
        let pane = PaneModel(kind: .local, location: entry.location) { _ in [entry] }
        await pane.refresh()
        var renamed = false
        pane.onRename = { _, _ in renamed = true }
        let table = FileTableView.Coordinator(pane: pane)
        let grid = FileGridView.Coordinator(pane: pane)
        let field = NSTextField(string: "changed.txt")
        table.editingEntry = entry
        table.editingRevision = pane.contentRevision
        table.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field, userInfo: ["NSTextMovement": NSTextMovement.cancel.rawValue]))
        XCTAssertFalse(renamed)
        XCTAssertEqual(field.stringValue, entry.name)
        field.stringValue = "changed.txt"
        grid.editingEntry = entry
        grid.editingRevision = pane.contentRevision
        pane.clear()
        grid.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
        XCTAssertFalse(renamed)
        XCTAssertEqual(field.stringValue, entry.name)
    }
}
