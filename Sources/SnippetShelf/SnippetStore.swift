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
    @Published var scope: LibraryScope = .all
    @Published var selection: LibrarySelection?
    @Published private(set) var systemItems: [SystemItem] = []
    @Published private(set) var networkMessage: String?
    private let catalog = SystemCatalog()
    private var menuObserver: NSObjectProtocol?
    @Published var wantsNewSnippet = false
    @Published var errorMessage: String?
    @Published var notice: String?
    private let repository: SnippetRepository
    private var loadSucceeded = false

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask)[0]
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "SnippetShelf"
        repository = SnippetRepository(fileURL: directory
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("snippets.json"))
        reload()
        refreshSystem()
        // Observe native menu tracking even when the desktop window is closed.
        menuObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshSystem() }
        }
    }

    deinit {
        if let menuObserver { NotificationCenter.default.removeObserver(menuObserver) }
    }

    func reload() {
        do {
            library = try repository.loadLibrary()
            loadSucceeded = true
            errorMessage = nil
        } catch {
            loadSucceeded = false
            errorMessage = "Could not read your snippets. Your saved file has been left untouched. \(error.localizedDescription)"
        }
    }

    /// Publish only after a successful write so the two interfaces stay consistent.
    @discardableResult
    func save(_ snippet: Snippet) -> Bool {
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
        guard commit(next) else { return false }
        if !library.filtered(scope: scope).contains(where: { $0.id == edited.id }) { scope = .all }
        selection = .snippet(edited.id)
        notice = "Snippet saved"
        return true
    }

    func delete(_ snippet: Snippet) {
        var next = library
        next.snippets.removeAll { $0.id == snippet.id }
        guard commit(next) else { return }
        if selection == .snippet(snippet.id) { selection = nil }
        notice = "Snippet deleted"
    }

    @discardableResult
    func saveTag(_ tag: SnippetTag) -> Bool {
        var next = library
        do {
            try next.saveTag(tag)
            guard commit(next) else { return false }
            notice = "Tag saved"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteTag(_ tag: SnippetTag) {
        var next = library
        let removed = library.subtreeIDs(of: tag.id)
        next.deleteTag(tag.id)
        guard commit(next) else { return }
        if case .tag(let id) = scope, removed.contains(id) { scope = .all }
        notice = "Tag deleted; snippets kept"
    }

    func refreshSystem() {
        let snapshot = catalog.snapshot(favorites: library.systemFavorites)
        systemItems = snapshot.items
        networkMessage = snapshot.networkMessage
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

    func toggleSystemFavorite(_ action: SystemAction) {
        var next = library
        if next.systemFavorites.contains(action) { next.systemFavorites.remove(action) }
        else { next.systemFavorites.insert(action) }
        guard commit(next) else { return }
        refreshSystem()
        notice = next.systemFavorites.contains(action) ? "Added to Favorites" : "Removed from Favorites"
    }

    func copySystem(_ action: SystemAction) {
        let item = catalog.resolve(action)
        guard let item, let value = item.value, !value.isEmpty else {
            refreshSystem()
            notice = item?.unavailableReason ?? "This system value is unavailable."
            return
        }
        refreshSystem()
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

    private func commit(_ next: SnippetLibrary) -> Bool {
        guard loadSucceeded else {
            errorMessage = "Saving is disabled because the saved file could not be read. Restore a valid snippets.json backup, then choose Retry Loading."
            return false
        }
        do {
            try repository.saveLibrary(next)
            library = next
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Could not save your changes. \(error.localizedDescription)"
            return false
        }
    }
}
