import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: BrowserPreferences
    var body: some View {
        Form {
            Section("Browser") {
                Toggle("Show this Mac on the left", isOn: $preferences.localOnLeft)
                Text("OpenMTP follows your Mac’s appearance, contrast, and motion settings.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 190)
    }
}
