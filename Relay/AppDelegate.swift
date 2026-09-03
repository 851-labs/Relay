import AppKit
import CoreSpotlight

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        RelayLog.write("applicationDidFinishLaunching")
    }

    func application(_ application: NSApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        RelayLog.write("willContinueUserActivityWithType \(userActivityType)")
        return true
    }

    func application(_ application: NSApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        RelayLog.write("continue userActivity type=\(userActivity.activityType) userInfo=\(userActivity.userInfo ?? [:])")
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return false }
        // Identifier may be the bare entity id or a system-prefixed form; match on suffix.
        if let command = CommandStore.shared.commands.first(where: { identifier == $0.id || identifier.hasSuffix($0.id) }) {
            RelayLog.write("running \(command.id) from Spotlight continuation")
            CommandRunner.run(command)
            return true
        }
        RelayLog.write("no command matched identifier \(identifier)")
        return false
    }

    func application(_ application: NSApplication, didFailToContinueUserActivityWithType userActivityType: String, error: any Error) {
        RelayLog.write("didFailToContinueUserActivity \(userActivityType): \(error)")
    }
}
