import Foundation

/// Stores the complete library in one atomic write, including tag assignments.
public struct SnippetRepository {
    public let fileURL: URL
    public var legacyBackupURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("snippets.legacy-backup.json")
    }

    public init(fileURL: URL) { self.fileURL = fileURL }

    public func loadLibrary() throws -> SnippetLibrary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return SnippetLibrary() }
        return try Self.decode(Data(contentsOf: fileURL)).library
    }

    /// Inspect legacy format/version through the same decoder that reads the data.
    private struct Document: Decodable {
        let library: SnippetLibrary
        let backupName: String?
        private enum VersionKey: String, CodingKey { case version }

        init(from decoder: Decoder) throws {
            if var array = try? decoder.unkeyedContainer() {
                var snippets: [Snippet] = []
                while !array.isAtEnd { snippets.append(try array.decode(Snippet.self)) }
                library = SnippetLibrary(snippets: snippets)
                backupName = "snippets.legacy-backup.json"
            } else {
                let values = try decoder.container(keyedBy: VersionKey.self)
                let version = try values.decode(Int.self, forKey: .version)
                library = try SnippetLibrary(from: decoder)
                backupName = version == 1 ? "snippets.v1-backup.json" : nil
            }
        }
    }

    private static func decode(_ data: Data) throws -> Document {
        let document = try JSONDecoder().decode(Document.self, from: data)
        try document.library.validate()
        return document
    }

    public func saveLibrary(_ library: SnippetLibrary) throws {
        try library.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // One read/decoding pass validates the existing file and identifies
            // any migration backup. Never overwrite an unreadable/newer library.
            let previous = try Data(contentsOf: fileURL)
            let document = try Self.decode(previous)
            if let name = document.backupName {
                let backup = fileURL.deletingLastPathComponent().appendingPathComponent(name)
                if !FileManager.default.fileExists(atPath: backup.path) {
                    try previous.write(to: backup, options: .atomic)
                }
            }
        }

        try data.write(to: fileURL, options: .atomic)
    }

    public func load() throws -> [Snippet] { try loadLibrary().snippets }

    /// Preserves existing tags when replacing the snippet collection.
    public func save(_ snippets: [Snippet]) throws {
        var library = try loadLibrary()
        library.snippets = snippets
        try saveLibrary(library)
    }
}
