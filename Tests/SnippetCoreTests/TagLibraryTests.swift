import XCTest
@testable import SnippetCore

final class TagLibraryTests: XCTestCase {
    private func withRepository(_ body: (SnippetRepository) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try body(SnippetRepository(fileURL: directory.appendingPathComponent("snippets.json")))
    }

    func testLegacyMigrationAndExactBackupPreserveExistingData() throws {
        try withRepository { repository in
            let original = Snippet(title: "Existing 👋", content: "Line one\nLine two", isFavorite: true)
            let encoded = try JSONEncoder().encode([original])
            var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
            raw[0].removeValue(forKey: "tagIDs")
            let legacy = try JSONSerialization.data(withJSONObject: raw)
            try legacy.write(to: repository.fileURL)
            var library = try repository.loadLibrary()
            XCTAssertEqual(library.snippets, [original])
            XCTAssertTrue(library.tags.isEmpty)
            let tag = SnippetTag(name: "Work")
            try library.saveTag(tag)
            library.snippets[0].tagIDs = [tag.id]
            try repository.saveLibrary(library)
            XCTAssertEqual(try repository.loadLibrary(), library)
            XCTAssertEqual(try Data(contentsOf: repository.legacyBackupURL), legacy)
            library.snippets[0].content = "Edited after migration"
            try repository.saveLibrary(library)
            XCTAssertEqual(try Data(contentsOf: repository.legacyBackupURL), legacy)
        }
    }

    func testParentScopeIncludesDescendantsWithoutDuplicates() throws {
        let root = SnippetTag(name: "Work")
        let child = SnippetTag(name: "Emails", parentID: root.id)
        let leaf = SnippetTag(name: "Follow-ups", parentID: child.id)
        let other = SnippetTag(name: "Other")
        let multiple = Snippet(title: "Follow up", content: "Body", tagIDs: [root.id, leaf.id, other.id])
        let childOnly = Snippet(title: "Introduction", content: "Body", tagIDs: [child.id])
        let untagged = Snippet(title: "Plain", content: "Body")
        let library = SnippetLibrary(snippets: [multiple, childOnly, untagged], tags: [root, child, leaf, other])
        try library.validate()
        XCTAssertEqual(Set(library.filtered(scope: .tag(root.id)).map(\.id)), [multiple.id, childOnly.id])
        XCTAssertEqual(library.filtered(scope: .tag(leaf.id)), [multiple])
        XCTAssertEqual(library.filtered(scope: .tag(other.id)), [multiple])
        XCTAssertEqual(library.filtered(scope: .tag(root.id), query: "INTRODUCTION"), [childOnly])
        XCTAssertEqual(library.filtered(scope: .untagged), [untagged])
        XCTAssertEqual(library.path(for: leaf.id), "Work/Emails/Follow-ups")
        XCTAssertEqual(library.tree().first { $0.id == root.id }?.children?.first?.id, child.id)
    }

    func testRenameAndMoveKeepAssignmentsAndDescendants() throws {
        let oldRoot = SnippetTag(name: "Development")
        let newRoot = SnippetTag(name: "Work")
        var child = SnippetTag(name: "Git", parentID: oldRoot.id)
        let leaf = SnippetTag(name: "Commands", parentID: child.id)
        let snippet = Snippet(title: "Status", content: "git status", tagIDs: [leaf.id, child.id])
        var library = SnippetLibrary(snippets: [snippet], tags: [oldRoot, newRoot, child, leaf])
        child.name = "Version Control"
        child.parentID = newRoot.id
        try library.saveTag(child)
        XCTAssertEqual(library.snippets, [snippet])
        XCTAssertEqual(library.path(for: leaf.id), "Work/Version Control/Commands")
        XCTAssertTrue(library.filtered(scope: .tag(oldRoot.id)).isEmpty)
        XCTAssertEqual(library.filtered(scope: .tag(newRoot.id)), [snippet])
    }

    func testDeleteSubtreeKeepsSnippetsFavoritesAndUnrelatedAssignments() throws {
        let root = SnippetTag(name: "Work")
        let child = SnippetTag(name: "Emails", parentID: root.id)
        let other = SnippetTag(name: "Clients")
        let multiple = Snippet(title: "Shared", content: "Keep this", isFavorite: true, tagIDs: [child.id, other.id])
        let single = Snippet(title: "Only work", content: "Also keep", tagIDs: [root.id])
        var library = SnippetLibrary(snippets: [multiple, single], tags: [root, child, other])
        library.deleteTag(root.id)
        try library.validate()
        XCTAssertEqual(library.tags, [other])
        XCTAssertEqual(library.snippets.count, 2)
        XCTAssertEqual(library.snippets[0].tagIDs, [other.id])
        XCTAssertEqual(library.snippets[0].content, multiple.content)
        XCTAssertTrue(library.snippets[0].isFavorite)
        XCTAssertTrue(library.snippets[1].tagIDs.isEmpty)
        XCTAssertEqual(library.filtered(scope: .untagged).map(\.id), [single.id])
    }

    func testInvalidMovesAndNamesLeaveLibraryUnchanged() throws {
        let root = SnippetTag(name: "Work")
        let child = SnippetTag(name: "Email", parentID: root.id)
        var library = SnippetLibrary(tags: [root, child])
        let before = library
        for candidate in [
            SnippetTag(id: root.id, name: "Work", parentID: child.id),
            SnippetTag(id: root.id, name: "Work", parentID: root.id),
            SnippetTag(name: " work "),
            SnippetTag(name: ""),
            SnippetTag(name: "Work/Email"),
            SnippetTag(name: "Line\nbreak"),
            SnippetTag(name: "Missing parent", parentID: UUID())
        ] {
            XCTAssertThrowsError(try library.saveTag(candidate))
            XCTAssertEqual(library, before)
        }
        // Equal leaf names are allowed under different parents.
        try library.saveTag(SnippetTag(name: "Email"))
        XCTAssertEqual(library.tags.count, 3)
    }

    func testNestedAndEmptyTagsAndMultipleAssignmentsSurviveReload() throws {
        try withRepository { repository in
            let root = SnippetTag(name: "Development")
            let child = SnippetTag(name: "Swift", parentID: root.id)
            let empty = SnippetTag(name: "Empty")
            let library = SnippetLibrary(snippets: [Snippet(title: "Example", content: "Hello",
                tagIDs: [root.id, child.id])], tags: [root, child, empty])
            try repository.saveLibrary(library)
            XCTAssertEqual(try repository.loadLibrary(), library)
            // The convenience snippet API must not drop the tag collection.
            try repository.save(library.snippets)
            XCTAssertEqual(try repository.loadLibrary().tags, library.tags)
        }
    }

    func testInvalidOrNewerSavedLibrariesAreNotOverwritten() throws {
        try withRepository { repository in
            var newer = SnippetLibrary()
            newer.version = 99
            let data = try JSONEncoder().encode(newer)
            try data.write(to: repository.fileURL)
            XCTAssertThrowsError(try repository.loadLibrary())
            XCTAssertThrowsError(try repository.saveLibrary(SnippetLibrary()))
            XCTAssertEqual(try Data(contentsOf: repository.fileURL), data)
            let corrupt = Data("bad json".utf8)
            try corrupt.write(to: repository.fileURL)
            XCTAssertThrowsError(try repository.saveLibrary(SnippetLibrary()))
            XCTAssertEqual(try Data(contentsOf: repository.fileURL), corrupt)
        }
        XCTAssertThrowsError(try SnippetLibrary(snippets: [Snippet(title: "Dangling", content: "Body", tagIDs: [UUID()])]).validate())
    }
}
