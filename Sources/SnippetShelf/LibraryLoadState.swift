import Foundation

/// Loading and persistence permission have one source of truth.
enum LibraryLoadState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)

    var canEdit: Bool { self == .ready }
}

/// Keep production storage paths out of stores and test fixtures.
enum AppStorageLocation {
    static func file(_ name: String) -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "SnippetShelf"
        return directory.appendingPathComponent(appName, isDirectory: true).appendingPathComponent(name)
    }
}
