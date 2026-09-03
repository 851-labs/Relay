import AppIntents
import AppKit
import CoreSpotlight
import Observation

@Observable
final class CommandStore {
    static let shared = CommandStore()

    private(set) var commands: [Command] = []

    private init() {}

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

        IconCache.prime(bundleIDs: Set(commands.map(\.bundleID)))
    }

    func reindex() async {
        do {
            let index = CSSearchableIndex.default()
            try await index.deleteAllSearchableItems()
            try await index.indexAppEntities(commands)
            RelayLog.write("indexed \(commands.count) commands")
        } catch {
            RelayLog.write("indexing failed: \(error)")
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
