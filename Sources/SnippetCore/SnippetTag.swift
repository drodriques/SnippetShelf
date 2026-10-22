import Foundation

/// Assignments use stable IDs so renaming or moving a tag never breaks a snippet.
public struct SnippetTag: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var parentID: UUID?

    public init(id: UUID = UUID(), name: String, parentID: UUID? = nil) {
        self.id = id
        self.name = name
        self.parentID = parentID
    }
}

public struct TagNode: Identifiable {
    public let tag: SnippetTag
    public let children: [TagNode]?
    public var id: UUID { tag.id }

    public init(tag: SnippetTag, children: [TagNode]?) {
        self.tag = tag
        self.children = children
    }
}

public enum LibraryScope: Hashable {
    case all, favorites, untagged, wordOfDay, tag(UUID), system(SystemGroup)
}

public enum LibraryError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}
