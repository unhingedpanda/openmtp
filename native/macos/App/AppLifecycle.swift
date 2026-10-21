import AppKit

@MainActor enum LaunchDiagnostics {
    static func record(_ event: String) {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openmtp-native-launch.log")
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data("\(ProcessInfo.processInfo.processIdentifier) \(ProcessInfo.processInfo.systemUptime) \(event)\n".utf8))
    }
    static func windows() -> String {
        NSApp.windows.map { "\(type(of: $0)) visible=\($0.isVisible) frame=\($0.frame)" }.joined(separator: " | ")
    }
}

@MainActor final class AppLifecycle: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    private static var asking = false
    func applicationWillFinishLaunching(_ notification: Notification) {
        LaunchDiagnostics.record("will_finish delegate=\(String(describing: NSApp.delegate)) windows=\(LaunchDiagnostics.windows())")
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchDiagnostics.record("did_finish windows=\(LaunchDiagnostics.windows())")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            LaunchDiagnostics.record("after_launch windows=\(LaunchDiagnostics.windows())")
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, !model.transfers.canClose else { return .terminateNow }
        Self.askToClose(model: model) { NSApp.terminate(nil) }
        return .terminateCancel
    }
    static func askToClose(model: AppModel, close: @escaping @MainActor () -> Void) {
        guard !asking else { return }
        asking = true
        let alert = NSAlert()
        alert.messageText = "A transfer is still active."
        alert.informativeText = "OpenMTP can close after the current item finishes. A folder finishes as one item."
        alert.addButton(withTitle: "Keep Transferring")
        alert.addButton(withTitle: "Stop After Current Item and Close")
        let response = alert.runModal()
        asking = false
        if response == .alertSecondButtonReturn {
            model.transfers.stopAfterCurrentItem()
            Task { await model.transfers.waitUntilIdle(); close() }
        }
    }
}

@MainActor final class WindowCloseProxy: NSObject, NSWindowDelegate {
    // Objective-C queries and forwarding can run outside Swift actor isolation.
    nonisolated(unsafe) weak var original: (any NSWindowDelegate)?
    weak var model: AppModel?
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let model, !model.transfers.canClose {
            AppLifecycle.askToClose(model: model) { sender.performClose(nil) }
            return false
        }
        return original?.windowShouldClose?(sender) ?? true
    }
    nonisolated override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (original?.responds(to: selector) ?? false)
    }
    nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
        if original?.responds(to: selector) == true { return original }
        return super.forwardingTarget(for: selector)
    }
}
