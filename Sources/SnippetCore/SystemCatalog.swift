import Foundation

public struct SystemCatalog {
    private let source: any SystemDataSource
    public init(source: any SystemDataSource = MacSystemDataSource()) { self.source = source }

    public func snapshot(favorites: Set<SystemAction> = []) -> SystemSnapshot {
        var items: [SystemItem] = []
        var networkMessage: String?
        do {
            let addresses = try source.networkAddresses()
            let groups = Dictionary(grouping: addresses) {
                SystemAction.network(interface: $0.interface, family: $0.family)
            }
            for (action, values) in groups {
                guard let first = values.first else { continue }
                let unique = Set(values.map(\.address)).sorted()
                let family = first.family == .ipv4 ? "IPv4" : "IPv6"
                items.append(SystemItem(action: action,
                    title: "\(first.displayName) (\(first.interface)) · \(family)",
                    value: unique.joined(separator: "\n"),
                    explanation: unique.count > 1
                        ? "Copies all \(family) addresses on this connection, one per line. These are local interface addresses; an IPv6 address may also be globally routable."
                        : "The \(family) address on this connection. This reads the local interface; it does not look up your public IP."))
            }
            if groups.isEmpty { networkMessage = "No active network address" }
        } catch {
            networkMessage = "Network addresses could not be read. Try refreshing."
        }
        let present = Set(items.map(\.action))
        for action in favorites.subtracting(present) {
            if case .network(let interface, let family) = action {
                items.append(SystemItem(action: action,
                    title: "\(interface) · \(family == .ipv4 ? "IPv4" : "IPv6")",
                    value: nil, explanation: "This favorite follows its connection when its address changes.",
                    unavailableReason: networkMessage ?? "This connection has no active address."))
            }
        }
        items.sort {
            // Put ordinary Wi-Fi/Ethernet connections before auxiliary interfaces.
            let firstRank = connectionRank($0.action)
            let secondRank = connectionRank($1.action)
            if firstRank != secondRank { return firstRank < secondRank }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        let name = source.computerName()
        items.append(SystemItem(action: .computerName, title: "Computer Name", value: name,
            explanation: "The computer name configured in macOS.",
            unavailableReason: name?.isEmpty == false ? nil : "Computer name is unavailable."))
        items.append(SystemItem(action: .macOSVersion, title: "macOS Version", value: source.macOSVersion(),
            explanation: "The macOS version currently running on this Mac."))
        let date = source.now()
        let zone = source.timeZone()
        let localDate = DateFormatter()
        localDate.locale = Locale(identifier: "en_US_POSIX")
        localDate.calendar = Calendar(identifier: .gregorian)
        localDate.timeZone = zone
        localDate.dateFormat = "yyyy-MM-dd"
        items.append(SystemItem(action: .localDate, title: "Local Date", value: localDate.string(from: date),
            explanation: "Today's date in your current time zone, formatted YYYY-MM-DD."))
        let localTime = DateFormatter()
        localTime.locale = source.locale()
        localTime.timeZone = zone
        localTime.dateStyle = .medium
        localTime.timeStyle = .medium
        items.append(SystemItem(action: .localDateTime, title: "Local Date & Time",
            value: localTime.string(from: date) + " " + (zone.abbreviation(for: date) ?? zone.identifier),
            explanation: "Date and time using your Mac's region and time zone, including its zone label."))
        let utc = ISO8601DateFormatter()
        utc.timeZone = TimeZone(secondsFromGMT: 0)
        utc.formatOptions = [.withInternetDateTime]
        items.append(SystemItem(action: .utcTimestamp, title: "UTC Timestamp", value: utc.string(from: date),
            explanation: "An ISO 8601 timestamp in UTC, ending in Z."))
        return SystemSnapshot(items: items, networkMessage: networkMessage)
    }

    private func connectionRank(_ action: SystemAction) -> Int {
        if case .network(let interface, _) = action, interface.hasPrefix("en") { return 0 }
        return 1
    }

    /// Each copy resolves again instead of returning a cached preview value.
    public func resolve(_ action: SystemAction) -> SystemItem? {
        snapshot(favorites: [action]).items.first { $0.action == action }
    }
}
