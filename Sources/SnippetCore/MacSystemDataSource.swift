import Foundation
import Darwin
import SystemConfiguration

/// Reads local OS information only. No requests, shell commands, or external tools.
public struct MacSystemDataSource: SystemDataSource {
    public init() {}
    public func now() -> Date { Date() }
    public func timeZone() -> TimeZone { .current }
    public func locale() -> Locale { .current }
    public func computerName() -> String? { SCDynamicStoreCopyComputerName(nil, nil) as String? }
    public func macOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    public func networkAddresses() throws -> [NetworkAddress] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else {
            throw LibraryError.invalid("Network addresses could not be read. Try refreshing.")
        }
        defer { if let first { freeifaddrs(first) } }
        var names: [String: String] = [:]
        if let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] {
            for interface in interfaces {
                if let bsd = SCNetworkInterfaceGetBSDName(interface) as String?,
                   let display = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? {
                    names[bsd] = display
                }
            }
        }
        var result: [NetworkAddress] = []
        var cursor = first
        while let current = cursor {
            let entry = current.pointee
            cursor = entry.ifa_next
            guard entry.ifa_flags & UInt32(IFF_UP) != 0,
                  entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                  let address = entry.ifa_addr, let name = entry.ifa_name else { continue }
            let family: IPFamily
            switch Int32(address.pointee.sa_family) {
            case AF_INET: family = .ipv4
            case AF_INET6: family = .ipv6
            default: continue
            }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &buffer,
                              socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let bsd = String(cString: name)
            let display = names[bsd] ?? (bsd.hasPrefix("utun") ? "Tunnel" : "Interface")
            let numericAddress = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            result.append(NetworkAddress(interface: bsd, displayName: display,
                                         family: family, address: numericAddress))
        }
        return result
    }
}
