// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnippetShelf",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SnippetShelf", targets: ["SnippetShelf"])],
    targets: [
        .target(name: "SnippetCore"),
        .executableTarget(name: "SnippetShelf", dependencies: ["SnippetCore"]),
        .testTarget(name: "SnippetCoreTests", dependencies: ["SnippetCore"]),
        .testTarget(name: "SnippetShelfTests", dependencies: ["SnippetShelf", "SnippetCore"])
    ]
)
