import SwiftUI

struct MenuBarContent: View {
    private let store = CommandStore.shared
    @Environment(\.openWindow) private var openWindow

    private var enabledApps: [RelayedApp] {
        let enabledIDs = Set(store.enabledCommands.map(\.id))
        return store.apps.compactMap { app in
            let commands = app.commands.filter { enabledIDs.contains($0.id) }
            return commands.isEmpty ? nil : RelayedApp(bundleID: app.bundleID, name: app.name, commands: commands)
        }
    }

    var body: some View {
        // One submenu per app, labeled with its icon; apps with nothing enabled are left out.
        ForEach(enabledApps) { app in
            Menu {
                ForEach(app.commands) { command in
                    Button(command.title) { CommandRunner.run(command) }
                }
            } label: {
                Label {
                    Text(app.name)
                } icon: {
                    if let icon = IconCache.menuImage(for: app.bundleID) { icon }
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
