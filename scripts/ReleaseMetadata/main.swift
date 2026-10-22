import Foundation

// Compiled with the same version model used by the app's tests.
do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 2 || arguments.count == 3,
          ["--check", "--sync"].contains(arguments[1]) else {
        throw NSError(domain: "Usage: release-metadata.sh --check [APP] | --sync", code: 2)
    }
    let root = URL(fileURLWithPath: arguments[0], isDirectory: true)
    let metadata = try JSONDecoder().decode(ReleaseMetadata.self,
        from: Data(contentsOf: root.appendingPathComponent("Resources/Version.json")))
    let version = try ReleaseVersion(metadata.version)
    let target = arguments.count == 3
        ? URL(fileURLWithPath: arguments[2]).appendingPathComponent("Contents/Info.plist")
        : root.appendingPathComponent("Resources/Info.plist")
    guard var plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: target), format: nil) as? [String: Any] else {
        throw NSError(domain: "Bundle metadata must be a dictionary", code: 1)
    }
    let expected = ["CFBundleShortVersionString": version.core,
                    "CFBundleVersion": String(metadata.build),
                    "SnippetShelfReleaseVersion": metadata.version]
    if arguments[1] == "--sync" {
        guard arguments.count == 2 else { throw NSError(domain: "Sync only updates source metadata", code: 2) }
        for (key, value) in expected { plist[key] = value }
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: target, options: .atomic)
    } else {
        for (key, value) in expected where plist[key] as? String != value {
            throw NSError(domain: "Version mismatch for \(key). Run scripts/release-metadata.sh --sync before building.", code: 1)
        }
    }
    print("\(metadata.version) (build \(metadata.build)) metadata verified")
} catch {
    FileHandle.standardError.write(Data("Release metadata error: \(error)\n".utf8))
    exit(1)
}
