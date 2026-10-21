import XCTest

final class TransferInteractionTests: XCTestCase {
    @MainActor func testDisconnectedDeviceCannotStartCopy() async {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--directory", "/tmp"]
        app.launch()
        app.activate()
        XCTAssertTrue(app.tables["local-file-list"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["connection-title"].exists)
        XCTAssertFalse(app.buttons["Copy to Device"].isEnabled)
        app.terminate()
    }
}
