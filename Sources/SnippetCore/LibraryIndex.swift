import Foundation

/// Derived navigation data rebuilt only when snippets or tags change.
public struct LibraryIndex {
    public let counts: [LibraryScope: Int]
    public let tree: [TagNode]
    public let tagsByPath: [SnippetTag]
    public let paths: [UUID: String]

    public init(library: SnippetLibrary) {
        var tags: [UUID: SnippetTag] = [:]
        for tag in library.tags { tags[tag.id] = tag }
        var paths: [UUID: String] = [:]
        for tag in library.tags {
            var names: [String] = []
            var cursor: UUID? = tag.id
            var visited = Set<UUID>()
            while let id = cursor, visited.insert(id).inserted, let node = tags[id] {
                names.append(node.name)
                cursor = node.parentID
            }
            paths[tag.id] = names.reversed().joined(separator: "/")
        }
        self.paths = paths
        tagsByPath = library.tags.sorted {
            (paths[$0.id] ?? "").localizedStandardCompare(paths[$1.id] ?? "") == .orderedAscending
        }
        let children = Dictionary(grouping: library.tags, by: \.parentID).mapValues {
            $0.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        func nodes(_ parent: UUID?) -> [TagNode] {
            (children[parent] ?? []).map { tag in
                let descendants = nodes(tag.id)
                return TagNode(tag: tag, children: descendants.isEmpty ? nil : descendants)
            }
        }
        tree = nodes(nil)

        var counts: [LibraryScope: Int] = [.all: library.snippets.count, .favorites: 0, .untagged: 0]
        for tag in library.tags { counts[.tag(tag.id)] = 0 }
        for snippet in library.snippets {
            if snippet.isFavorite { counts[.favorites, default: 0] += 1 }
            if snippet.tagIDs.isEmpty { counts[.untagged, default: 0] += 1 }
            // Assignments to siblings or to both parent/child count once per ancestor.
            var ancestors = Set<UUID>()
            for id in snippet.tagIDs {
                var cursor: UUID? = id
                while let node = cursor, ancestors.insert(node).inserted {
                    cursor = tags[node]?.parentID
                }
            }
            for id in ancestors { counts[.tag(id), default: 0] += 1 }
        }
        self.counts = counts
    }
}
