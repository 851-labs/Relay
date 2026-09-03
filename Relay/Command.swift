import AppIntents
import CoreSpotlight
import AppKit

enum CommandAction: Codable, Hashable, Sendable {
    case url(String)
    case shell(String)
}

struct Command: AppEntity, IndexedEntity, Codable, Hashable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Command")
    static let defaultQuery = CommandQuery()

    var id: String
    var title: String
    var appName: String
    var bundleID: String
    var action: CommandAction
    var keywords: [String] = []

    var displayRepresentation: DisplayRepresentation {
        if let png = IconCache.pngData(bundleID: bundleID) {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(appName)", image: .init(data: png))
        }
        return DisplayRepresentation(title: "\(title)", subtitle: "\(appName)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = title
        attributes.contentDescription = appName
        attributes.keywords = keywords + [appName, "relay"]
        attributes.thumbnailData = IconCache.pngData(bundleID: bundleID)
        return attributes
    }
}

struct CommandQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [Command] {
        RelayLog.write("CommandQuery.entities(for:) \(identifiers)")
        return CommandStore.shared.commands.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [Command] {
        let needle = string.lowercased()
        return CommandStore.shared.commands.filter {
            $0.title.lowercased().contains(needle)
                || $0.appName.lowercased().contains(needle)
                || $0.keywords.contains { $0.lowercased().contains(needle) }
        }
    }

    func suggestedEntities() async throws -> [Command] {
        CommandStore.shared.commands
    }
}
