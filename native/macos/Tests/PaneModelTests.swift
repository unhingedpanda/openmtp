import XCTest
import Foundation

final class PaneModelTests: XCTestCase {
    @MainActor func testFolderNavigationClearsPreviousSelection() async throws {
        let pane = PaneModel(kind: .local, location: .local(URL(fileURLWithPath: "/"))) { location in
            [FileEntry(location: location, name: "item", isDirectory: false, byteCount: 0, modifiedAt: nil)]
        }
        await pane.navigate(to: .local(URL(fileURLWithPath: "/first")))
        pane.setSelection(Set(pane.entries.map(\.id)))
        await pane.navigate(to: .local(URL(fileURLWithPath: "/second")))
        XCTAssertTrue(pane.selection.isEmpty)
        XCTAssertEqual(pane.location.path, "/second")
    }

    @MainActor func testRangeSelectionUsesVisibleSortOrder() async {
        let rows = ["z.txt", "a.txt", ".hidden"].map {
            FileEntry(location: .local(URL(fileURLWithPath: "/" + $0)), name: $0, isDirectory: false, byteCount: 1, modifiedAt: nil)
        }
        let pane = PaneModel(kind: .local, location: .local(URL(fileURLWithPath: "/"))) { _ in rows }
        await pane.refresh()
        XCTAssertEqual(pane.visibleEntries.map(\.name), ["a.txt", "z.txt"])
        pane.setSelection(Set(pane.visibleEntries.map(\.id)))
        XCTAssertEqual(pane.selectedEntries.map(\.name), ["a.txt", "z.txt"])
    }

    @MainActor func testPermissionFailureRetainsLastValidLocation() async {
        let pane = PaneModel(kind: .local, location: .local(URL(fileURLWithPath: "/valid"))) { _ in
            throw CocoaError(.fileReadNoPermission)
        }
        await pane.navigate(to: .local(URL(fileURLWithPath: "/denied")))
        XCTAssertEqual(pane.location.path, "/valid")
        XCTAssertNotNil(pane.error)
    }

    @MainActor func testPreferencesRestorePaneOrderAndViewMode() async {
        let suite = "OpenMTPTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = BrowserPreferences(defaults: defaults)
        first.localOnLeft = false
        first.localView = .grid
        first.localSortKey = .size
        first.localSortAscending = false
        let restored = BrowserPreferences(defaults: defaults)
        XCTAssertFalse(restored.localOnLeft)
        XCTAssertEqual(restored.localView, .grid)
        XCTAssertEqual(restored.localSortKey, .size)
        XCTAssertFalse(restored.localSortAscending)
    }
}
