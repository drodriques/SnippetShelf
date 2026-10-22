import Foundation

/// Public release identity is independent of saved-data schema versions.
public struct ReleaseVersion: Equatable, Sendable {
    public let value: String
    public let core: String
    public let isPrerelease: Bool

    public enum ValidationError: Error { case invalidVersion, invalidBuild }

    public init(_ value: String) throws {
        let number = "(0|[1-9][0-9]*)"
        let identifier = "(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
        let pattern = "^" + number + "\\." + number + "\\." + number
            + "(-" + identifier + "(\\." + identifier + ")*)?"
            + "(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"
        guard value.range(of: pattern, options: .regularExpression)?.lowerBound == value.startIndex,
              let match = value.range(of: pattern, options: .regularExpression), match.upperBound == value.endIndex else {
            throw ValidationError.invalidVersion
        }
        self.value = value
        let withoutBuild = String(value.split(separator: "+", maxSplits: 1)[0])
        core = String(withoutBuild.split(separator: "-", maxSplits: 1)[0])
        isPrerelease = withoutBuild.contains("-")
    }
}

public struct ReleaseMetadata: Codable, Equatable, Sendable {
    public let version: String
    public let build: Int

    public init(version: String, build: Int) throws {
        _ = try ReleaseVersion(version)
        guard build > 0 else { throw ReleaseVersion.ValidationError.invalidBuild }
        self.version = version
        self.build = build
    }

    private enum CodingKeys: String, CodingKey { case version, build }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(version: values.decode(String.self, forKey: .version),
                      build: values.decode(Int.self, forKey: .build))
    }
}
