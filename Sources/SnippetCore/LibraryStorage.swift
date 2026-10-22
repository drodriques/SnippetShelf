import Foundation

/// Injectable persistence boundaries; implementations own their serialization.
public protocol SnippetPersisting: Sendable {
    func load() async throws -> SnippetLibrary
    func save(_ library: SnippetLibrary) async throws
}

public protocol WordPersisting: Sendable {
    func load() async throws -> WordLibrary
    func save(_ library: WordLibrary) async throws
}

/// File parsing, validation, encoding and atomic writes run on serial actor executors.
/// These workers never publish UI state or bypass repository safeguards.
public actor SnippetStorage: SnippetPersisting {
    private let repository: SnippetRepository
    public init(fileURL: URL) { repository = SnippetRepository(fileURL: fileURL) }
    public func load() throws -> SnippetLibrary { try repository.loadLibrary() }
    public func save(_ library: SnippetLibrary) throws { try repository.saveLibrary(library) }
}

public actor WordStorage: WordPersisting {
    private let repository: WordRepository
    public init(fileURL: URL) { repository = WordRepository(fileURL: fileURL) }
    public func load() throws -> WordLibrary { try repository.load() }
    public func save(_ library: WordLibrary) throws { try repository.save(library) }
}
