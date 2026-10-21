import Foundation
import CoreGraphics
import AppKit

if CommandLine.arguments[1] == "--launch" {
    let application = URL(fileURLWithPath: CommandLine.arguments[2])
    let pidFile = CommandLine.arguments[3]
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    configuration.activates = true
    configuration.arguments = Array(CommandLine.arguments.dropFirst(4))
    NSWorkspace.shared.openApplication(at: application, configuration: configuration) { app, error in
        guard let app else {
            FileHandle.standardError.write(Data((error?.localizedDescription ?? "Launch failed").utf8))
            exit(1)
        }
        do { try String(app.processIdentifier).write(toFile: pidFile, atomically: true, encoding: .utf8) }
        catch { exit(1) }
        exit(0)
    }
    RunLoop.main.run()
    exit(1)
}

let pid = Int32(CommandLine.arguments[1])!
let deadline = Date().addingTimeInterval(10)
while Date() < deadline {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    if windows.contains(where: { window in
        guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
              (window[kCGWindowLayer as String] as? Int) == 0,
              let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double else { return false }
        return width >= 500 && height >= 400
    }) { print("visible"); exit(0) }
    usleep(5_000)
}
let app = NSRunningApplication(processIdentifier: pid)
let diagnostics: [String: Any] = [
    "pid": pid,
    "screen_count": NSScreen.screens.count,
    "application_found": app != nil,
    "activation_policy": app?.activationPolicy.rawValue ?? -1,
    "finished_launching": app?.isFinishedLaunching ?? false,
    "terminated": app?.isTerminated ?? true,
    "active": app?.isActive ?? false,
    "hidden": app?.isHidden ?? false,
    "bundle": app?.bundleURL?.path ?? "unknown"
]
if let data = try? JSONSerialization.data(withJSONObject: diagnostics, options: [.sortedKeys]), let line = String(data: data, encoding: .utf8) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}
exit(1)
