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

    /// Spotlight may deliver a selected indexed item as a CoreSpotlight user activity rather than an `OpenIntent`.
    func application(_ application: NSApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        RelayLog.write("continue userActivity type=\(userActivity.activityType) userInfo=\(userActivity.userInfo ?? [:])")
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return false }
        guard let command = CommandStore.shared.command(matchingSpotlightIdentifier: identifier) else {
            RelayLog.write("no command matched identifier \(identifier)")
            return false
        }
        RelayLog.write("running \(command.id) from Spotlight continuation")
        CommandRunner.run(command)
        return true
    }

    func application(_ application: NSApplication, didFailToContinueUserActivityWithType userActivityType: String, error: any Error) {
        RelayLog.write("didFailToContinueUserActivity \(userActivityType): \(error)")
    }
}
