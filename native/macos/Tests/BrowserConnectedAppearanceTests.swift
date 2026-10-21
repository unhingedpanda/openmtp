import AppKit
import SwiftUI
import XCTest

final class BrowserConnectedAppearanceTests: XCTestCase {
    @MainActor func testLongStorageNameKeepsDevicePathUsableInBothAppearances() async throws {
        _ = NSApplication.shared
        let model = AppModel(monitorUSB: false)
        model.connected = true
        model.deviceName = "Android device"
        model.selectedStorageID = 7
        model.storages = [DeviceStorage(id: 7, name: "Internal shared storage with a long device-provided name")]
        model.activePaneKind = .device
        let entries = ["DCIM", "Documents", "Downloads", "Music", "Pictures", "Videos"].map {
            FileEntry(location: .device(storageID: 7, path: "/" + $0), name: $0, isDirectory: true, byteCount: 0, modifiedAt: nil)
        }
        model.devicePane.loader = { _ in entries }
        await model.devicePane.navigate(to: .device(storageID: 7, path: "/"))
        model.devicePane.viewMode = .grid
        model.devicePane.setSelection([entries[0].id])
        let host = NSHostingView(rootView: BrowserPane(pane: model.devicePane, model: model).preferredColorScheme(.light))
        host.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 600), styleMask: .titled, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
            window.appearance = NSAppearance(named: name == "dark" ? .darkAqua : .aqua)
            host.rootView = BrowserPane(pane: model.devicePane, model: model).preferredColorScheme(scheme)
            try await Task.sleep(for: .milliseconds(200))
            host.layoutSubtreeIfNeeded()
            guard let path = findPath(host) else { return XCTFail("The device path was not created") }
            XCTAssertGreaterThanOrEqual(path.bounds.width, 100, "A long storage name must leave the path usable")
            let rect = path.convert(path.bounds, to: host)
            XCTAssertGreaterThanOrEqual(rect.minX, 0)
            XCTAssertLessThanOrEqual(rect.maxX, host.bounds.width)
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return XCTFail("Could not capture the connected browser") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { return XCTFail("Could not encode the connected browser") }
            let capture = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            capture.name = "Native-connected-\(name)-400x600"
            capture.lifetime = .keepAlways
            add(capture)
        }
    }
    @MainActor private func findPath(_ view: NSView) -> NSPathControl? {
        if let path = view as? NSPathControl { return path }
        for child in view.subviews { if let path = findPath(child) { return path } }
        return nil
    }
}
