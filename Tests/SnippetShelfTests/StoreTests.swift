import XCTest
import SnippetCore
@testable import SnippetShelf

private enum FixtureError: Error { case unavailable }

/// A deterministic suspension point; tests release it explicitly, without sleeps.
private actor OperationGate {
    private var entered = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func pause() async {
        entered = true
        entryWaiters.forEach { $0.resume() }
        entryWaiters.removeAll()
        await withCheckedContinuation { releaseContinuation = $0 }
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }
    func release() { releaseContinuation?.resume(); releaseContinuation = nil }
}

private actor MemorySnippets: SnippetPersisting {
    private(set) var value: SnippetLibrary
    private(set) var loads = 0
    private(set) var saves = 0
    private var failLoad = false
    private var failSave = false
    let loadGate: OperationGate?
    let saveGate: OperationGate?

    init(_ value: SnippetLibrary = SnippetLibrary(), loadGate: OperationGate? = nil,
         saveGate: OperationGate? = nil) {
        self.value = value
        self.loadGate = loadGate
        self.saveGate = saveGate
    }
    func setFailures(load: Bool = false, save: Bool = false) { failLoad = load; failSave = save }
    func load() async throws -> SnippetLibrary {
        loads += 1
        await loadGate?.pause()
        if failLoad { throw FixtureError.unavailable }
        return value
    }
    func save(_ library: SnippetLibrary) async throws {
        saves += 1
        await saveGate?.pause()
        if failSave { throw FixtureError.unavailable }
        value = library
    }
}

private actor MemoryWords: WordPersisting {
    private(set) var value = WordLibrary()
    private var failLoad = false
    private var failSave = false
    func setFailures(load: Bool = false, save: Bool = false) { failLoad = load; failSave = save }
    func load() async throws -> WordLibrary {
        if failLoad { throw FixtureError.unavailable }
        return value
    }
    func save(_ library: WordLibrary) async throws {
        if failSave { throw FixtureError.unavailable }
        value = library
    }
}

private struct FixedSystemSource: SystemDataSource {
    func networkAddresses() throws -> [NetworkAddress] { [] }
    func computerName() -> String? { "Test Mac" }
    func macOSVersion() -> String { "macOS Test" }
    func now() -> Date { Date(timeIntervalSince1970: 0) }
    func timeZone() -> TimeZone { TimeZone(secondsFromGMT: 0)! }
    func locale() -> Locale { Locale(identifier: "en_US_POSIX") }
}

final class StoreTests: XCTestCase {
    @MainActor
    private func store(_ storage: MemorySnippets) -> SnippetStore {
        SnippetStore(repository: storage, catalog: SystemCatalog(source: FixedSystemSource()), observeMenus: false)
    }

    @MainActor
    func testInitializationDoesNotStartHiddenIOAndLoadIsIdempotentWhileSuspended() async {
        let gate = OperationGate()
        let storage = MemorySnippets(loadGate: gate)
        let model = store(storage)
        XCTAssertEqual(model.loadState, .idle)
        XCTAssertFalse(model.canEdit)
        let initialLoads = await storage.loads
        XCTAssertEqual(initialLoads, 0)
        let loading = Task { await model.loadIfNeeded() }
        await gate.waitUntilEntered()
        XCTAssertEqual(model.loadState, .loading)
        await model.loadIfNeeded()
        await gate.release()
        await loading.value
        XCTAssertEqual(model.loadState, .ready)
        XCTAssertTrue(model.canEdit)
        await model.loadIfNeeded()
        let loads = await storage.loads
        XCTAssertEqual(loads, 1)
    }

    @MainActor
    func testFailedLoadPreventsOverwriteAndRetryRestoresEditing() async {
        let storage = MemorySnippets()
        await storage.setFailures(load: true)
        let model = store(storage)
        await model.loadIfNeeded()
        guard case .failed = model.loadState else { return XCTFail("Expected explicit failed state") }
        let saved = await model.save(Snippet(title: "Draft", content: "Keep me"))
        XCTAssertFalse(saved)
        XCTAssertFalse(model.canEdit)
        let writes = await storage.saves
        XCTAssertEqual(writes, 0)
        await storage.setFailures()
        await model.reload()
        XCTAssertEqual(model.loadState, .ready)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testFailedSaveKeepsPublishedLibrarySelectionAndDraftThenRetrySucceeds() async {
        let storage = MemorySnippets()
        let model = store(storage)
        await model.loadIfNeeded()
        let draft = Snippet(title: "Draft", content: "Unicode café 👋")
        await storage.setFailures(save: true)
        let failed = await model.save(draft)
        XCTAssertFalse(failed)
        XCTAssertTrue(model.snippets.isEmpty)
        XCTAssertNil(model.selection)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.loadState, .ready)
        await storage.setFailures()
        let saved = await model.save(draft)
        XCTAssertTrue(saved)
        XCTAssertEqual(model.selection, .snippet(draft.id))
        XCTAssertEqual(model.snippets.first?.content, draft.content)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testSaveMovesToVisibleScopeAndDeleteClearsSelectionAndIndex() async {
        let storage = MemorySnippets()
        let model = store(storage)
        await model.loadIfNeeded()
        model.scope = .favorites
        let draft = Snippet(title: "Plain", content: "Text")
        let saved = await model.save(draft)
        XCTAssertTrue(saved)
        XCTAssertEqual(model.scope, .all)
        XCTAssertEqual(model.snippetCount(in: .all), 1)
        await model.delete(draft)
        XCTAssertNil(model.selection)
        XCTAssertEqual(model.snippetCount(in: .all), 0)
        XCTAssertTrue(model.filteredSnippets(scope: .all).isEmpty)
    }

    @MainActor
    func testSavingInvalidatesSearchResultsAndPreservesOnlyMatchingTagScope() async {
        let parent = SnippetTag(name: "Development")
        let child = SnippetTag(name: "Git", parentID: parent.id)
        var snippet = Snippet(title: "Original", content: "Text", tagIDs: [child.id])
        let model = store(MemorySnippets(SnippetLibrary(snippets: [snippet], tags: [parent, child])))
        await model.loadIfNeeded()
        model.scope = .tag(parent.id)
        XCTAssertEqual(model.filteredSnippets(scope: model.scope, query: "Original").map(\.id), [snippet.id])

        snippet.title = "Updated"
        let edited = await model.save(snippet)
        XCTAssertTrue(edited)
        XCTAssertEqual(model.scope, .tag(parent.id))
        XCTAssertEqual(model.selection, .snippet(snippet.id))
        XCTAssertTrue(model.filteredSnippets(scope: model.scope, query: "Original").isEmpty)
        XCTAssertEqual(model.filteredSnippets(scope: model.scope, query: "Updated").map(\.id), [snippet.id])

        snippet.tagIDs = []
        let untagged = await model.save(snippet)
        XCTAssertTrue(untagged)
        XCTAssertEqual(model.scope, .all)
        XCTAssertEqual(model.selection, .snippet(snippet.id))
        XCTAssertTrue(model.filteredSnippets(scope: .tag(parent.id)).isEmpty)
        XCTAssertEqual(model.snippetCount(in: .untagged), 1)
    }

    @MainActor
    func testShutdownDrainWaitsForPublicationEvenWhenSaveCallerIsCancelled() async {
        let gate = OperationGate()
        let storage = MemorySnippets(saveGate: gate)
        let model = store(storage)
        await model.loadIfNeeded()
        let draft = Snippet(title: "Durable", content: "Pending save")
        let saving = Task { await model.save(draft) }
        await gate.waitUntilEntered()
        XCTAssertTrue(model.hasPendingWrites)
        XCTAssertTrue(model.snippets.isEmpty)
        saving.cancel()
        let draining = Task { await model.finishPendingWrites() }
        await gate.release()
        await draining.value
        let saved = await saving.value
        XCTAssertTrue(saved)
        XCTAssertFalse(model.hasPendingWrites)
        XCTAssertEqual(model.snippets.first?.id, draft.id)
        let disk = await storage.value
        XCTAssertEqual(disk, model.library)
    }

    @MainActor
    func testInjectedSystemProviderDeterminesPreviewWithoutReadingTheMac() {
        let model = store(MemorySnippets())
        XCTAssertEqual(model.systemItems.first { $0.action == .computerName }?.value, "Test Mac")
        XCTAssertEqual(model.refreshSystem().items.first { $0.action == .utcTimestamp }?.value, "1970-01-01T00:00:00Z")
    }

    @MainActor
    func testWordsLoadFailureCanRetryAndFailedSavePreservesCurrentAndHistory() async {
        let storage = MemoryWords()
        let model = WordStore(repository: storage)
        XCTAssertEqual(model.loadState, .idle)
        await storage.setFailures(load: true)
        await model.loadIfNeeded()
        guard case .failed = model.loadState else { return XCTFail("Expected failed load") }
        XCTAssertFalse(model.canEdit)
        await storage.setFailures()
        await model.reload()
        let added = await model.save(entry: nil, word: "Resilience", definition: "Recovering")
        XCTAssertTrue(added)
        let original = model.library
        let selection = model.selectedID
        await storage.setFailures(save: true)
        let failed = await model.save(entry: nil, word: "Serendipity", definition: "Happy discovery")
        XCTAssertFalse(failed)
        XCTAssertEqual(model.library, original)
        XCTAssertEqual(model.selectedID, selection)
        XCTAssertTrue(model.history.isEmpty)
        XCTAssertNotNil(model.errorMessage)
        await storage.setFailures()
        let retried = await model.save(entry: nil, word: "Serendipity", definition: "Happy discovery")
        XCTAssertTrue(retried)
        XCTAssertEqual(model.history.first?.word, "Resilience")
    }

    @MainActor
    func testWordReusePreservesHistoryAndDeleteUpdatesSelectionAndCaches() async throws {
        let model = WordStore(repository: MemoryWords())
        await model.loadIfNeeded()
        _ = await model.save(entry: nil, word: "First", definition: "One")
        let first = try XCTUnwrap(model.current)
        _ = await model.save(entry: nil, word: "Second", definition: "Two")
        await model.reuse(first)
        let reused = try XCTUnwrap(model.current)
        XCTAssertNotEqual(reused.id, first.id)
        XCTAssertEqual(reused.word, first.word)
        XCTAssertEqual(model.history.count, 2)
        XCTAssertEqual(model.selectedID, reused.id)
        await model.delete(reused)
        XCTAssertNil(model.current)
        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.history.count, 2)
        await model.finishPendingWrites()
        XCTAssertFalse(model.hasPendingWrites)
    }
}
