import Foundation

public struct GitHubRelease: Decodable, Sendable {
    public let tagName: String
    public let pageURL: URL
    public let notes: String?
    public let assets: [GitHubReleaseAsset]

    public var version: SemanticVersion? { SemanticVersion(tagName) }

    enum CodingKeys: String, CodingKey {
        case assets
        case tagName = "tag_name"
        case pageURL = "html_url"
        case notes = "body"
    }
}

public struct GitHubReleaseAsset: Decodable, Sendable {
    public let name: String
    public let downloadURL: URL
    public let size: Int
    /// `sha256:<hex>`, provided by GitHub for uploaded assets.
    public let digest: String?

    enum CodingKeys: String, CodingKey {
        case name, size, digest
        case downloadURL = "browser_download_url"
    }
}

struct GitHubReleaseClient: Sendable {
    let repository: String
    var session: URLSession = .shared

    /// Latest published release; GitHub excludes drafts and pre-releases.
    func latest() async throws -> GitHubRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw UpdateError.invalidRepository(repository)
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(repository, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw UpdateError.http(status) }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
}
