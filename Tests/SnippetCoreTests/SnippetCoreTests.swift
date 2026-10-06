import XCTest
@testable import SnippetCore

final class SnippetCoreTests: XCTestCase {
    private func temporaryRepository() -> SnippetRepository {
        SnippetRepository(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("snippets.json"))
    }

    func testRoundTripPreservesUnicodeMultilineAndFavorites() throws {
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.fileURL.deletingLastPathComponent()) }
        let snippet = Snippet(title: "Greeting 👋", content: "Hello\nこんにちは\n\"quoted\"", isFavorite: true)
        try repository.save([snippet])
        XCTAssertEqual(try repository.load(), [snippet])
    }

    func testUpdatesAndDeletionPersistAcrossReloads() throws {
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.fileURL.deletingLastPathComponent()) }
        var snippet = Snippet(title: "Before", content: "Original")
        try repository.save([snippet])
        snippet.title = "After"
        snippet.content = "Updated"
        try repository.save([snippet])
        XCTAssertEqual(try repository.load(), [snippet])
        try repository.save([])
        XCTAssertEqual(try repository.load(), [])
    }

    func testMissingFileLoadsEmptyAndCorruptFileIsNotOverwritten() throws {
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.fileURL.deletingLastPathComponent()) }
        XCTAssertEqual(try repository.load(), [])
        try FileManager.default.createDirectory(at: repository.fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let corrupt = Data("invalid json".utf8)
        try corrupt.write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), corrupt)
    }

    func testSearchMatchesTitleAndContentIgnoringCaseAndWhitespace() {
        let snippet = Snippet(title: "Meeting", content: "Follow up tomorrow")
        XCTAssertEqual(Snippet.matching([snippet], query: " MEETING "), [snippet])
        XCTAssertEqual(Snippet.matching([snippet], query: "TOMORROW"), [snippet])
        XCTAssertTrue(Snippet.matching([snippet], query: "missing").isEmpty)
    }

    func testFavoritesSortBeforeMoreRecentSnippets() {
        let favorite = Snippet(title: "Favorite", content: "A", isFavorite: true,
                               updatedAt: Date(timeIntervalSince1970: 1))
        let recent = Snippet(title: "Recent", content: "B", updatedAt: Date())
        XCTAssertEqual(Snippet.matching([recent, favorite], query: ""), [favorite, recent])
    }
}
