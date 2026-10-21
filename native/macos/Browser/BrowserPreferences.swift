import Foundation
import Observation

@MainActor @Observable final class BrowserPreferences {
    private let defaults: UserDefaults
    var localSortKey: BrowserSortKey { didSet { defaults.set(localSortKey.rawValue, forKey: "localSortKey") } }
    var localSortAscending: Bool { didSet { defaults.set(localSortAscending, forKey: "localSortAscending") } }
    var deviceSortKey: BrowserSortKey { didSet { defaults.set(deviceSortKey.rawValue, forKey: "deviceSortKey") } }
    var deviceSortAscending: Bool { didSet { defaults.set(deviceSortAscending, forKey: "deviceSortAscending") } }
    var localOnLeft: Bool { didSet { defaults.set(localOnLeft, forKey: "localOnLeft") } }
    var localView: BrowserViewMode { didSet { defaults.set(localView.rawValue, forKey: "localView") } }
    var deviceView: BrowserViewMode { didSet { defaults.set(deviceView.rawValue, forKey: "deviceView") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        localSortKey = BrowserSortKey(rawValue: defaults.string(forKey: "localSortKey") ?? "") ?? .name
        deviceSortKey = BrowserSortKey(rawValue: defaults.string(forKey: "deviceSortKey") ?? "") ?? .name
        localSortAscending = defaults.object(forKey: "localSortAscending") as? Bool ?? true
        deviceSortAscending = defaults.object(forKey: "deviceSortAscending") as? Bool ?? true
        localOnLeft = defaults.object(forKey: "localOnLeft") as? Bool ?? true
        localView = BrowserViewMode(rawValue: defaults.string(forKey: "localView") ?? "") ?? .list
        deviceView = BrowserViewMode(rawValue: defaults.string(forKey: "deviceView") ?? "") ?? .list
    }
}
