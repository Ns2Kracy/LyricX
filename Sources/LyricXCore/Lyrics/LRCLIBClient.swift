import Foundation

public struct LRCLIBClient: Sendable {
    public let baseURL: URL

    public init(baseURL: URL = URL(string: "https://lrclib.net")!) {
        self.baseURL = baseURL
    }

    public func lookupURL(for track: PlaybackTrack) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.scheme = components.scheme ?? "https"
        components.path = baseURL.appendingPathComponent("api/get").path

        var queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist)
        ]

        if let album = track.album?.nilIfBlank {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }

        if let duration = track.duration {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }

        components.queryItems = queryItems
        return components.url ?? baseURL
    }

    public func fetchSyncedLyrics(for track: PlaybackTrack) async throws -> String? {
        let (data, response) = try await URLSession.shared.data(from: lookupURL(for: track))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LRCLIBError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LRCLIBError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(LRCLIBLyrics.self, from: data)
        return result.syncedLyrics?.nilIfBlank
    }
}

public enum LRCLIBError: Error, Equatable, LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "LRCLIB returned an invalid response."
        case .requestFailed(let statusCode):
            "LRCLIB request failed with HTTP \(statusCode)."
        }
    }
}

struct LRCLIBLyrics: Decodable {
    let id: Int?
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}
