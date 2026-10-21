import Foundation
import CoreGraphics
import AppKit

func firstWindow(pid: Int32) -> [String: Any]? {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.first { window in
        guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
              (window[kCGWindowLayer as String] as? Int) == 0,
              let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double else { return false }
        return width >= 500 && height >= 400
    }
}

if CommandLine.arguments[1] == "--launch" {
    let application = URL(fileURLWithPath: CommandLine.arguments[2])
    let reportFile = CommandLine.arguments[3]
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    configuration.activates = true
    configuration.arguments = Array(CommandLine.arguments.dropFirst(4))
    // Exclude the observer's own process startup from the app launch measurement.
    let started = DispatchTime.now().uptimeNanoseconds
    NSWorkspace.shared.openApplication(at: application, configuration: configuration) { app, error in
        guard let app else {
            FileHandle.standardError.write(Data((error?.localizedDescription ?? "Launch failed").utf8))
            exit(1)
        }
        var report: [String: Any] = ["pid": app.processIdentifier, "first_window_seconds": NSNull()]
        func save() throws {
            try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]).write(to: URL(fileURLWithPath: reportFile), options: .atomic)
        }
        // Preserve ownership before probing so Python can stop this exact instance after a timeout.
        do { try save() }
        catch { exit(1) }
        let deadline = DispatchTime.now().uptimeNanoseconds + 10_000_000_000
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if let window = firstWindow(pid: app.processIdentifier) {
                report["first_window_seconds"] = Double(DispatchTime.now().uptimeNanoseconds - started) / 1e9
                report["window_bounds"] = window[kCGWindowBounds as String]
                break
            }
            usleep(5_000)
        }
        report["active"] = app.isActive
        report["finished_launching"] = app.isFinishedLaunching
        do { try save() }
        catch { exit(1) }
        exit(0)
    }
    RunLoop.main.run()
    exit(1)
}

let pid = Int32(CommandLine.arguments[1])!
let deadline = Date().addingTimeInterval(10)
while Date() < deadline {
    if firstWindow(pid: pid) != nil { print("visible"); exit(0) }
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
