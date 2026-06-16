import Foundation

public struct GitHubReleaseUpdateService: UpdateService {
    private let currentVersion: AppVersion
    private let fetchLatestReleaseData: @Sendable () async throws -> Data

    public init(owner: String, repository: String, currentVersion: AppVersion) {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
        self.currentVersion = currentVersion
        self.fetchLatestReleaseData = {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw AppUpdateError.requestFailed(httpResponse.statusCode)
            }
            return data
        }
    }

    public init(
        currentVersion: AppVersion,
        fetchLatestReleaseData: @escaping @Sendable () async throws -> Data
    ) {
        self.currentVersion = currentVersion
        self.fetchLatestReleaseData = fetchLatestReleaseData
    }

    public func latestVersion() async throws -> AppUpdate? {
        let update = try Self.decodeRelease(data: try await fetchLatestReleaseData())
        return update.version > currentVersion ? update : nil
    }

    public static func decodeRelease(data: Data) throws -> AppUpdate {
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let packageURL = release.assets.first { asset in
            asset.name.lowercased() == "lyricx.zip"
        }?.browserDownloadURL
        let checksumURL = release.assets.first { asset in
            asset.name.lowercased() == "lyricx.zip.sha256"
        }?.browserDownloadURL

        return AppUpdate(
            version: AppVersion(release.tagName),
            pageURL: release.htmlURL,
            packageURL: packageURL,
            checksumURL: checksumURL
        )
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
