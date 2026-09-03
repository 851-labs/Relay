import Foundation

/// Append-only diagnostics at ~/Library/Logs/Relay.log.
nonisolated enum RelayLog {
    private static let url = URL.homeDirectory.appending(path: "Library/Logs/Relay.log")

    static func write(_ message: String) {
        let line = Data("\(Date.now) \(message)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url)
        }
    }
}
