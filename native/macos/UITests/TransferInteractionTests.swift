import XCTest

final class TransferInteractionTests: XCTestCase {
    @MainActor func testLightDarkAndNarrowAppearanceCaptures() async throws {
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchEnvironment = ["OPENMTP_UI_TESTING": "1", "OPENMTP_DIRECTORY": "/tmp/openmtp-native-fixtures/1000", "OPENMTP_APPEARANCE": appearance, "OPENMTP_NARROW": "1"]
            app.launch()
            defer { app.terminate() }
            app.activate()
            let table = app.tables["local-file-list"]
            guard table.waitForExistence(timeout: 20), table.cells.firstMatch.waitForExistence(timeout: 20) else { return XCTFail("The fixture rows did not appear") }
            let count = app.staticTexts["local-selection-status"]
            let counts = ["1000 items", "1,000 items"]
            // A whole-tree AX lookup can exceed five seconds on the hosted macOS 27 image.
            // Rows establish data readiness before the single footer snapshot assertion.
            let value = count.value
            let text = (value as? String) ?? (value as? NSAttributedString)?.string ?? count.label
            XCTAssertTrue(counts.contains(text), "Unexpected footer text: \(text)")
            let capture = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            capture.name = "Native-\(appearance)-880x640"
            capture.lifetime = .keepAlways
            add(capture)
            app.segmentedControls["local-view-mode"].buttons["Icons"].click()
            XCTAssertTrue(app.collectionViews["local-file-grid"].waitForExistence(timeout: 5))
            let icons = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            icons.name = "Native-\(appearance)-icons-880x640"
            icons.lifetime = .keepAlways
            add(icons)
            app.terminate()
        }
    }
    @MainActor func testFolderIconAppearanceCaptures() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Mac files-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["Documents", "Downloads", "Music", "Pictures", "Projects", "Videos"] {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        for name in ["Readme.txt", "Trip.pdf", "Notes.md"] {
            try Data().write(to: directory.appendingPathComponent(name))
        }
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchEnvironment = ["OPENMTP_UI_TESTING": "1", "OPENMTP_DIRECTORY": directory.path, "OPENMTP_APPEARANCE": appearance]
            app.launch()
            app.activate()
            defer { app.terminate() }
            let table = app.tables["local-file-list"]
            guard table.waitForExistence(timeout: 20), table.cells.firstMatch.waitForExistence(timeout: 20) else { return XCTFail("The sample folders did not appear") }
            app.segmentedControls["local-view-mode"].buttons["Icons"].click()
            XCTAssertTrue(app.collectionViews["local-file-grid"].waitForExistence(timeout: 5))
            let capture = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            capture.name = "Native-\(appearance)-folders"
            capture.lifetime = .keepAlways
            add(capture)
            app.terminate()
        }
    }
    @MainActor func testDisconnectedDeviceCannotStartCopy() async throws {
        let app = XCUIApplication()
        app.launchEnvironment = ["OPENMTP_UI_TESTING": "1", "OPENMTP_DIRECTORY": "/tmp/openmtp-native-fixtures/1000"]
        app.launch()
        defer { app.terminate() }
        app.activate()
        guard app.tables["local-file-list"].waitForExistence(timeout: 20) else { return XCTFail("The native file table did not appear") }
        let status = app.staticTexts["connection-explanation"]
        let disconnected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "No device found", "No device found"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [disconnected], timeout: 10), .completed)
        XCTAssertFalse(app.buttons["Copy to Device"].isEnabled)
        app.terminate()
    }
}
