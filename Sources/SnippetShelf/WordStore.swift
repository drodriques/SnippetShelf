import SwiftUI
import AppKit
import SnippetCore

struct WordDraft: Identifiable {
    let id = UUID()
    let entry: WordEntry?
}

@MainActor
final class WordStore: ObservableObject {
    @Published private(set) var library = WordLibrary()
    private(set) var current: WordEntry?
    private(set) var history: [WordEntry] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var loadState: LibraryLoadState = .idle
    var canEdit: Bool { loadState.canEdit }
    @Published var selectedID: UUID?
    @Published var draft: WordDraft?
    private let repository: any WordPersisting
    private let mutations = AsyncMutationQueue()

    init(repository: any WordPersisting = WordStorage(fileURL: AppStorageLocation.file("words.json"))) {
        self.repository = repository
    }

    var hasPendingWrites: Bool { mutations.hasPendingOperations }
    func finishPendingWrites() async { await mutations.finishPendingOperations() }

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
                if !library.entries.contains(where: { $0.id == selectedID }) { selectedID = library.currentID }
            } catch {
                let message = "Could not read your word history. The saved file has been left untouched. \(error.localizedDescription)"
                loadState = .failed(message)
                errorMessage = message
            }
        }
    }

    @discardableResult
    func save(entry: WordEntry?, word: String, definition: String) async -> Bool {
        await mutations.run { [self] in
            guard canEdit else { return false }
            do {
                var next = library
                let selected: UUID
                if let entry {
                    try next.edit(id: entry.id, word: word, definition: definition)
                    selected = entry.id
                } else {
                    selected = try next.add(word: word, definition: definition)
                }
                try await repository.save(next)
                applyLibrary(next)
                selectedID = selected
                errorMessage = nil
                return true
            } catch {
                errorMessage = "Could not save your word. \(error.localizedDescription)"
                return false
            }
        }
    }

    func reuse(_ entry: WordEntry) async {
        await mutations.run { [self] in
            guard canEdit else { return }
            do {
                var next = library
                let id = try next.reuse(id: entry.id)
                try await repository.save(next)
                applyLibrary(next)
                selectedID = id
                errorMessage = nil
            } catch {
                errorMessage = "Could not reuse this word. \(error.localizedDescription)"
            }
        }
    }

    func delete(_ entry: WordEntry) async {
        await mutations.run { [self] in
            guard canEdit else { return }
            var next = library
            next.delete(id: entry.id)
            do {
                try await repository.save(next)
                applyLibrary(next)
                if selectedID == entry.id { selectedID = next.currentID }
                errorMessage = nil
            } catch {
                errorMessage = "Could not delete your word. \(error.localizedDescription)"
            }
        }
    }

    private func applyLibrary(_ next: WordLibrary) {
        guard next != library else { return }
        current = next.current
        history = next.history
        library = next
    }

    func copy(_ entry: WordEntry, includeDefinition: Bool = false) {
        NSPasteboard.general.clearContents()
        if !NSPasteboard.general.setString(includeDefinition ? "\(entry.word)\n\(entry.definition)" : entry.word, forType: .string) {
            errorMessage = "The word could not be copied. Please try again."
        }
    }
}
