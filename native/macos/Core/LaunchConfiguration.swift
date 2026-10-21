import Foundation

enum LaunchAppearance: String, Sendable { case light, dark }

struct LaunchConfiguration: Sendable {
    static let current = LaunchConfiguration(environment: ProcessInfo.processInfo.environment)
    let isUITesting: Bool
    let directory: URL?
    let appearance: LaunchAppearance?
    let narrow: Bool

    init(environment: [String: String]) {
        isUITesting = environment["OPENMTP_UI_TESTING"] == "1"
        directory = isUITesting ? environment["OPENMTP_DIRECTORY"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) } : nil
        appearance = isUITesting ? environment["OPENMTP_APPEARANCE"].flatMap(LaunchAppearance.init(rawValue:)) : nil
        narrow = isUITesting && environment["OPENMTP_NARROW"] == "1"
    }
}

/// Diagnostic output exists only in an explicitly configured debug UI-test launch.
@MainActor enum NativeUITestDiagnostics {
    static var enabled: Bool {
        #if DEBUG
        LaunchConfiguration.current.isUITesting && ProcessInfo.processInfo.environment["OPENMTP_UI_DIAGNOSTICS"] != nil
        #else
        false
        #endif
    }
    static func record(_ message: @autoclosure () -> String) {
        #if DEBUG
        guard enabled, let path = ProcessInfo.processInfo.environment["OPENMTP_UI_DIAGNOSTICS"] else { return }
        let data = Data(("\(ProcessInfo.processInfo.systemUptime) \(message())\n").utf8)
        if !FileManager.default.fileExists(atPath: path) { _ = FileManager.default.createFile(atPath: path, contents: nil) }
        guard let file = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) else { return }
        defer { try? file.close() }
        _ = try? file.seekToEnd()
        try? file.write(contentsOf: data)
        #endif
    }
}
