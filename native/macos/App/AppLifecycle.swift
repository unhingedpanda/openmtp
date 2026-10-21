import AppKit

@MainActor final class AppLifecycle: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    private static var asking = false
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
