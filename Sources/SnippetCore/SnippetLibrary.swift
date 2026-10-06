import Foundation

public struct SnippetLibrary: Codable, Equatable {
    public var version: Int = 2
    public var snippets: [Snippet]
    public var tags: [SnippetTag]
    public var systemFavorites: Set<SystemAction>

    public init(snippets: [Snippet] = [], tags: [SnippetTag] = [], systemFavorites: Set<SystemAction> = []) {
        self.snippets = snippets
        self.tags = tags
        self.systemFavorites = systemFavorites
    }

    private enum CodingKeys: String, CodingKey { case version, snippets, tags, systemFavorites }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let savedVersion = try values.decode(Int.self, forKey: .version)
        version = savedVersion == 1 ? 2 : savedVersion
        snippets = try values.decode([Snippet].self, forKey: .snippets)
        tags = try values.decode([SnippetTag].self, forKey: .tags)
        systemFavorites = try values.decodeIfPresent(Set<SystemAction>.self, forKey: .systemFavorites) ?? []
    }

    public func children(of parentID: UUID?) -> [SnippetTag] {
        tags.filter { $0.parentID == parentID }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    public func tree(parentID: UUID? = nil) -> [TagNode] {
        children(of: parentID).map { tag in
            let descendants = tree(parentID: tag.id)
            return TagNode(tag: tag, children: descendants.isEmpty ? nil : descendants)
        }
    }

    public func path(for id: UUID) -> String {
        var components: [String] = []
        var current: UUID? = id
        var visited = Set<UUID>()
        while let nodeID = current, visited.insert(nodeID).inserted,
              let tag = tags.first(where: { $0.id == nodeID }) {
            components.insert(tag.name, at: 0)
            current = tag.parentID
        }
        return components.joined(separator: "/")
    }

    public var tagsByPath: [SnippetTag] {
        tags.sorted { path(for: $0.id).localizedStandardCompare(path(for: $1.id)) == .orderedAscending }
    }

    public func subtreeIDs(of id: UUID) -> Set<UUID> {
        var result: Set<UUID> = [id]
        var pending = [id]
        while let parent = pending.popLast() {
            for child in children(of: parent) where result.insert(child.id).inserted {
                pending.append(child.id)
            }
        }
        return result
    }

    /// Parent scopes include every descendant and return each snippet only once.
    public func filtered(scope: LibraryScope, query: String = "") -> [Snippet] {
        let candidates: [Snippet]
        switch scope {
        case .system: candidates = []
        case .all: candidates = snippets
        case .favorites: candidates = snippets.filter(\.isFavorite)
        case .untagged: candidates = snippets.filter { $0.tagIDs.isEmpty }
        case .tag(let id):
            let ids = subtreeIDs(of: id)
            candidates = snippets.filter { !$0.tagIDs.isDisjoint(with: ids) }
        }
        return Snippet.matching(candidates, query: query)
    }

    public mutating func saveTag(_ proposed: SnippetTag) throws {
        var next = self
        var tag = proposed
        tag.name = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = next.tags.firstIndex(where: { $0.id == tag.id }) {
            next.tags[index] = tag
        } else {
            next.tags.append(tag)
        }
        try next.validate()
        self = next
    }

    /// Only removes grouping and assignments; snippet contents and favorites survive.
    public mutating func deleteTag(_ id: UUID) {
        let removed = subtreeIDs(of: id)
        tags.removeAll { removed.contains($0.id) }
        for index in snippets.indices { snippets[index].tagIDs.subtract(removed) }
    }

    public func validate() throws {
        guard version == 2 else {
            throw LibraryError.invalid("This library was saved by an unsupported app version.")
        }
        let tagIDs = Set(tags.map(\.id))
        guard tagIDs.count == tags.count, Set(snippets.map(\.id)).count == snippets.count else {
            throw LibraryError.invalid("The library contains duplicate identifiers.")
        }
        for tag in tags {
            guard !tag.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !tag.name.contains("/"), !tag.name.contains("\n"), !tag.name.contains("\r") else {
                throw LibraryError.invalid("Tag names must be nonempty and cannot contain a slash or line break.")
            }
            if let parent = tag.parentID, !tagIDs.contains(parent) {
                throw LibraryError.invalid("A tag's parent no longer exists.")
            }
            var visited: Set<UUID> = [tag.id]
            var current = tag.parentID
            while let id = current {
                guard visited.insert(id).inserted else {
                    throw LibraryError.invalid("A tag cannot be moved inside itself or one of its sub-tags.")
                }
                current = tags.first { $0.id == id }?.parentID
            }
            guard !tags.contains(where: {
                $0.id != tag.id && $0.parentID == tag.parentID
                    && $0.name.compare(tag.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) else {
                throw LibraryError.invalid("A tag with that name already exists under this parent.")
            }
        }
        guard snippets.allSatisfy({ $0.tagIDs.isSubset(of: tagIDs) }) else {
            throw LibraryError.invalid("A snippet refers to a tag that no longer exists.")
        }
    }
}
