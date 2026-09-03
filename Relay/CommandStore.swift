import Foundation
import CoreSpotlight
import AppKit

final class CommandStore: @unchecked Sendable {
    static let shared = CommandStore()

    private(set) var commands: [Command] = []

    /// Loads ~/Library/Application Support/Relay/commands.json if present, else the bundled catalog.
    func load() {
        let userFile = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Relay/commands.json")
        let url = FileManager.default.fileExists(atPath: userFile.path)
            ? userFile
            : Bundle.main.url(forResource: "commands", withExtension: "json")!
        do {
            commands = try JSONDecoder().decode([Command].self, from: Data(contentsOf: url))
        } catch {
            NSLog("Relay: failed to load commands: \(error)")
            commands = []
        }
    }

    func reindex() async {
        do {
            try await CSSearchableIndex.default().deleteAllSearchableItems()
            try await CSSearchableIndex.default().indexAppEntities(commands)
            NSLog("Relay: indexed \(commands.count) commands")
        } catch {
            NSLog("Relay: indexing failed: \(error)")
        }
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
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", script]
            try? process.run()
        }
    }
}

enum IconCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: Data] = [:]

    static func pngData(bundleID: String) -> Data? {
        lock.lock()
        let cached = cache[bundleID]
        lock.unlock()
        if let cached { return cached }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        let size = NSSize(width: 128, height: 128)
        let rendered = NSImage(size: size, flipped: false) { rect in
            icon.draw(in: rect)
            return true
        }
        guard let tiff = rendered.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }

        lock.lock()
        cache[bundleID] = png
        lock.unlock()
        return png
    }
}
