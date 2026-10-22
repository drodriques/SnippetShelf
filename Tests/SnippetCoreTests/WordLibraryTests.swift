import XCTest
@testable import SnippetCore

final class WordLibraryTests: XCTestCase {
    func testReplacingCurrentArchivesPreviousAndKeepsExactlyOneCurrent() throws {
        var library = WordLibrary()
        let first = try library.add(word: " Serendipity ", definition: " A happy discovery. ", at: Date(timeIntervalSince1970: 1))
        let second = try library.add(word: "Resilience", definition: "The ability to recover.", at: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(library.current?.id, second)
        XCTAssertEqual(library.history.map(\.id), [first])
        XCTAssertEqual(library.history.first?.word, "Serendipity")
        XCTAssertEqual(library.history.first?.definition, "A happy discovery.")
        XCTAssertEqual(library.entries.count, 2)
    }

    func testReusingHistoryCreatesNewDatedOccurrenceAndArchivesCurrent() throws {
        var library = WordLibrary()
        let pastID = try library.add(word: "Serendipity", definition: "A happy discovery.", at: Date(timeIntervalSince1970: 1))
        let currentID = try library.add(word: "Resilience", definition: "Recovery.", at: Date(timeIntervalSince1970: 2))
        let original = library.history.first!
        let previousCurrent = library.current!
        let date = Date(timeIntervalSince1970: 3)
        let reusedID = try library.reuse(id: pastID, at: date)
        XCTAssertNotEqual(reusedID, pastID)
        XCTAssertNotEqual(reusedID, currentID)
        XCTAssertEqual(library.current?.word, original.word)
        XCTAssertEqual(library.current?.definition, original.definition)
        XCTAssertEqual(library.current?.createdAt, date)
        XCTAssertEqual(library.current?.updatedAt, date)
        XCTAssertEqual(library.history, [previousCurrent, original])
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.fileURL.deletingLastPathComponent()) }
        try repository.save(library)
        XCTAssertEqual(try repository.load(), library)
        // An edit to the reused occurrence must not alter the original.
        try library.edit(id: reusedID, word: "Corrected", definition: "Updated")
        XCTAssertEqual(library.entries.first { $0.id == pastID }, original)
    }

    func testRepeatedReuseRecordsEachOccurrenceIncludingWhenThereIsNoCurrent() throws {
        var library = WordLibrary()
        let originalID = try library.add(word: "Again", definition: "Another occurrence.")
        let removedID = try library.add(word: "Remove", definition: "Temporary.")
        library.delete(id: removedID)
        XCTAssertNil(library.current)
        let firstReuseID = try library.reuse(id: originalID)
        let secondReuseID = try library.reuse(id: originalID)
        XCTAssertEqual(library.currentID, secondReuseID)
        XCTAssertEqual(library.history.count, 2)
        XCTAssertEqual(Set(library.history.map(\.id)), [originalID, firstReuseID])
        XCTAssertEqual(library.entries.count, 3)
    }

    func testReusingMissingOrCurrentWordLeavesCollectionUnchanged() throws {
        var library = WordLibrary()
        let id = try library.add(word: "Current", definition: "Current definition.")
        let original = library
        XCTAssertThrowsError(try library.reuse(id: id))
        XCTAssertThrowsError(try library.reuse(id: UUID()))
        XCTAssertEqual(library, original)
    }

    func testEditingCurrentOrHistoryPreservesIdentityDatesAndCurrentChoice() throws {
        var library = WordLibrary()
        let first = try library.add(word: "Old", definition: "Old definition", at: Date(timeIntervalSince1970: 1))
        let second = try library.add(word: "Current", definition: "Current definition", at: Date(timeIntervalSince1970: 2))
        try library.edit(id: first, word: " Past ", definition: " Corrected ", at: Date(timeIntervalSince1970: 3))
        try library.edit(id: second, word: "Present", definition: "Updated", at: Date(timeIntervalSince1970: 4))
        XCTAssertEqual(library.entries.count, 2)
        XCTAssertEqual(library.currentID, second)
        XCTAssertEqual(library.current?.word, "Present")
        XCTAssertEqual(library.current?.createdAt, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(library.current?.updatedAt, Date(timeIntervalSince1970: 4))
        XCTAssertEqual(library.history.first?.word, "Past")
        XCTAssertEqual(library.history.first?.createdAt, Date(timeIntervalSince1970: 1))
    }

    func testDeletionDoesNotPromoteHistoryAndHistoryDeletionKeepsCurrent() throws {
        var library = WordLibrary()
        let first = try library.add(word: "One", definition: "First")
        let second = try library.add(word: "Two", definition: "Second")
        let third = try library.add(word: "Three", definition: "Third")
        library.delete(id: second)
        XCTAssertEqual(library.currentID, third)
        XCTAssertEqual(library.history.map(\.id), [first])
        library.delete(id: third)
        XCTAssertNil(library.current)
        XCTAssertEqual(library.history.map(\.id), [first])
        try library.validate()
    }

    func testInvalidEditsAndNewWordsLeaveOriginalUntouched() throws {
        var library = WordLibrary()
        let current = try library.add(word: "Valid", definition: "Definition")
        let original = library
        for (word, definition) in [(" \n", "Definition"), ("Word", " \n"), ("Two\nlines", "Definition")] {
            XCTAssertThrowsError(try library.add(word: word, definition: definition))
            XCTAssertThrowsError(try library.edit(id: current, word: word, definition: definition))
            XCTAssertEqual(library, original)
        }
        XCTAssertThrowsError(try library.edit(id: UUID(), word: "Missing", definition: "Definition"))
        XCTAssertEqual(library, original)
    }

    func testHistoryOrderUsesAddedDateRatherThanEditDate() throws {
        var library = WordLibrary()
        let first = try library.add(word: "First", definition: "1", at: Date(timeIntervalSince1970: 1))
        let second = try library.add(word: "Second", definition: "2", at: Date(timeIntervalSince1970: 2))
        _ = try library.add(word: "Current", definition: "3", at: Date(timeIntervalSince1970: 3))
        try library.edit(id: first, word: "Edited first", definition: "1", at: Date(timeIntervalSince1970: 4))
        XCTAssertEqual(library.history.map(\.id), [second, first])
    }

    func testMenuTitleIsBoundedWithoutSplittingUnicodeCharacters() {
        let word = String(repeating: "👨‍👩‍👧‍👦", count: 30)
        let entry = WordEntry(word: word, definition: "A family")
        XCTAssertEqual(entry.menuBarTitle, String(repeating: "👨‍👩‍👧‍👦", count: 24) + "…")
        XCTAssertEqual(WordEntry(word: "Café", definition: "Coffee").menuBarTitle, "Café")
    }

    func testRepositoryRoundTripAndDeletingCurrentPersistAcrossReloads() throws {
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.fileURL.deletingLastPathComponent()) }
        XCTAssertEqual(try repository.load(), WordLibrary())
        var library = WordLibrary()
        _ = try library.add(word: "一期一会", definition: "A unique encounter.\nAn opportunity to treasure.")
        let current = try library.add(word: "Café 👋", definition: "A place for coffee.\n\"Hello\"", at: Date(timeIntervalSince1970: 100))
        try repository.save(library)
        XCTAssertEqual(try repository.load(), library)
        library.delete(id: current)
        try repository.save(library)
        XCTAssertEqual(try repository.load(), library)
        XCTAssertNil(try repository.load().current)
    }

    func testCorruptNewerAndInvalidFilesCannotBeOverwritten() throws {
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.fileURL.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: repository.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let entry = WordEntry(word: "Valid", definition: "Definition")
        var newer = WordLibrary(entries: [entry], currentID: entry.id)
        newer.version = 99
        let invalid = WordLibrary(entries: [entry], currentID: UUID())
        let duplicates = WordLibrary(entries: [entry, entry], currentID: entry.id)
        let documents = [Data("not json".utf8), try JSONEncoder().encode(newer),
                         try JSONEncoder().encode(invalid), try JSONEncoder().encode(duplicates)]
        for document in documents {
            try document.write(to: repository.fileURL)
            XCTAssertThrowsError(try repository.load())
            XCTAssertThrowsError(try repository.save(WordLibrary()))
            XCTAssertEqual(try Data(contentsOf: repository.fileURL), document)
        }
    }

    func testSearchMatchesWordsAndDefinitionsIgnoringCaseAndWhitespace() {
        let entry = WordEntry(word: "Serendipity", definition: "An unexpected happy discovery.")
        XCTAssertTrue(entry.matches(" SERENDIPITY "))
        XCTAssertTrue(entry.matches("UNEXPECTED"))
        XCTAssertTrue(entry.matches("  "))
        XCTAssertFalse(entry.matches("missing"))
    }

    func testWordScopeDoesNotIncludeOrChangeSnippets() {
        let snippet = Snippet(title: "A snippet", content: "Keep me")
        let library = SnippetLibrary(snippets: [snippet])
        XCTAssertTrue(library.filtered(scope: .wordOfDay).isEmpty)
        XCTAssertEqual(library.filtered(scope: .all), [snippet])
    }

    private func temporaryRepository() -> WordRepository {
        WordRepository(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("words.json"))
    }
}
