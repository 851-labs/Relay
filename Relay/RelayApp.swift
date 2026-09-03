import SwiftUI
import AppIntents

@main
struct RelayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        CommandStore.shared.load()
        RelayShortcuts.updateAppShortcutParameters()
        Task { await CommandStore.shared.reindex() }
    }

    var body: some Scene {
        MenuBarExtra("Relay", systemImage: "bolt.horizontal") {
            ForEach(CommandStore.shared.commands) { command in
                Button("\(command.appName): \(command.title)") { CommandRunner.run(command) }
            }
            Divider()
            Button("Reindex Spotlight") { Task { await CommandStore.shared.reindex() } }
            Button("Quit Relay") { NSApp.terminate(nil) }
        }
    }
}
