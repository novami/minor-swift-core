import Foundation
@testable import MinorUpdater
import XCTest

final class MinorUpdaterTests: XCTestCase {
    func testVersionParsingAndOrdering() throws {
        let version = try XCTUnwrap(SemanticVersion("1.10.0"))
        XCTAssertEqual(version.description, "1.10.0")
        XCTAssertGreaterThan(version, try XCTUnwrap(SemanticVersion("1.9.12")))

        for invalid in ["v1.0.0", "1.0", "1.0.0-beta", "01.0.0", "1.0.0.1", "1..0", ""] {
            XCTAssertNil(SemanticVersion(invalid), invalid)
        }
    }

    func testReleaseDecoding() throws {
        let json = """
            {"tag_name": "1.2.3", "html_url": "https://github.com/o/r/releases/tag/1.2.3", "body": "Notes",
             "assets": [{"name": "App-1.2.3.zip", "size": 10, "digest": "sha256:ab",
                         "browser_download_url": "https://github.com/o/r/releases/download/1.2.3/App-1.2.3.zip"}]}
            """
        let release = try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
        XCTAssertEqual(release.version, SemanticVersion(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(release.assets.first?.digest, "sha256:ab")
    }

    func testSHA256() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data("abc".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(
            try UpdateInstaller.sha256(of: url),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }
}
