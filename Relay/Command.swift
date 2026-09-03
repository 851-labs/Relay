import AppIntents
import CoreSpotlight

/// What a command does when run. Encoded as a single-key object: `{"url": "..."}` or `{"shell": "..."}`.
nonisolated enum CommandAction: Hashable, Sendable {
    case url(String)
    case shell(String)
}

extension CommandAction: Codable {
    private enum CodingKeys: String, CodingKey { case url, shell }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let url = try container.decodeIfPresent(String.self, forKey: .url) {
            self = .url(url)
        } else if let shell = try container.decodeIfPresent(String.self, forKey: .shell) {
            self = .shell(shell)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expected \"url\" or \"shell\""))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .url(let value): try container.encode(value, forKey: .url)
        case .shell(let value): try container.encode(value, forKey: .shell)
        }
    }
}

nonisolated struct Command: AppEntity, IndexedEntity, Codable, Hashable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Command")
    static let defaultQuery = CommandQuery()

    var id: String
    var title: String
    var appName: String
    var bundleID: String
    var action: CommandAction
    var keywords: [String] = []

    var displayRepresentation: DisplayRepresentation {
        guard let png = IconCache.pngData(for: bundleID) else {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(appName)")
        }
        return DisplayRepresentation(title: "\(title)", subtitle: "\(appName)", image: .init(data: png))
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = title
        attributes.contentDescription = appName
        attributes.keywords = keywords + [appName, "relay"]
        attributes.thumbnailData = IconCache.pngData(for: bundleID)
        return attributes
    }

    func matches(_ query: String) -> Bool {
        let needle = query.lowercased()
        return title.localizedCaseInsensitiveContains(needle)
            || appName.localizedCaseInsensitiveContains(needle)
            || keywords.contains { $0.localizedCaseInsensitiveContains(needle) }
    }
}

nonisolated struct CommandQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [Command] {
        RelayLog.write("CommandQuery.entities(for:) \(identifiers)")
        let ids = Set(identifiers)
        return await CommandStore.shared.commands.filter { ids.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [Command] {
        await CommandStore.shared.commands.filter { $0.matches(string) }
    }

    func suggestedEntities() async throws -> [Command] {
        await CommandStore.shared.commands
    }
}
