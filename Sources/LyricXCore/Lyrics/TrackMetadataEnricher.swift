import Foundation

public protocol TrackMetadataEnriching: Sendable {
    func enrichedTrack(for track: PlaybackTrack) async throws -> PlaybackTrack?
}

public actor MusicBrainzMetadataClient: TrackMetadataEnriching {
    private let session: URLSession
    private let baseURL: URL
    private let userAgent: String
    private let minimumRequestInterval: TimeInterval
    private var nextRequestDate = Date.distantPast

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://musicbrainz.org")!,
        userAgent: String = "LyricX/0.1 (+https://github.com/ns2kracy/LyricX)",
        minimumRequestInterval: TimeInterval = 1
    ) {
        self.session = session
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.minimumRequestInterval = max(0, minimumRequestInterval)
    }

    public func lookupURL(forISRC isrc: String) -> URL? {
        guard let normalizedISRC = Self.normalizedISRC(isrc) else {
            return nil
        }
        var components = URLComponents(
            url: baseURL.appendingPathComponent("ws/2/recording"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "query", value: "isrc:\(normalizedISRC)"),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "5")
        ]
        return components?.url
    }

    public func enrichedTrack(for track: PlaybackTrack) async throws -> PlaybackTrack? {
        guard let isrc = track.isrc, let url = lookupURL(forISRC: isrc) else {
            return nil
        }

        try await waitForRateLimit()
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw MusicBrainzMetadataError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw MusicBrainzMetadataError.requestFailed(statusCode: response.statusCode)
        }

        let payload: MusicBrainzRecordingSearchResponse
        do {
            payload = try JSONDecoder().decode(MusicBrainzRecordingSearchResponse.self, from: data)
        } catch {
            throw MusicBrainzMetadataError.invalidResponse
        }
        guard let recording = payload.recordings.max(by: {
            Self.score($0, against: track) < Self.score($1, against: track)
        }) else {
            return nil
        }

        let artist = recording.artistCredit
            .map { $0.name + ($0.joinPhrase ?? "") }
            .filter { !$0.isEmpty }
            .joined()
            .nilIfBlank
        return PlaybackTrack(
            title: recording.title.nilIfBlank ?? track.title,
            artist: artist ?? track.artist,
            album: track.album ?? recording.releases?.compactMap { $0.title?.nilIfBlank }.first,
            duration: track.duration ?? recording.length.map { TimeInterval($0) / 1_000 },
            artworkURL: track.artworkURL,
            sourceID: track.sourceID,
            sourceURI: track.sourceURI,
            isrc: track.isrc
        )
    }

    private func waitForRateLimit() async throws {
        let now = Date()
        let scheduledDate = max(now, nextRequestDate)
        nextRequestDate = scheduledDate.addingTimeInterval(minimumRequestInterval)
        let delay = scheduledDate.timeIntervalSince(now)
        if delay > 0 {
            try await Task.sleep(for: .seconds(delay))
        }
    }

    private static func normalizedISRC(_ isrc: String) -> String? {
        let uppercase = isrc.uppercased()
        guard uppercase.allSatisfy({ character in
            character.isASCII && (character.isLetter || character.isNumber || character == "-")
        }) else {
            return nil
        }
        let normalized = uppercase.filter { $0 != "-" }
        guard normalized.count == 12 else {
            return nil
        }
        return normalized
    }

    private static func score(_ recording: MusicBrainzRecording, against track: PlaybackTrack) -> Int {
        var score = 0
        if recording.title.caseInsensitiveCompare(track.title) == .orderedSame {
            score += 5
        }
        let recordingArtists = recording.artistCredit
            .map { $0.name + ($0.joinPhrase ?? "") }
            .joined()
            .lowercased()
        if !recordingArtists.isEmpty,
           recordingArtists.contains(track.artist.lowercased())
            || track.artist.lowercased().contains(recordingArtists) {
            score += 3
        }
        if let expected = track.duration, let length = recording.length {
            let difference = abs(expected - TimeInterval(length) / 1_000)
            score += max(0, 3 - Int(difference / 3))
        }
        return score
    }
}

public enum MusicBrainzMetadataError: LocalizedError, Equatable {
    case invalidResponse
    case requestFailed(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "MusicBrainz returned an invalid metadata response"
        case .requestFailed(let statusCode):
            return "MusicBrainz metadata request failed (HTTP \(statusCode))"
        }
    }
}

private struct MusicBrainzRecordingSearchResponse: Decodable {
    let recordings: [MusicBrainzRecording]
}

private struct MusicBrainzRecording: Decodable {
    let title: String
    let length: Int?
    let artistCredit: [MusicBrainzArtistCredit]
    let releases: [MusicBrainzRelease]?

    private enum CodingKeys: String, CodingKey {
        case title
        case length
        case artistCredit = "artist-credit"
        case releases
    }
}

private struct MusicBrainzArtistCredit: Decodable {
    let name: String
    let joinPhrase: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case joinPhrase = "joinphrase"
    }
}

private struct MusicBrainzRelease: Decodable {
    let title: String?
}
