import Foundation
import LyricXCore

public struct SpotifyConnectDevice: Equatable, Sendable {
    public let id: String?
    public let name: String
    public let type: String
    public let isActive: Bool

    public init(id: String?, name: String, type: String, isActive: Bool) {
        self.id = id
        self.name = name
        self.type = type
        self.isActive = isActive
    }
}

public struct SpotifyPlaybackContext: Equatable, Sendable {
    public let snapshot: PlaybackSnapshot
    public let device: SpotifyConnectDevice?

    public init(snapshot: PlaybackSnapshot, device: SpotifyConnectDevice?) {
        self.snapshot = snapshot
        self.device = device
    }
}

public actor SpotifyWebAPIClient {
    private let authorizationService: SpotifyAuthorizationService
    private let session: URLSession
    private let baseURL: URL

    public init(
        authorizationService: SpotifyAuthorizationService,
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.spotify.com/v1")!
    ) {
        self.authorizationService = authorizationService
        self.session = session
        self.baseURL = baseURL
    }

    public func currentPlayback() async throws -> SpotifyPlaybackContext? {
        let (data, response) = try await send(path: "me/player")
        if response.statusCode == 204 {
            return nil
        }

        let payload: SpotifyPlaybackResponse
        do {
            payload = try JSONDecoder().decode(SpotifyPlaybackResponse.self, from: data)
        } catch {
            throw SpotifyWebAPIError.invalidResponse
        }
        return payload.playbackContext
    }

    public func resume() async throws {
        _ = try await send(path: "me/player/play", method: "PUT")
    }

    public func pause() async throws {
        _ = try await send(path: "me/player/pause", method: "PUT")
    }

    public func nextTrack() async throws {
        _ = try await send(path: "me/player/next", method: "POST")
    }

    public func previousTrack() async throws {
        _ = try await send(path: "me/player/previous", method: "POST")
    }

    public func transferPlayback(to deviceID: String, play: Bool) async throws {
        let body = try JSONEncoder().encode(SpotifyTransferRequest(deviceIDs: [deviceID], play: play))
        _ = try await send(path: "me/player", method: "PUT", body: body)
    }

    private func send(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let token = try await authorizationService.accessToken()
        var result = try await perform(path: path, method: method, body: body, token: token.value)
        if result.1.statusCode == 401 {
            let refreshedToken = try await authorizationService.refreshAccessToken()
            result = try await perform(path: path, method: method, body: body, token: refreshedToken.value)
        }
        try validate(result.1)
        return result
    }

    private func perform(
        path: String,
        method: String,
        body: Data?,
        token: String
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SpotifyWebAPIError.invalidResponse
        }
        return (data, response)
    }

    private func validate(_ response: HTTPURLResponse) throws {
        if response.statusCode == 429 {
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap(TimeInterval.init) ?? 1
            throw SpotifyWebAPIError.rateLimited(retryAfter: retryAfter)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw SpotifyWebAPIError.requestFailed(statusCode: response.statusCode)
        }
    }
}

public enum SpotifyWebAPIError: LocalizedError, Equatable {
    case invalidResponse
    case rateLimited(retryAfter: TimeInterval)
    case requestFailed(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Spotify returned an invalid playback response"
        case .rateLimited(let retryAfter):
            return "Spotify rate limit reached; retrying in \(Int(retryAfter.rounded(.up))) seconds"
        case .requestFailed(let statusCode):
            return "Spotify playback request failed (HTTP \(statusCode))"
        }
    }
}

private struct SpotifyTransferRequest: Encodable {
    let deviceIDs: [String]
    let play: Bool

    private enum CodingKeys: String, CodingKey {
        case deviceIDs = "device_ids"
        case play
    }
}

private struct SpotifyPlaybackResponse: Decodable {
    let device: SpotifyDeviceResponse?
    let progressMS: Int?
    let isPlaying: Bool
    let item: SpotifyTrackResponse?

    var playbackContext: SpotifyPlaybackContext {
        let device = device.map {
            SpotifyConnectDevice(id: $0.id, name: $0.name, type: $0.type, isActive: $0.isActive)
        }
        guard let item, item.type == "track", !item.name.isEmpty else {
            return SpotifyPlaybackContext(
                snapshot: PlaybackSnapshot(
                    state: .stopped,
                    message: "Spotify is not playing a supported track"
                ),
                device: device
            )
        }

        let artworkURL = (item.album?.images?.first).flatMap { URL(string: $0.url) }
        let track = PlaybackTrack(
            title: item.name,
            artist: (item.artists ?? []).map(\.name).joined(separator: ", "),
            album: item.album?.name,
            duration: item.durationMS.map { TimeInterval($0) / 1_000 },
            artworkURL: artworkURL,
            sourceID: item.id,
            sourceURI: item.uri,
            isrc: item.externalIDs?.isrc
        )
        return SpotifyPlaybackContext(
            snapshot: PlaybackSnapshot(
                state: isPlaying ? .playing : .paused,
                track: track,
                position: TimeInterval(progressMS ?? 0) / 1_000
            ),
            device: device
        )
    }

    private enum CodingKeys: String, CodingKey {
        case device
        case progressMS = "progress_ms"
        case isPlaying = "is_playing"
        case item
    }
}

private struct SpotifyDeviceResponse: Decodable {
    let id: String?
    let isActive: Bool
    let name: String
    let type: String

    private enum CodingKeys: String, CodingKey {
        case id
        case isActive = "is_active"
        case name
        case type
    }
}

private struct SpotifyTrackResponse: Decodable {
    let album: SpotifyAlbumResponse?
    let artists: [SpotifyArtistResponse]?
    let durationMS: Int?
    let externalIDs: SpotifyExternalIDsResponse?
    let id: String?
    let name: String
    let type: String
    let uri: String?

    private enum CodingKeys: String, CodingKey {
        case album
        case artists
        case durationMS = "duration_ms"
        case externalIDs = "external_ids"
        case id
        case name
        case type
        case uri
    }
}

private struct SpotifyAlbumResponse: Decodable {
    let images: [SpotifyImageResponse]?
    let name: String?
}

private struct SpotifyArtistResponse: Decodable {
    let name: String
}

private struct SpotifyImageResponse: Decodable {
    let url: String
}

private struct SpotifyExternalIDsResponse: Decodable {
    let isrc: String?
}
