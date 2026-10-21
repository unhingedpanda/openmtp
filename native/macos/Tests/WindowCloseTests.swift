import AppKit
import XCTest

@MainActor private final class OriginalWindowDelegate: NSObject, NSWindowDelegate {
    var closeCalls = 0
    var resizeCalls = 0
    func windowShouldClose(_ sender: NSWindow) -> Bool { closeCalls += 1; return false }
    func windowDidResize(_ notification: Notification) { resizeCalls += 1 }
}
final class WindowCloseTests: XCTestCase {
    @MainActor func testCloseProtectionPreservesOriginalWindowDelegate() async {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: .titled, backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        let original = OriginalWindowDelegate()
        let proxy = WindowCloseProxy()
        proxy.original = original
        let model = AppModel(monitorUSB: false)
        proxy.model = model
        XCTAssertFalse(proxy.windowShouldClose(window))
        XCTAssertEqual(original.closeCalls, 1)
        XCTAssertTrue(proxy.responds(to: #selector(NSWindowDelegate.windowDidResize(_:))))
        (proxy as NSWindowDelegate).windowDidResize?(Notification(name: NSWindow.didResizeNotification, object: window))
        XCTAssertEqual(original.resizeCalls, 1)
    }
}
