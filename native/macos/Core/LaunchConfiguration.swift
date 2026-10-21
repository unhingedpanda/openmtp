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
