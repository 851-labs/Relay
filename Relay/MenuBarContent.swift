import SwiftUI

struct MenuBarContent: View {
    private let store = CommandStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.enabledCommands) { command in
            Button("\(command.appName): \(command.title)") { CommandRunner.run(command) }
        }
        Divider()
        Button("Settings…") {
            openWindow(id: SettingsWindow.id)
            NSApplication.shared.activate()
        }
        .keyboardShortcut(",")
        Button("Reindex Spotlight") { Task { await store.reindex() } }
        Divider()
        Button("Quit Relay") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

enum SettingsWindow {
    static let id = "settings"
}
