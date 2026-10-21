import SwiftUI

struct AppCommands: Commands {
    let model: AppModel
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Folder") { model.requestNewFolder() }.keyboardShortcut("n", modifiers: [.command, .shift]).disabled(!model.canActOnPane)
            Button("Rename") { model.requestRename() }.disabled(!model.canActOnPane || model.activePane.selection.count != 1)
            Button(model.activePaneKind == .local ? "Move to Trash" : "Delete from Device…") { model.requestDelete() }
                .keyboardShortcut(.delete, modifiers: .command).disabled(!model.canActOnPane || model.activePane.selection.isEmpty)
            Divider()
            Button("Enclosing Folder") { model.activePane.goUp() }.keyboardShortcut(.upArrow, modifiers: .command)
            Button("Refresh") { Task { await model.activePane.refresh() } }.keyboardShortcut("r")
        }
        CommandGroup(after: .toolbar) {
            Button("Swap Panes") { model.preferences.localOnLeft.toggle() }
            Toggle("Show Hidden Files", isOn: Binding(get: { model.activePane.showHidden }, set: { model.activePane.showHidden = $0 }))
                .keyboardShortcut(".", modifiers: [.command, .shift])
        }
    }
}
