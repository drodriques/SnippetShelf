import AppKit
import SwiftUI
import SnippetCore

enum LibrarySelection: Hashable {
    case snippet(UUID)
    case system(SystemAction)
}

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var library = SnippetLibrary()
    var snippets: [Snippet] { library.snippets }
    private(set) var index = LibraryIndex(library: SnippetLibrary())
    private var cachedResults: (scope: LibraryScope, query: String, snippets: [Snippet])?
    private var refreshScheduled = false
    private var lastSystemRefresh = -Double.infinity
    @Published var scope: LibraryScope = .all
    @Published var selection: LibrarySelection?
    @Published private(set) var systemItems: [SystemItem] = []
    @Published private(set) var networkMessage: String?
    private let catalog: SystemCatalog
    private var menuObserver: MainActorNotification?
    @Published var wantsNewSnippet = false
    @Published var errorMessage: String?
    @Published var notice: String?
    private let repository: any SnippetPersisting
    private let mutations = AsyncMutationQueue()
    @Published private(set) var loadState: LibraryLoadState = .idle
    var canEdit: Bool { loadState.canEdit }

    init(repository: any SnippetPersisting = SnippetStorage(fileURL: AppStorageLocation.file("snippets.json")),
         catalog: SystemCatalog = SystemCatalog(), observeMenus: Bool = true) {
        self.repository = repository
        self.catalog = catalog
        refreshSystem()
        // Observe native menu tracking even when the desktop window is closed.
        guard observeMenus else { return }
        menuObserver = MainActorNotification(NSMenu.didBeginTrackingNotification) { [weak self] notification in
            // Other app menus (Edit, Window, context menus) need no system reads.
            guard let menu = notification.object as? NSMenu,
                  NativeMenuCompatibility.isQuickMenu(menu) else { return }
            Task { @MainActor in self?.requestSystemRefresh() }
        }
    }

    var hasPendingWrites: Bool { mutations.hasPendingOperations }
    func finishPendingWrites() async { await mutations.finishPendingOperations() }

    /// Called by the scene task, not implicitly from initialization.
    func loadIfNeeded() async {
        guard loadState == .idle else { return }
        loadState = .loading
        await reload()
    }

    func reload() async {
        await mutations.run { [self] in
            loadState = .loading
            do {
                applyLibrary(try await repository.load())
                loadState = .ready
                errorMessage = nil
            } catch {
                let message = "Could not read your snippets. Your saved file has been left untouched. \(error.localizedDescription)"
                loadState = .failed(message)
                errorMessage = message
            }
        }
    }

    /// Publish only after a successful write so the two interfaces stay consistent.
    @discardableResult
    func save(_ snippet: Snippet) async -> Bool {
        await mutations.run { [self] in
            var next = library
            var edited = snippet
            edited.title = edited.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !edited.title.isEmpty else { return false }
            edited.tagIDs.formIntersection(Set(library.tags.map(\.id)))
            edited.updatedAt = Date()
            if let index = next.snippets.firstIndex(where: { $0.id == edited.id }) {
                next.snippets[index] = edited
            } else {
                next.snippets.append(edited)
            }
            guard await commit(next) else { return false }
            // Reuse this sorted result when the visible list renders after saving.
            if !filteredSnippets(scope: scope).contains(where: { $0.id == edited.id }) { scope = .all }
            selection = .snippet(edited.id)
            notice = "Snippet saved"
            return true
        }
    }

    func delete(_ snippet: Snippet) async {
        await mutations.run { [self] in
            var next = library
            next.snippets.removeAll { $0.id == snippet.id }
            guard await commit(next) else { return }
            if selection == .snippet(snippet.id) { selection = nil }
            notice = "Snippet deleted"
        }
    }

    @discardableResult
    func saveTag(_ tag: SnippetTag) async -> Bool {
        await mutations.run { [self] in
            var next = library
            do {
                try next.saveTag(tag)
                guard await commit(next) else { return false }
                notice = "Tag saved"
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
    }

    func deleteTag(_ tag: SnippetTag) async {
        await mutations.run { [self] in
            var next = library
            let removed = library.subtreeIDs(of: tag.id)
            next.deleteTag(tag.id)
            guard await commit(next) else { return }
            if case .tag(let id) = scope, removed.contains(id) { scope = .all }
            notice = "Tag deleted; snippets kept"
        }
    }

    /// Coalesce preview requests; explicit Refresh and Copy bypass this throttle.
    func requestSystemRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshScheduled = false
            if ProcessInfo.processInfo.systemUptime - self.lastSystemRefresh >= 0.5 {
                self.refreshSystem()
            }
        }
    }

    @discardableResult
    func refreshSystem(including action: SystemAction? = nil) -> SystemSnapshot {
        var favorites = library.systemFavorites
        if let action { favorites.insert(action) }
        let snapshot = catalog.snapshot(favorites: favorites)
        lastSystemRefresh = ProcessInfo.processInfo.systemUptime
        if snapshot.items != systemItems { systemItems = snapshot.items }
        if snapshot.networkMessage != networkMessage { networkMessage = snapshot.networkMessage }
        return snapshot
    }

    func snippetCount(in scope: LibraryScope) -> Int {
        index.counts[scope, default: 0] + systemItems.reduce(into: 0) { count, item in
            switch scope {
            case .system(let group): if item.group == group { count += 1 }
            case .favorites: if library.systemFavorites.contains(item.action) { count += 1 }
            default: break
            }
        }
    }

    func tagPath(for id: UUID) -> String { index.paths[id] ?? "" }

    /// One bounded cache for the currently rendered list, never a cache per keystroke.
    func filteredSnippets(scope: LibraryScope, query: String = "") -> [Snippet] {
        if let cachedResults, cachedResults.scope == scope, cachedResults.query == query {
            return cachedResults.snippets
        }
        let result = library.filtered(scope: scope, query: query)
        cachedResults = (scope, query, result)
        return result
    }

    private func applyLibrary(_ next: SnippetLibrary) {
        if next.snippets != library.snippets || next.tags != library.tags {
            index = LibraryIndex(library: next)
            cachedResults = nil
        }
        if next != library { library = next }
    }

    func systemItems(in scope: LibraryScope, query: String = "") -> [SystemItem] {
        let items: [SystemItem]
        switch scope {
        case .system(let group): items = systemItems.filter { $0.group == group }
        case .favorites: items = systemItems.filter { library.systemFavorites.contains($0.action) }
        default: items = []
        }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter {
            term.isEmpty || $0.title.localizedCaseInsensitiveContains(term)
                || ($0.value?.localizedCaseInsensitiveContains(term) ?? false)
        }
    }

    func toggleSystemFavorite(_ action: SystemAction) async {
        await mutations.run { [self] in
            var next = library
            if next.systemFavorites.contains(action) { next.systemFavorites.remove(action) }
            else { next.systemFavorites.insert(action) }
            guard await commit(next) else { return }
            refreshSystem()
            notice = next.systemFavorites.contains(action) ? "Added to Favorites" : "Removed from Favorites"
        }
    }

    func copySystem(_ action: SystemAction) {
        // Resolve once, and use that same fresh snapshot for clipboard and preview.
        let snapshot = refreshSystem(including: action)
        let item = snapshot.items.first { $0.action == action }
        guard let item, let value = item.value, !value.isEmpty else {
            notice = item?.unavailableReason ?? "This system value is unavailable."
            return
        }
        copyText(value, title: item.title)
    }

    func copy(_ snippet: Snippet) {
        copyText(snippet.content, title: snippet.title)
    }

    private func copyText(_ text: String, title: String) {
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(text, forType: .string) {
            notice = "Copied \(title)"
        } else {
            errorMessage = "The snippet could not be copied. Please try again."
        }
    }

    private func commit(_ next: SnippetLibrary) async -> Bool {
        guard canEdit else {
            errorMessage = "Saving is disabled because the saved file could not be read. Restore a valid snippets.json backup, then choose Retry Loading."
            return false
        }
        do {
            try await repository.save(next)
            applyLibrary(next)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Could not save your changes. \(error.localizedDescription)"
            return false
        }
    }
}
