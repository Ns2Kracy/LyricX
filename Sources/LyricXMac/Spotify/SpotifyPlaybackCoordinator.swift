import Foundation
import LyricXCore

public actor SpotifyPlaybackCoordinator: PlaybackArtworkService {
    private let fallback: any PlaybackArtworkService
    private let webAPI: SpotifyWebAPIClient?
    private let minimumFetchInterval: TimeInterval
    private var isSpotifyConnected = false
    private var cachedContext: SpotifyPlaybackContext?
    private var fetchedAt: Date?
    private var retryAfter: Date?
    private var failureCount = 0
    private var lastErrorMessage: String?

    public init(
        fallback: any PlaybackArtworkService = SpotifyAppleScriptPlaybackService(),
        authorizationService: SpotifyAuthorizationService?,
        minimumFetchInterval: TimeInterval = 2
    ) {
        self.fallback = fallback
        self.webAPI = authorizationService.map { SpotifyWebAPIClient(authorizationService: $0) }
        self.minimumFetchInterval = minimumFetchInterval
    }

    public func setSpotifyConnected(_ connected: Bool) {
        guard connected != isSpotifyConnected else {
            return
        }
        isSpotifyConnected = connected
        cachedContext = nil
        fetchedAt = nil
        retryAfter = nil
        failureCount = 0
        lastErrorMessage = nil
    }

    public func spotifyConnected() -> Bool {
        isSpotifyConnected
    }

    public func currentDevice() -> SpotifyConnectDevice? {
        cachedContext?.device
    }

    public func statusMessage() -> String? {
        lastErrorMessage
    }

    public func currentSnapshot() async -> PlaybackSnapshot {
        guard isSpotifyConnected, let webAPI else {
            return await fallback.currentSnapshot()
        }

        let now = Date()
        if let retryAfter, retryAfter > now {
            return cachedSnapshot(at: now) ?? PlaybackSnapshot(
                state: .unavailable,
                message: lastErrorMessage ?? "Spotify is temporarily unavailable"
            )
        }
        if let fetchedAt, now.timeIntervalSince(fetchedAt) < minimumFetchInterval {
            return cachedSnapshot(at: now) ?? PlaybackSnapshot(state: .stopped, message: "No active Spotify playback")
        }

        do {
            cachedContext = try await webAPI.currentPlayback()
            fetchedAt = now
            retryAfter = nil
            failureCount = 0
            lastErrorMessage = nil
            return cachedSnapshot(at: now) ?? PlaybackSnapshot(state: .stopped, message: "No active Spotify playback")
        } catch let error as SpotifyAuthorizationError {
            isSpotifyConnected = false
            lastErrorMessage = error.localizedDescription
            return await fallback.currentSnapshot()
        } catch SpotifyWebAPIError.rateLimited(let delay) {
            retryAfter = now.addingTimeInterval(max(1, delay))
            lastErrorMessage = SpotifyWebAPIError.rateLimited(retryAfter: delay).localizedDescription
            return cachedSnapshot(at: now) ?? PlaybackSnapshot(state: .unavailable, message: lastErrorMessage)
        } catch {
            failureCount += 1
            let delay = min(30, minimumFetchInterval * pow(2, Double(failureCount - 1)))
            retryAfter = now.addingTimeInterval(delay)
            lastErrorMessage = error.localizedDescription
            return cachedSnapshot(at: now) ?? PlaybackSnapshot(
                state: .unavailable,
                message: "Spotify Connect is temporarily unavailable"
            )
        }
    }

    public func playPause() async {
        guard isSpotifyConnected, let webAPI else {
            await fallback.playPause()
            return
        }
        let isPlaying = cachedContext?.snapshot.isPlaying == true
        await performCommand {
            if isPlaying {
                try await webAPI.pause()
            } else {
                try await webAPI.resume()
            }
        }
    }

    public func nextTrack() async {
        guard isSpotifyConnected, let webAPI else {
            await fallback.nextTrack()
            return
        }
        await performCommand {
            try await webAPI.nextTrack()
        }
    }

    public func previousTrack() async {
        guard isSpotifyConnected, let webAPI else {
            await fallback.previousTrack()
            return
        }
        await performCommand {
            try await webAPI.previousTrack()
        }
    }

    public func artwork(for track: PlaybackTrack) async -> TrackArtwork? {
        await fallback.artwork(for: track)
    }

    private func performCommand(
        _ command: @Sendable () async throws -> Void
    ) async {
        do {
            try await command()
            fetchedAt = nil
            failureCount = 0
            lastErrorMessage = nil
        } catch let error as SpotifyAuthorizationError {
            isSpotifyConnected = false
            lastErrorMessage = error.localizedDescription
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func cachedSnapshot(at date: Date) -> PlaybackSnapshot? {
        guard let cachedContext else {
            return nil
        }
        let snapshot = cachedContext.snapshot
        guard snapshot.isPlaying, let fetchedAt else {
            return snapshot
        }

        let elapsed = max(0, date.timeIntervalSince(fetchedAt))
        let position = min(snapshot.position + elapsed, snapshot.track?.duration ?? .greatestFiniteMagnitude)
        return PlaybackSnapshot(
            state: snapshot.state,
            track: snapshot.track,
            position: position,
            message: snapshot.message
        )
    }
}
