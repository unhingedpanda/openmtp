import XCTest

final class BrowserInteractionTests: XCTestCase {
    @MainActor func testKeyboardActionUsesTheFocusedPane() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["one.txt", "two.txt", "three.txt"] {
            try Data(name.utf8).write(to: directory.appendingPathComponent(name))
        }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--directory", directory.path]
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        let table = app.tables["local-file-list"]
        XCTAssertTrue(table.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["connection-title"].exists)
        table.cells.firstMatch.click()
        app.typeKey("a", modifierFlags: .command)
        let status = app.staticTexts["local-selection-status"]
        XCTAssertTrue(NSPredicate(format: "value == %@ OR label == %@", "3 selected", "3 selected").evaluate(with: status))
        XCTAssertFalse(app.buttons["Copy to Device"].isEnabled)
        let originalX = table.frame.midX
        app.menuBars.menuBarItems["View"].click()
        app.menuItems["Swap Panes"].click()
        XCTAssertNotEqual(table.frame.midX, originalX)
        table.cells.firstMatch.click()
        app.typeKey("a", modifierFlags: .command)
        XCTAssertTrue(NSPredicate(format: "value == %@ OR label == %@", "3 selected", "3 selected").evaluate(with: status))
        XCTAssertTrue(app.buttons["Copy to Device"].exists)
        app.terminate()
    }
}
