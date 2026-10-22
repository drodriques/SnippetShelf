import Foundation

public enum SystemGroup: String, CaseIterable, Codable, Hashable, Identifiable {
    case network, device, dateTime
    public var id: Self { self }
    public var title: String {
        switch self {
        case .network: return "Network"
        case .device: return "Device"
        case .dateTime: return "Date & Time"
        }
    }
    public var icon: String {
        switch self {
        case .network: return "network"
        case .device: return "desktopcomputer"
        case .dateTime: return "calendar"
        }
    }
}

public enum IPFamily: String, Codable, Hashable, Sendable { case ipv4, ipv6 }

/// Network favorites refer to a connection and family, never to a stale address.
public enum SystemAction: Codable, Hashable, Identifiable, Sendable {
    case network(interface: String, family: IPFamily)
    case computerName, macOSVersion, localDate, localDateTime, utcTimestamp
    public var id: Self { self }
    public var group: SystemGroup {
        switch self {
        case .network: return .network
        case .computerName, .macOSVersion: return .device
        case .localDate, .localDateTime, .utcTimestamp: return .dateTime
        }
    }
    public var copyLabel: String {
        switch self {
        case .network: return "Copy IP Address"
        case .computerName: return "Copy Computer Name"
        case .macOSVersion: return "Copy macOS Version"
        case .localDate: return "Copy Date"
        case .localDateTime: return "Copy Local Date & Time"
        case .utcTimestamp: return "Copy UTC Timestamp"
        }
    }
}

public struct SystemItem: Identifiable, Equatable {
    public let action: SystemAction
    public let title: String
    public let value: String?
    public let explanation: String
    public let unavailableReason: String?
    public var id: SystemAction { action }
    public var group: SystemGroup { action.group }
    public var isAvailable: Bool { value?.isEmpty == false }
    public var copyLabel: String {
        if case .network = action, value?.contains("\n") == true { return "Copy IP Addresses" }
        return action.copyLabel
    }

    public init(action: SystemAction, title: String, value: String?, explanation: String,
                unavailableReason: String? = nil) {
        self.action = action
        self.title = title
        self.value = value
        self.explanation = explanation
        self.unavailableReason = unavailableReason
    }
}

public struct NetworkAddress: Equatable {
    public let interface: String
    public let displayName: String
    public let family: IPFamily
    public let address: String
    public init(interface: String, displayName: String, family: IPFamily, address: String) {
        self.interface = interface
        self.displayName = displayName
        self.family = family
        self.address = address
    }
}

public protocol SystemDataSource {
    func networkAddresses() throws -> [NetworkAddress]
    func computerName() -> String?
    func macOSVersion() -> String
    func now() -> Date
    func timeZone() -> TimeZone
    func locale() -> Locale
}

public struct SystemSnapshot {
    public let items: [SystemItem]
    public let networkMessage: String?
}
