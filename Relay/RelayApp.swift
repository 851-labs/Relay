import AppIntents
import SwiftUI

@main
struct RelayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let store = CommandStore.shared

    init() {
        let store = store
        store.load()
        RelayShortcuts.updateAppShortcutParameters()
        Task { await store.reindex() }
    }

    var body: some Scene {
        MenuBarExtra("Relay", systemImage: "bolt.horizontal") {
            ForEach(store.commands) { command in
                Button("\(command.appName): \(command.title)") { CommandRunner.run(command) }
            }
            Divider()
            Button("Reindex Spotlight") { Task { await store.reindex() } }
            Button("Quit Relay") { NSApplication.shared.terminate(nil) }
        }
    }
}
