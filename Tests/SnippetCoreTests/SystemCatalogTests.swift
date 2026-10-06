import XCTest
@testable import SnippetCore

private final class TestSystemSource: SystemDataSource {
    var addresses: [NetworkAddress] = []
    var failsNetwork = false
    var name: String? = "Test Mac"
    var date = ISO8601DateFormatter().date(from: "2026-10-06T02:03:04Z")!
    var zone = TimeZone(identifier: "America/New_York")!
    func networkAddresses() throws -> [NetworkAddress] {
        if failsNetwork { throw LibraryError.invalid("Fixture failure") }
        return addresses
    }
    func computerName() -> String? { name }
    func macOSVersion() -> String { "macOS 15.0.1" }
    func now() -> Date { date }
    func timeZone() -> TimeZone { zone }
    func locale() -> Locale { Locale(identifier: "en_US") }
}

final class SystemCatalogTests: XCTestCase {
    func testNetworkConnectionsAndFamiliesHaveDistinctStableActions() throws {
        let source = TestSystemSource()
        source.addresses = [
            NetworkAddress(interface: "en0", displayName: "Wi-Fi", family: .ipv4, address: "192.0.2.10"),
            NetworkAddress(interface: "en1", displayName: "Ethernet", family: .ipv4, address: "192.0.2.11"),
            NetworkAddress(interface: "en0", displayName: "Wi-Fi", family: .ipv6, address: "2001:db8::1"),
            NetworkAddress(interface: "en0", displayName: "Wi-Fi", family: .ipv6, address: "2001:db8::2"),
            NetworkAddress(interface: "en0", displayName: "Wi-Fi", family: .ipv6, address: "2001:db8::1")
        ]
        let snapshot = SystemCatalog(source: source).snapshot()
        let network = snapshot.items.filter { $0.group == .network }
        XCTAssertEqual(network.count, 3)
        XCTAssertEqual(Set(network.map(\.id)).count, 3)
        let ipv6 = try XCTUnwrap(network.first { $0.action == .network(interface: "en0", family: .ipv6) })
        XCTAssertEqual(ipv6.value, "2001:db8::1\n2001:db8::2")
        XCTAssertTrue(ipv6.title.contains("Wi-Fi (en0)"))
        XCTAssertTrue(ipv6.explanation.contains("one per line"))
        XCTAssertEqual(ipv6.copyLabel, "Copy IP Addresses")
        XCTAssertNil(snapshot.networkMessage)
    }

    func testResolvingCopiesFreshAddressAndTimeInsteadOfPreview() throws {
        let source = TestSystemSource()
        let action = SystemAction.network(interface: "en0", family: .ipv4)
        source.addresses = [NetworkAddress(interface: "en0", displayName: "Wi-Fi", family: .ipv4, address: "192.0.2.10")]
        let catalog = SystemCatalog(source: source)
        let preview = catalog.snapshot(favorites: [action])
        source.addresses = [NetworkAddress(interface: "en0", displayName: "Wi-Fi", family: .ipv4, address: "192.0.2.20")]
        XCTAssertEqual(catalog.resolve(action)?.value, "192.0.2.20")
        XCTAssertEqual(preview.items.first { $0.id == action }?.value, "192.0.2.10")
        source.date.addTimeInterval(10)
        XCTAssertEqual(catalog.resolve(.utcTimestamp)?.value, "2026-10-06T02:03:14Z")
    }

    func testDateFormatsUseLocalZoneAndUTCUnambiguously() {
        let source = TestSystemSource()
        let catalog = SystemCatalog(source: source)
        XCTAssertEqual(catalog.resolve(.localDate)?.value, "2026-10-05")
        XCTAssertEqual(catalog.resolve(.utcTimestamp)?.value, "2026-10-06T02:03:04Z")
        XCTAssertTrue(catalog.resolve(.localDateTime)?.value?.hasSuffix("EDT") == true)
        source.zone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(catalog.resolve(.localDate)?.value, "2026-10-06")
    }

    func testDisconnectedFavoritesRemainVisibleWithoutStaleValues() {
        let source = TestSystemSource()
        let action = SystemAction.network(interface: "en0", family: .ipv4)
        let snapshot = SystemCatalog(source: source).snapshot(favorites: [action])
        let unavailable = snapshot.items.first { $0.id == action }
        XCTAssertEqual(snapshot.networkMessage, "No active network address")
        XCTAssertNotNil(unavailable)
        XCTAssertNil(unavailable?.value)
        XCTAssertFalse(unavailable?.isAvailable ?? true)
        XCTAssertNotNil(unavailable?.unavailableReason)
        XCTAssertEqual(snapshot.items.filter { $0.group == .device }.count, 2)
        XCTAssertEqual(snapshot.items.filter { $0.group == .dateTime }.count, 3)
    }

    func testNetworkReadFailureAndMissingComputerNameLeaveOtherActionsUsable() {
        let source = TestSystemSource()
        source.failsNetwork = true
        source.name = nil
        let catalog = SystemCatalog(source: source)
        let snapshot = catalog.snapshot()
        XCTAssertNotNil(snapshot.networkMessage)
        XCTAssertFalse(catalog.resolve(.computerName)?.isAvailable ?? true)
        XCTAssertEqual(catalog.resolve(.macOSVersion)?.value, "macOS 15.0.1")
        XCTAssertTrue(catalog.resolve(.utcTimestamp)?.isAvailable == true)
    }

    func testSystemFavoritesPersistWithoutAddingSavedSnippetsOrTags() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SnippetRepository(fileURL: directory.appendingPathComponent("snippets.json"))
        let snippet = Snippet(title: "Saved", content: "Text")
        let library = SnippetLibrary(snippets: [snippet], systemFavorites: [.localDate,
            .network(interface: "en0", family: .ipv4)])
        try repository.saveLibrary(library)
        XCTAssertEqual(try repository.loadLibrary(), library)
        XCTAssertEqual(library.filtered(scope: .all), [snippet])
        XCTAssertEqual(library.filtered(scope: .untagged), [snippet])
        XCTAssertTrue(library.filtered(scope: .favorites).isEmpty)
        XCTAssertTrue(library.filtered(scope: .system(.device)).isEmpty)
        XCTAssertTrue(library.tags.isEmpty)
    }

    func testVersionOneMigrationBacksUpLibraryAndKeepsTagsAndSnippets() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = SnippetRepository(fileURL: directory.appendingPathComponent("snippets.json"))
        let tag = SnippetTag(name: "Work")
        let snippet = Snippet(title: "Email", content: "Hello", tagIDs: [tag.id])
        let original = SnippetLibrary(snippets: [snippet], tags: [tag])
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        raw["version"] = 1
        raw.removeValue(forKey: "systemFavorites")
        let oldData = try JSONSerialization.data(withJSONObject: raw)
        try oldData.write(to: repository.fileURL)
        var migrated = try repository.loadLibrary()
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(migrated.snippets, [snippet])
        XCTAssertEqual(migrated.tags, [tag])
        XCTAssertTrue(migrated.systemFavorites.isEmpty)
        migrated.systemFavorites = [.computerName]
        try repository.saveLibrary(migrated)
        let backup = directory.appendingPathComponent("snippets.v1-backup.json")
        XCTAssertEqual(try Data(contentsOf: backup), oldData)
        XCTAssertEqual(try repository.loadLibrary(), migrated)
        migrated.systemFavorites = [.macOSVersion]
        try repository.saveLibrary(migrated)
        XCTAssertEqual(try Data(contentsOf: backup), oldData)
    }
}
