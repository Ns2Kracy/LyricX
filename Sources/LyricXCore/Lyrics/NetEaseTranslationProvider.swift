import Foundation

public struct NetEaseTranslationProvider: LyricTranslationProvider {
    public let kind = TranslationProviderKind.netEaseCloudMusic
    private let baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URL(string: "https://music.163.com")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func translation(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationProviderResult? {
        guard options.netEaseEnabled,
              options.sourceMode != .existingLyricsOnly,
              !sourceTimeline.lines.isEmpty,
              let songID = try await searchSongID(for: track),
              let translatedLyrics = try await fetchTranslation(songID: songID) else {
            return nil
        }

        let translatedLines = LRCParser.parse(translatedLyrics)
        let lines = sourceTimeline.lines.compactMap { sourceLine -> LyricTranslationLine? in
            guard let translatedLine = translatedLines.min(by: {
                abs($0.time - sourceLine.time) < abs($1.time - sourceLine.time)
            }), abs(translatedLine.time - sourceLine.time) <= 2.5 else {
                return nil
            }

            return LyricTranslationLine(
                sourceLineID: sourceLine.id,
                time: sourceLine.time,
                translatedText: translatedLine.text,
                romajiText: nil
            )
        }
        guard !lines.isEmpty else {
            return nil
        }

        return LyricTranslationProviderResult(
            timeline: LyricTranslationTimeline(targetLanguage: targetLanguage, lines: lines),
            providerKind: kind,
            confidence: 1
        )
    }

    private func searchSongID(for track: PlaybackTrack) async throws -> Int? {
        let query = [track.title, track.artist].filter { !$0.isEmpty }.joined(separator: " ")
        let url = try makeURL(
            path: "api/search/get/web",
            queryItems: [
                URLQueryItem(name: "s", value: query),
                URLQueryItem(name: "type", value: "1"),
                URLQueryItem(name: "limit", value: "20")
            ]
        )
        let data = try await data(from: url)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        let expectedTitle = matchingKey(track.title)
        let expectedArtist = matchingKey(
            track.artist.split(separator: ",", maxSplits: 1).first.map(String.init) ?? track.artist
        )

        return response.result?.songs?
            .compactMap { song -> (id: Int, durationDifference: Double)? in
                guard matchingKey(song.name ?? "") == expectedTitle,
                      (song.artists ?? song.ar ?? []).contains(where: { matchingKey($0.name ?? "") == expectedArtist }) else {
                    return nil
                }
                let difference = song.durationSeconds.map { abs($0 - (track.duration ?? $0)) } ?? 0
                guard difference <= 15 else {
                    return nil
                }
                return (song.id, difference)
            }
            .min(by: { $0.durationDifference < $1.durationDifference })?
            .id
    }

    private func fetchTranslation(songID: Int) async throws -> String? {
        let url = try makeURL(
            path: "api/song/lyric",
            queryItems: [
                URLQueryItem(name: "id", value: String(songID)),
                URLQueryItem(name: "lv", value: "1"),
                URLQueryItem(name: "kv", value: "1"),
                URLQueryItem(name: "tv", value: "-1")
            ]
        )
        let data = try await data(from: url)
        return try JSONDecoder().decode(LyricsResponse.self, from: data).tlyric?.lyric?.nilIfBlank
    }

    private func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse else {
            throw NetEaseTranslationProviderError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw NetEaseTranslationProviderError.requestFailed(statusCode: response.statusCode)
        }
        return data
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw NetEaseTranslationProviderError.invalidURL
        }
        return url
    }

    private func matchingKey(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

public enum NetEaseTranslationProviderError: Error, Equatable, LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "NetEase returned an invalid request URL."
        case .invalidResponse:
            "NetEase returned an invalid response."
        case .requestFailed(let statusCode):
            "NetEase request failed with HTTP \(statusCode)."
        }
    }
}

private struct SearchResponse: Decodable {
    let result: SearchResult?
}

private struct SearchResult: Decodable {
    let songs: [Song]?
}

private struct Song: Decodable {
    let id: Int
    let name: String?
    let artists: [Artist]?
    let ar: [Artist]?
    let duration: Int?
    let dt: Int?

    var durationSeconds: Double? {
        (duration ?? dt).map { Double($0) / 1_000 }
    }
}

private struct Artist: Decodable {
    let name: String?
}

private struct LyricsResponse: Decodable {
    let tlyric: LyricPayload?
}

private struct LyricPayload: Decodable {
    let lyric: String?
}
