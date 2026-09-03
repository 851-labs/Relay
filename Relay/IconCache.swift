import AppKit
import SwiftUI
import Synchronization

/// PNG renderings of app icons, keyed by bundle identifier.
///
/// Rendering touches AppKit, so it happens once on the main actor via `prime`; reads are lock-protected
/// and safe from the concurrent contexts App Intents uses when evaluating entity representations.
nonisolated enum IconCache {
    private static let cache = Mutex<[String: Data]>([:])
    private static let iconSize = NSSize(width: 128, height: 128)

    static func pngData(for bundleID: String) -> Data? {
        cache.withLock { $0[bundleID] }
    }

    @MainActor
    static func prime(bundleIDs: Set<String>) {
        for bundleID in bundleIDs where pngData(for: bundleID) == nil {
            guard let png = render(bundleID: bundleID) else { continue }
            cache.withLock { $0[bundleID] = png }
        }
    }

    @MainActor
    private static func render(bundleID: String) -> Data? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        let rendered = NSImage(size: iconSize, flipped: false) { rect in
            icon.draw(in: rect)
            return true
        }
        guard let tiff = rendered.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

extension IconCache {
    @MainActor
    static func image(for bundleID: String) -> Image? {
        guard let png = pngData(for: bundleID), let nsImage = NSImage(data: png) else { return nil }
        return Image(nsImage: nsImage)
    }
}
