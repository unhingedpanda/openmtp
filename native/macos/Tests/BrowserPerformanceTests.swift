import AppKit
import SwiftUI
import XCTest

final class BrowserPerformanceTests: XCTestCase {
    @MainActor func testTenThousandEntryNativeTableActions() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OpenMTP-10000-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for index in 0..<10000 { try Data("fixture".utf8).write(to: directory.appendingPathComponent(String(format: "file-%05d.txt", index))) }
        let pane = PaneModel(kind: .local, location: .local(directory)) { location in
            guard case .local(let url) = location else { throw DeviceError.stale }
            return try await LocalFileService().entries(at: url)
        }
        await pane.refresh()
        XCTAssertEqual(pane.visibleEntries.count, 10000)
        let host = NSHostingView(rootView: FileTableView(pane: pane))
        host.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: .titled, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        host.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        for _ in 0..<5 { host.layoutSubtreeIfNeeded(); await Task.yield() }
        guard let table = findTable(host) else { return XCTFail("Native table was not created") }
        window.makeFirstResponder(table)
        var samples: [Double] = []
        for action in 0..<100 {
            let started = ContinuousClock.now
            if action.isMultiple(of: 2) { table.selectRowIndexes(IndexSet(integer: action * 31), byExtendingSelection: false) }
            else { table.moveDown(nil) }
            await Task.yield()
            host.layoutSubtreeIfNeeded()
            table.displayIfNeeded()
            let elapsed = started.duration(to: .now).components
            samples.append(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15)
            XCTAssertEqual(pane.selection.count, 1)
        }
        let p95 = samples.sorted()[94]
        let result: [String: Any] = ["entries": 10000, "actions": 100, "p95_ms": p95, "samples_ms": samples,
            "method": "In-process AppKit selection and moveDown keyboard action with layout/display updates. Hidden 800x600 window. Debug test build. Does not measure physical input-to-screen latency."]
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/browser-performance.json")
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: output)
        XCTAssertLessThanOrEqual(p95, 100)
    }
    @MainActor private func findTable(_ view: NSView) -> BrowserTable? {
        if let table = view as? BrowserTable { return table }
        for child in view.subviews { if let table = findTable(child) { return table } }
        return nil
    }
}
