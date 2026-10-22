import Foundation

/// Independent of snippet storage. Invalid or newer files are never overwritten.
public struct WordRepository {
    public let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> WordLibrary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return WordLibrary() }
        let library = try JSONDecoder().decode(WordLibrary.self, from: Data(contentsOf: fileURL))
        try library.validate()
        return library
    }

    public func save(_ library: WordLibrary) throws {
        try library.validate()
        if FileManager.default.fileExists(atPath: fileURL.path) { _ = try load() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}
