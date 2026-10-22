import XCTest
@testable import SnippetCore

final class ReleaseVersionTests: XCTestCase {
    func testBetaAndStableVersionsKeepNumericAppleVersionSeparate() throws {
        let beta = try ReleaseVersion("0.1.0-beta.1")
        XCTAssertEqual(beta.core, "0.1.0")
        XCTAssertTrue(beta.isPrerelease)
        XCTAssertFalse(try ReleaseVersion("0.1.0").isPrerelease)
        XCTAssertEqual(try ReleaseVersion("1.2.3-rc.1+build.007").core, "1.2.3")
    }
    func testRejectsInvalidIdentifiersAndFilenameInjection() {
        for invalid in ["v0.1.0", "01.1.0", "1.2", "1.2.3-beta.01", "1.2.3-", "1.2.3+", "1.2.3\n", "1.2.3/../../secret", "1.2.3-$(cmd)"] {
            XCTAssertThrowsError(try ReleaseVersion(invalid), invalid)
        }
    }
    func testDecodingCannotBypassVersionOrPositiveBuildValidation() throws {
        for invalid in [#"{"version":"0.1.0-beta.1","build":0}"#,
                        #"{"version":"bad","build":1}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(ReleaseMetadata.self, from: Data(invalid.utf8)))
        }
        let valid = try ReleaseMetadata(version: "0.1.0-beta.1", build: 1)
        XCTAssertEqual(try JSONDecoder().decode(ReleaseMetadata.self, from: JSONEncoder().encode(valid)), valid)
    }
}
