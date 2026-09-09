import Foundation

public struct LRCLIBClient: Sendable {
    public let baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URL(string: "https://lrclib.net")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func lookupURL(for track: PlaybackTrack) -> URL {
        url(path: "api/get", for: track, includesDuration: true)
    }

    public func searchURL(for track: PlaybackTrack) -> URL {
        url(path: "api/search", for: track, includesDuration: false)
    }

    public func fetchSyncedLyrics(
        for track: PlaybackTrack,
        searchesNormalizedVariant: Bool = true
    ) async throws -> String? {
        if let exactLyrics = try await fetchExactSyncedLyrics(for: track) {
            return exactLyrics
        }
        if let searchedLyrics = try await searchSyncedLyrics(for: track) {
            return searchedLyrics
        }

        guard searchesNormalizedVariant,
              let normalizedTrack = normalizedSearchTrack(for: track),
              normalizedTrack != track else {
            return nil
        }
        return try await searchSyncedLyrics(for: normalizedTrack)
    }

    private func fetchExactSyncedLyrics(for track: PlaybackTrack) async throws -> String? {
        let (data, response) = try await session.data(from: lookupURL(for: track))
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
        let (data, response) = try await session.data(from: searchURL(for: track))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LRCLIBError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LRCLIBError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let results = try JSONDecoder().decode([LRCLIBLyrics].self, from: data)
        return results
            .compactMap { lyrics -> (lyrics: String, score: Int)? in
                guard let syncedLyrics = lyrics.syncedLyrics?.nilIfBlank,
                      let score = score(lyrics, for: track) else {
                    return nil
                }
                return (syncedLyrics, score)
            }
            .max(by: { $0.score < $1.score })?
            .lyrics
    }

    private func normalizedSearchTrack(for track: PlaybackTrack) -> PlaybackTrack? {
        let title = Self.normalizedTitle(track.title)
        let artist = track.artist.split(separator: ",", maxSplits: 1).first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? track.artist
        guard title != track.title || artist != track.artist else {
            return nil
        }
        return PlaybackTrack(
            title: title,
            artist: artist,
            album: track.album,
            duration: track.duration,
            artworkURL: track.artworkURL,
            sourceID: track.sourceID,
            sourceURI: track.sourceURI,
            isrc: track.isrc
        )
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

    private func score(_ lyrics: LRCLIBLyrics, for track: PlaybackTrack) -> Int? {
        let expectedTitle = Self.matchingKey(Self.normalizedTitle(track.title))
        let actualTitle = Self.matchingKey(Self.normalizedTitle(lyrics.trackName ?? ""))
        guard !expectedTitle.isEmpty, expectedTitle == actualTitle else {
            return nil
        }

        let expectedArtist = Self.matchingKey(
            track.artist.split(separator: ",", maxSplits: 1).first.map(String.init) ?? track.artist
        )
        let actualArtistName = lyrics.artistName ?? ""
        let actualArtist = Self.matchingKey(
            actualArtistName.split(separator: ",", maxSplits: 1).first.map(String.init) ?? actualArtistName
        )
        let artistMatches = !expectedArtist.isEmpty && expectedArtist == actualArtist
        let durationDifference: TimeInterval? = if let expected = track.duration,
                                                   let actual = lyrics.duration {
            abs(expected - actual)
        } else {
            nil
        }
        if let durationDifference, durationDifference > 12 {
            return nil
        }
        let durationMatches = durationDifference.map { $0 <= 8 } ?? false
        guard artistMatches || durationMatches else {
            return nil
        }

        var score = 6
        if artistMatches {
            score += 4
        }
        if let difference = durationDifference {
            score += max(0, 4 - Int(difference / 2))
        }
        if let album = track.album,
           Self.matchingKey(lyrics.albumName ?? "") == Self.matchingKey(album) {
            score += 2
        }
        return score
    }

    private static func normalizedTitle(_ title: String) -> String {
        let bracketedSuffix = #"(?i)\s*[\(\[].*\b(feat(uring)?\.?|ft\.?|with|remaster(ed)?|live|radio edit|acoustic|version)\b.*[\)\]]\s*$"#
        let dashedSuffix = #"(?i)\s+-\s+(remaster(ed)?|live|radio edit|acoustic|.*version)\b.*$"#
        return title
            .replacingOccurrences(of: bracketedSuffix, with: "", options: .regularExpression)
            .replacingOccurrences(of: dashedSuffix, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchingKey(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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
