import SwiftUI

struct MenuBarContent: View {
    private let store = CommandStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.enabledCommands) { command in
            Button { CommandRunner.run(command) } label: {
                Label {
                    Text("\(command.appName): \(command.title)")
                } icon: {
                    if let icon = IconCache.menuImage(for: command.bundleID) { icon }
                }
            }
        }
        Divider()
        Button("Settings…") {
            openWindow(id: SettingsWindow.id)
            // LSUIElement apps don't activate on window open; give the window a beat to exist first.
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                NSApplication.shared.activate()
            }
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
