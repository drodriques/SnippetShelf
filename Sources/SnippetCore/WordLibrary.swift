import Foundation

public struct WordEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var word: String
    public var definition: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), word: String, definition: String, createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.word = word
        self.definition = definition
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    public func matches(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty || word.localizedCaseInsensitiveContains(term)
            || definition.localizedCaseInsensitiveContains(term)
    }

    /// Bound menu-bar width by user-perceived characters, including emoji.
    public var menuBarTitle: String {
        word.count > 24 ? String(word.prefix(24)) + "…" : word
    }
}

/// One current identifier makes multiple simultaneous current words impossible.
public struct WordLibrary: Codable, Equatable, Sendable {
    public var version = 1
    public private(set) var entries: [WordEntry]
    public private(set) var currentID: UUID?

    public init(entries: [WordEntry] = [], currentID: UUID? = nil) {
        self.entries = entries
        self.currentID = currentID
    }

    public var current: WordEntry? { entries.first { $0.id == currentID } }
    public var history: [WordEntry] {
        entries.filter { $0.id != currentID }.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    @discardableResult
    public mutating func add(word: String, definition: String, at date: Date = Date()) throws -> UUID {
        var next = self
        let entry = WordEntry(word: word.trimmingCharacters(in: .whitespacesAndNewlines),
                              definition: definition.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: date)
        next.entries.append(entry)
        next.currentID = entry.id
        try next.validate()
        self = next
        return entry.id
    }

    /// Reusing starts a new occurrence; the historical record is never mutated.
    @discardableResult
    public mutating func reuse(id: UUID, at date: Date = Date()) throws -> UUID {
        guard id != currentID, let entry = entries.first(where: { $0.id == id }) else {
            throw LibraryError.invalid("Choose a past word to use as current.")
        }
        return try add(word: entry.word, definition: entry.definition, at: date)
    }

    public mutating func edit(id: UUID, word: String, definition: String, at date: Date = Date()) throws {
        var next = self
        guard let index = next.entries.firstIndex(where: { $0.id == id }) else {
            throw LibraryError.invalid("This word no longer exists.")
        }
        next.entries[index].word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        next.entries[index].definition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
        next.entries[index].updatedAt = date
        try next.validate()
        self = next
    }

    public mutating func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        if currentID == id { currentID = nil }
    }

    public func validate() throws {
        guard version == 1 else { throw LibraryError.invalid("The word history was saved by an unsupported app version.") }
        let ids = Set(entries.map(\.id))
        guard ids.count == entries.count, currentID.map({ ids.contains($0) }) ?? true else {
            throw LibraryError.invalid("The word history contains invalid or duplicate identifiers.")
        }
        for entry in entries {
            guard !entry.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !entry.definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  entry.word.rangeOfCharacter(from: .newlines) == nil else {
                throw LibraryError.invalid("Enter a word on one line and a nonempty definition.")
            }
            guard entry.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  entry.updatedAt.timeIntervalSinceReferenceDate.isFinite else {
                throw LibraryError.invalid("The word history contains an invalid date.")
            }
        }
    }
}
