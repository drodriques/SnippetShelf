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
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let library: SnippetLibrary
        if try JSONSerialization.jsonObject(with: data) is [Any] {
            library = SnippetLibrary(snippets: try decoder.decode([Snippet].self, from: data))
        } else {
            library = try decoder.decode(SnippetLibrary.self, from: data)
        }
        try library.validate()
        return library
    }

    public func saveLibrary(_ library: SnippetLibrary) throws {
        try library.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Never replace an unreadable library, even if called outside the app store.
            _ = try loadLibrary()
            let previous = try Data(contentsOf: fileURL)
            if try JSONSerialization.jsonObject(with: previous) is [Any],
               !FileManager.default.fileExists(atPath: legacyBackupURL.path) {
                try previous.write(to: legacyBackupURL, options: .atomic)
            }
            if let oldDocument = try JSONSerialization.jsonObject(with: previous) as? [String: Any],
               oldDocument["version"] as? Int == 1 {
                let backup = fileURL.deletingLastPathComponent().appendingPathComponent("snippets.v1-backup.json")
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
