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
        defer { app.terminate() }
        guard app.windows.firstMatch.waitForExistence(timeout: 20) else { return XCTFail("The native window did not appear") }
        let table = app.tables["local-file-list"]
        guard table.waitForExistence(timeout: 20) else { return XCTFail("The native file table did not appear") }
        XCTAssertTrue(app.staticTexts["connection-title"].exists)
        table.cells.firstMatch.click()
        app.typeKey("a", modifierFlags: .command)
        let status = app.staticTexts["local-selection-status"]
        XCTAssertTrue(NSPredicate(format: "value == %@ OR label == %@", "3 selected", "3 selected").evaluate(with: status))
        XCTAssertFalse(app.buttons["Copy to Device"].isEnabled)
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(NSPredicate(format: "value == %@ OR label == %@", "1 selected", "1 selected").evaluate(with: status))
        app.typeKey(.return, modifierFlags: [])
        let editor = app.textFields.firstMatch
        guard editor.waitForExistence(timeout: 2) else { return XCTFail("Rename editor did not open. Status: \(status.value ?? status.label)") }
        editor.typeKey("a", modifierFlags: .command)
        editor.typeText("renamed.txt")
        editor.typeKey(.return, modifierFlags: [])
        let renamed = directory.appendingPathComponent("renamed.txt")
        let renamedExpectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: renamed.path) }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [renamedExpectation], timeout: 3), .completed, "Names: \((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])")
        app.typeKey("n", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3))
        app.sheets.textFields.firstMatch.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText("Created folder")
        app.sheets.buttons["New Folder"].click()
        let folderExpectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: directory.appendingPathComponent("Created folder").path) }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [folderExpectation], timeout: 3), .completed)
        let originalX = table.frame.midX
        app.menuBars.menuBarItems["View"].click()
        app.menuItems["Swap Panes"].click()
        XCTAssertNotEqual(table.frame.midX, originalX)
        table.cells.firstMatch.click()
        app.typeKey("a", modifierFlags: .command)
        XCTAssertTrue(NSPredicate(format: "value == %@ OR label == %@", "4 selected", "4 selected").evaluate(with: status))
        XCTAssertTrue(app.buttons["Copy to Device"].exists)
        app.terminate()
    }
}

final class PaneFocusTests: XCTestCase {
    @MainActor func testDisconnectedPaneFocusCannotDeleteTheSelectedLocalFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("keep.txt")
        try Data("preserved".utf8).write(to: original)
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--directory", directory.path]
        app.launch()
        defer { app.terminate() }
        app.activate()
        let table = app.tables["local-file-list"]
        guard table.waitForExistence(timeout: 20) else { return XCTFail("The native file table did not appear") }
        table.cells.firstMatch.click()
        app.staticTexts["connection-title"].click()
        XCTAssertFalse(app.buttons["New Folder"].isEnabled)
        app.typeKey(.delete, modifierFlags: .command)
        XCTAssertEqual(try Data(contentsOf: original), Data("preserved".utf8))
        XCTAssertFalse(app.sheets.firstMatch.exists)
    }
}
