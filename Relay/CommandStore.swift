import AppIntents
import AppKit
import CoreSpotlight
import Observation

/// A third-party app that Relay exposes commands for, derived from the catalog.
struct RelayedApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let commands: [Command]

    var id: String { bundleID }
}

@Observable
final class CommandStore {
    static let shared = CommandStore()

    private static let disabledCommandsKey = "disabledCommandIDs"
    private static let disabledAppsKey = "disabledAppBundleIDs"

    private(set) var commands: [Command] = []
    /// Individually switched-off commands. Preserved while their app is off so re-enabling the app restores them.
    private(set) var disabledIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(disabledIDs).sorted(), forKey: Self.disabledCommandsKey) }
    }
    /// Apps switched off wholesale; none of their commands are exposed regardless of per-command state.
    private(set) var disabledAppIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(disabledAppIDs).sorted(), forKey: Self.disabledAppsKey) }
    }

    @ObservationIgnored private var reindexTask: Task<Void, Never>?

    private init() {
        disabledIDs = Set(UserDefaults.standard.stringArray(forKey: Self.disabledCommandsKey) ?? [])
        disabledAppIDs = Set(UserDefaults.standard.stringArray(forKey: Self.disabledAppsKey) ?? [])
    }

    /// Commands whose app is on and that aren't individually off — the only ones indexed, queryable, or listed in the menu.
    var enabledCommands: [Command] {
        commands.filter { !disabledAppIDs.contains($0.bundleID) && !disabledIDs.contains($0.id) }
    }

    /// Catalog grouped by target app, in first-appearance order.
    var apps: [RelayedApp] {
        var order: [String] = []
        var grouped: [String: [Command]] = [:]
        for command in commands {
            if grouped[command.bundleID] == nil { order.append(command.bundleID) }
            grouped[command.bundleID, default: []].append(command)
        }
        return order.map { RelayedApp(bundleID: $0, name: grouped[$0]!.first!.appName, commands: grouped[$0]!) }
    }

    func isEnabled(_ command: Command) -> Bool {
        !disabledIDs.contains(command.id)
    }

    func setEnabled(_ enabled: Bool, for command: Command) {
        if enabled { disabledIDs.remove(command.id) } else { disabledIDs.insert(command.id) }
        scheduleReindex()
    }

    func isAppEnabled(_ bundleID: String) -> Bool {
        !disabledAppIDs.contains(bundleID)
    }

    func setAppEnabled(_ enabled: Bool, bundleID: String) {
        if enabled { disabledAppIDs.remove(bundleID) } else { disabledAppIDs.insert(bundleID) }
        scheduleReindex()
    }

    /// Loads ~/Library/Application Support/Relay/commands.json if present, else the bundled catalog,
    /// and primes the icon cache so entity getters can run off the main actor without touching AppKit.
    func load() {
        let userFile = URL.applicationSupportDirectory.appending(path: "Relay/commands.json")
        let source = FileManager.default.fileExists(atPath: userFile.path)
            ? userFile
            : Bundle.main.url(forResource: "commands", withExtension: "json")

        do {
            guard let source else { throw CocoaError(.fileNoSuchFile) }
            commands = try JSONDecoder().decode([Command].self, from: Data(contentsOf: source))
        } catch {
            RelayLog.write("failed to load commands: \(error)")
            commands = []
        }

        migrateWholeAppDisables()
        IconCache.prime(bundleIDs: Set(commands.map(\.bundleID)))
    }

    /// Before app-level switches existed, turning an app off disabled every one of its commands individually.
    /// Reinterpret that state as "app off" so the per-command switches come back on.
    private func migrateWholeAppDisables() {
        for app in apps where !app.commands.isEmpty && app.commands.allSatisfy({ disabledIDs.contains($0.id) }) {
            disabledIDs.subtract(app.commands.map(\.id))
            disabledAppIDs.insert(app.bundleID)
        }
    }

    func reindex() async {
        do {
            let index = CSSearchableIndex.default()
            try await index.deleteAllSearchableItems()
            try await index.indexAppEntities(enabledCommands)
            RelayLog.write("indexed \(enabledCommands.count) of \(commands.count) commands")
        } catch {
            RelayLog.write("indexing failed: \(error)")
        }
    }

    /// Coalesces rapid toggling into a single reindex.
    private func scheduleReindex() {
        reindexTask?.cancel()
        reindexTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await reindex()
        }
    }

    func command(matchingSpotlightIdentifier identifier: String) -> Command? {
        commands.first { identifier == $0.id || identifier.hasSuffix($0.id) }
    }
}

enum CommandRunner {
    static func run(_ command: Command) {
        switch command.action {
        case .url(let string):
            guard let url = URL(string: string) else { return }
            NSWorkspace.shared.open(url)
        case .shell(let script):
            let process = Process()
            process.executableURL = URL(filePath: "/bin/zsh")
            process.arguments = ["-lc", script]
            do { try process.run() } catch { RelayLog.write("shell failed: \(error)") }
        }
    }
}
