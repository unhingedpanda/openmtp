import Foundation
import CoreGraphics
import AppKit

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
