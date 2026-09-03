import AppIntents
import SwiftUI

@main
struct RelayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let store = CommandStore.shared
        store.load()
        RelayShortcuts.updateAppShortcutParameters()
        Task { await store.reindex() }
    }

    var body: some Scene {
        MenuBarExtra("Relay", systemImage: "bolt.horizontal") {
            MenuBarContent()
        }

        Window("Relay", id: SettingsWindow.id) {
            SettingsView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 820, height: 560)
    }
}
