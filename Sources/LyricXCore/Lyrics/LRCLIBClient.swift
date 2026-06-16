import Foundation

public struct LRCLIBClient: Sendable {
    public let baseURL: URL

    public init(baseURL: URL = URL(string: "https://lrclib.net")!) {
        self.baseURL = baseURL
    }

    public func lookupURL(for track: PlaybackTrack) -> URL {
        url(path: "api/get", for: track, includesDuration: true)
    }

    public func searchURL(for track: PlaybackTrack) -> URL {
        url(path: "api/search", for: track, includesDuration: false)
    }

    public func fetchSyncedLyrics(for track: PlaybackTrack) async throws -> String? {
        if let exactLyrics = try await fetchExactSyncedLyrics(for: track) {
            return exactLyrics
        }

        return try await searchSyncedLyrics(for: track)
    }

    private func fetchExactSyncedLyrics(for track: PlaybackTrack) async throws -> String? {
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

    private func searchSyncedLyrics(for track: PlaybackTrack) async throws -> String? {
        let (data, response) = try await URLSession.shared.data(from: searchURL(for: track))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LRCLIBError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LRCLIBError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let results = try JSONDecoder().decode([LRCLIBLyrics].self, from: data)
        return results
            .filter { $0.syncedLyrics?.nilIfBlank != nil }
            .sorted { lhs, rhs in
                score(lhs, for: track) > score(rhs, for: track)
            }
            .first?
            .syncedLyrics?
            .nilIfBlank
    }

    private func url(path: String, for track: PlaybackTrack, includesDuration: Bool) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.scheme = components.scheme ?? "https"
        components.path = baseURL.appendingPathComponent(path).path

        var queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist)
        ]

        if let album = track.album?.nilIfBlank {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }

        if includesDuration, let duration = track.duration {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }

        components.queryItems = queryItems
        return components.url ?? baseURL
    }

    private func score(_ lyrics: LRCLIBLyrics, for track: PlaybackTrack) -> Int {
        var score = 0
        if lyrics.trackName?.caseInsensitiveCompare(track.title) == .orderedSame {
            score += 4
        }
        if lyrics.artistName?.caseInsensitiveCompare(track.artist) == .orderedSame {
            score += 3
        }
        if let album = track.album, lyrics.albumName?.caseInsensitiveCompare(album) == .orderedSame {
            score += 2
        }
        if let expectedDuration = track.duration, let actualDuration = lyrics.duration {
            score += max(0, 3 - Int(abs(expectedDuration - actualDuration).rounded()))
        }
        return score
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
