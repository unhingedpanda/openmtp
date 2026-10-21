import XCTest

final class TransferInteractionTests: XCTestCase {
    @MainActor func testLightDarkAndNarrowAppearanceCaptures() async {
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-testing", "--directory", "/tmp/openmtp-native-fixtures/1000", "--appearance", appearance, "--narrow"]
            app.launch()
            defer { app.terminate() }
            app.openNativeWindow()
            guard app.tables["local-file-list"].waitForExistence(timeout: 20) else { return XCTFail("The native file table did not appear") }
            let count = app.staticTexts["local-selection-status"]
            let counts = ["1000 items", "1,000 items"]
            let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value IN %@ OR label IN %@", counts, counts), object: count)
            XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 5), .completed)
            let capture = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            capture.name = "Native-\(appearance)-880x640"
            capture.lifetime = .keepAlways
            add(capture)
            app.terminate()
        }
    }
    @MainActor func testDisconnectedDeviceCannotStartCopy() async {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--directory", "/tmp/openmtp-native-fixtures/1000"]
        app.launch()
        defer { app.terminate() }
        app.openNativeWindow()
        guard app.tables["local-file-list"].waitForExistence(timeout: 20) else { return XCTFail("The native file table did not appear") }
        let status = app.staticTexts["connection-explanation"]
        let disconnected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "No device found", "No device found"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [disconnected], timeout: 10), .completed)
        XCTAssertFalse(app.buttons["Copy to Device"].isEnabled)
        app.terminate()
    }
}
