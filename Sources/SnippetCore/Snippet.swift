import Foundation

public struct Snippet: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var content: String
    public var isFavorite: Bool
    public var updatedAt: Date
    public var tagIDs: Set<UUID>

    public init(id: UUID = UUID(), title: String, content: String,
                isFavorite: Bool = false, updatedAt: Date = Date(), tagIDs: Set<UUID> = []) {
        self.id = id
        self.title = title
        self.content = content
        self.isFavorite = isFavorite
        self.updatedAt = updatedAt
        self.tagIDs = tagIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, content, isFavorite, updatedAt, tagIDs
    }

    /// Version 0.1 snippets have no tagIDs field and migrate to untagged.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        content = try values.decode(String.self, forKey: .content)
        isFavorite = try values.decode(Bool.self, forKey: .isFavorite)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        tagIDs = try values.decodeIfPresent(Set<UUID>.self, forKey: .tagIDs) ?? []
    }

    public static func matching(_ snippets: [Snippet], query: String) -> [Snippet] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return snippets.filter {
            term.isEmpty || $0.title.localizedCaseInsensitiveContains(term)
                || $0.content.localizedCaseInsensitiveContains(term)
        }.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
