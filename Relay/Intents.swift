import AppIntents

struct RunCommandIntent: nonisolated AppIntent {
    static let title: LocalizedStringResource = "Run Command"
    static let description = IntentDescription("Runs a Relay command in its target app.")

    @Parameter(title: "Command")
    var command: Command

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$command)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        RelayLog.write("RunCommandIntent.perform \(command.id)")
        CommandRunner.run(command)
        return .result()
    }
}

/// Fired when a Relay command is selected from Spotlight search results.
struct OpenCommandIntent: nonisolated OpenIntent {
    static let title: LocalizedStringResource = "Open Command"

    @Parameter(title: "Command")
    var target: Command

    @MainActor
    func perform() async throws -> some IntentResult {
        RelayLog.write("OpenCommandIntent.perform \(target.id)")
        CommandRunner.run(target)
        return .result()
    }
}

nonisolated struct RelayShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunCommandIntent(),
            phrases: ["Run \(\.$command) with \(.applicationName)"],
            shortTitle: "Run Command",
            systemImageName: "bolt.horizontal"
        )
    }
}
