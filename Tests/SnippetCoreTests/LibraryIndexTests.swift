import XCTest
@testable import SnippetCore

final class LibraryIndexTests: XCTestCase {
    func testCountsAgreeWithFilteringForOverlappingTagAssignments() throws {
        let parent = SnippetTag(name: "Work")
        let child = SnippetTag(name: "Code", parentID: parent.id)
        let sibling = SnippetTag(name: "Notes", parentID: parent.id)
        let empty = SnippetTag(name: "Empty")
        let library = SnippetLibrary(snippets: [
            Snippet(title: "Parent and child", content: "A", isFavorite: true, tagIDs: [parent.id, child.id]),
            Snippet(title: "Both children", content: "B", tagIDs: [child.id, sibling.id]),
            Snippet(title: "Untagged", content: "C", isFavorite: true)
        ], tags: [sibling, empty, child, parent])
        try library.validate()
        let index = LibraryIndex(library: library)
        let scopes: [LibraryScope] = [.all, .favorites, .untagged, .tag(parent.id), .tag(child.id), .tag(sibling.id), .tag(empty.id)]
        for scope in scopes { XCTAssertEqual(index.counts[scope], library.filtered(scope: scope).count) }
        XCTAssertEqual(index.counts[.tag(parent.id)], 2)
        XCTAssertEqual(index.counts[.tag(empty.id)], 0)
    }

    func testIndexedTreePathsAndOrderingMatchLibraryNavigation() {
        let parent = SnippetTag(name: "Work")
        let child = SnippetTag(name: "Code", parentID: parent.id)
        let deep = SnippetTag(name: "Swift", parentID: child.id)
        let other = SnippetTag(name: "Personal")
        let library = SnippetLibrary(tags: [deep, other, child, parent])
        let index = LibraryIndex(library: library)
        XCTAssertEqual(index.tagsByPath, library.tagsByPath)
        for tag in library.tags { XCTAssertEqual(index.paths[tag.id], library.path(for: tag.id)) }
        func flatten(_ nodes: [TagNode]) -> [UUID] {
            nodes.flatMap { [$0.id] + flatten($0.children ?? []) }
        }
        XCTAssertEqual(flatten(index.tree), flatten(library.tree()))
        XCTAssertEqual(index.tree.first?.id, other.id)
        XCTAssertEqual(index.paths[deep.id], "Work/Code/Swift")
    }

    func testRebuildingAfterMovesDeletionAndSnippetEditsDoesNotKeepStaleCounts() throws {
        let first = SnippetTag(name: "First")
        let second = SnippetTag(name: "Second")
        var child = SnippetTag(name: "Child", parentID: first.id)
        var library = SnippetLibrary(snippets: [Snippet(title: "One", content: "Text", tagIDs: [child.id])], tags: [first, second, child])
        let before = LibraryIndex(library: library)
        child.parentID = second.id
        try library.saveTag(child)
        library.snippets[0].isFavorite = true
        let moved = LibraryIndex(library: library)
        XCTAssertEqual(before.counts[.tag(first.id)], 1)
        XCTAssertEqual(moved.counts[.tag(first.id)], 0)
        XCTAssertEqual(moved.counts[.tag(second.id)], 1)
        XCTAssertEqual(moved.counts[.favorites], 1)
        XCTAssertEqual(moved.paths[child.id], "Second/Child")
        library.deleteTag(second.id)
        let deleted = LibraryIndex(library: library)
        XCTAssertEqual(deleted.counts[.untagged], 1)
        XCTAssertNil(deleted.paths[child.id])
        XCTAssertFalse(deleted.tagsByPath.contains { $0.id == child.id })
    }
}
