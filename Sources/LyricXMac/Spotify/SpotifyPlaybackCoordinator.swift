import Foundation
import LyricXCore

public actor SpotifyPlaybackCoordinator: PlaybackArtworkService {
    private let fallback: any PlaybackArtworkService
    private let webAPI: SpotifyWebAPIClient?
    private let webPlaybackService: SpotifyWebPlaybackService?
    private let minimumFetchInterval: TimeInterval
    private var isSpotifyConnected = false
    private var cachedContext: SpotifyPlaybackContext?
    private var fetchedAt: Date?
    private var retryAfter: Date?
    private var failureCount = 0
    private var lastErrorMessage: String?
    private var embeddedDeviceID: String?
    private var embeddedSnapshot: PlaybackSnapshot?
    private var embeddedUpdatedAt: Date?
    private var embeddedActivatedAt: Date?
    private var usesEmbeddedPlayback = false

    public init(
        fallback: any PlaybackArtworkService = SpotifyAppleScriptPlaybackService(),
        authorizationService: SpotifyAuthorizationService?,
        webPlaybackService: SpotifyWebPlaybackService? = nil,
        minimumFetchInterval: TimeInterval = 2
    ) {
        self.fallback = fallback
        self.webAPI = authorizationService.map { SpotifyWebAPIClient(authorizationService: $0) }
        self.webPlaybackService = webPlaybackService
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
        if !connected {
            embeddedDeviceID = nil
            embeddedSnapshot = nil
            embeddedUpdatedAt = nil
            embeddedActivatedAt = nil
            usesEmbeddedPlayback = false
        }
    }

    public func spotifyConnected() -> Bool {
        isSpotifyConnected
    }

    public func isUsingEmbeddedPlayback() -> Bool {
        usesEmbeddedPlayback
    }

    public func currentDevice() -> SpotifyConnectDevice? {
        if usesEmbeddedPlayback, let embeddedDeviceID {
            return SpotifyConnectDevice(
                id: embeddedDeviceID,
                name: "LyricX",
                type: "Computer",
                isActive: true
            )
        }
        return cachedContext?.device
    }

    public func statusMessage() -> String? {
        lastErrorMessage
    }

    public func receiveWebPlaybackEvent(_ event: SpotifyWebPlaybackEvent) {
        switch event {
        case .ready(let deviceID):
            embeddedDeviceID = deviceID
        case .offline:
            if usesEmbeddedPlayback {
                usesEmbeddedPlayback = false
                lastErrorMessage = "LyricX's Spotify player went offline"
            }
        case .stateChanged(let state):
            embeddedUpdatedAt = Date()
            embeddedSnapshot = state.map(Self.snapshot(from:))
        case .autoplayFailed:
            usesEmbeddedPlayback = false
            lastErrorMessage = "Spotify blocked automatic playback. Try Listen in LyricX again."
        case .warning(let message):
            lastErrorMessage = message
        case .failed(let message):
            usesEmbeddedPlayback = false
            lastErrorMessage = message
        }
    }

    public func activateEmbeddedPlayback(deviceID: String) async throws {
        guard isSpotifyConnected, let webAPI, let webPlaybackService else {
            throw SpotifyPlaybackCoordinatorError.embeddedPlayerUnavailable
        }
        try await webPlaybackService.activateElement()
        try await webAPI.transferPlayback(to: deviceID, play: true)
        embeddedDeviceID = deviceID
        embeddedActivatedAt = Date()
        usesEmbeddedPlayback = true
        fetchedAt = nil
        retryAfter = nil
        failureCount = 0
        lastErrorMessage = nil
    }

    public func currentSnapshot() async -> PlaybackSnapshot {
        guard isSpotifyConnected, let webAPI else {
            return await fallback.currentSnapshot()
        }

        let now = Date()
        if let retryAfter, retryAfter > now {
            return preferredSnapshot(at: now) ?? PlaybackSnapshot(
                state: .unavailable,
                message: lastErrorMessage ?? "Spotify is temporarily unavailable"
            )
        }
        if let fetchedAt, now.timeIntervalSince(fetchedAt) < minimumFetchInterval {
            return preferredSnapshot(at: now) ?? PlaybackSnapshot(
                state: .stopped,
                message: "No active Spotify playback"
            )
        }

        do {
            cachedContext = try await webAPI.currentPlayback()
            fetchedAt = now
            retryAfter = nil
            failureCount = 0
            lastErrorMessage = nil
            reconcileEmbeddedDevice(at: now)
            return preferredSnapshot(at: now) ?? PlaybackSnapshot(
                state: .stopped,
                message: "No active Spotify playback"
            )
        } catch let error as SpotifyAuthorizationError {
            isSpotifyConnected = false
            lastErrorMessage = error.localizedDescription
            return await fallback.currentSnapshot()
        } catch SpotifyWebAPIError.rateLimited(let delay) {
            retryAfter = now.addingTimeInterval(max(1, delay))
            lastErrorMessage = SpotifyWebAPIError.rateLimited(retryAfter: delay).localizedDescription
            return preferredSnapshot(at: now) ?? PlaybackSnapshot(state: .unavailable, message: lastErrorMessage)
        } catch {
            failureCount += 1
            let delay = min(30, minimumFetchInterval * pow(2, Double(failureCount - 1)))
            retryAfter = now.addingTimeInterval(delay)
            lastErrorMessage = error.localizedDescription
            return preferredSnapshot(at: now) ?? PlaybackSnapshot(
                state: .unavailable,
                message: "Spotify Connect is temporarily unavailable"
            )
        }
    }

    public func playPause() async {
        guard isSpotifyConnected else {
            await fallback.playPause()
            return
        }
        if usesEmbeddedPlayback, let webPlaybackService {
            await performEmbeddedCommand { try await webPlaybackService.playPause() }
            return
        }
        guard let webAPI else {
            await fallback.playPause()
            return
        }
        let isPlaying = cachedContext?.snapshot.isPlaying == true
        await performAPICommand {
            if isPlaying {
                try await webAPI.pause()
            } else {
                try await webAPI.resume()
            }
        }
    }

    public func nextTrack() async {
        guard isSpotifyConnected else {
            await fallback.nextTrack()
            return
        }
        if usesEmbeddedPlayback, let webPlaybackService {
            await performEmbeddedCommand { try await webPlaybackService.nextTrack() }
            return
        }
        guard let webAPI else {
            await fallback.nextTrack()
            return
        }
        await performAPICommand {
            try await webAPI.nextTrack()
        }
    }

    public func previousTrack() async {
        guard isSpotifyConnected else {
            await fallback.previousTrack()
            return
        }
        if usesEmbeddedPlayback, let webPlaybackService {
            await performEmbeddedCommand { try await webPlaybackService.previousTrack() }
            return
        }
        guard let webAPI else {
            await fallback.previousTrack()
            return
        }
        await performAPICommand {
            try await webAPI.previousTrack()
        }
    }

    public func artwork(for track: PlaybackTrack) async -> TrackArtwork? {
        await fallback.artwork(for: track)
    }

    private func performAPICommand(
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

    private func performEmbeddedCommand(
        _ command: @MainActor @Sendable () async throws -> Void
    ) async {
        do {
            try await command()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func reconcileEmbeddedDevice(at date: Date) {
        guard usesEmbeddedPlayback, let embeddedDeviceID else {
            return
        }
        guard let activeDeviceID = cachedContext?.device?.id else {
            return
        }
        if activeDeviceID == embeddedDeviceID {
            return
        }
        if let embeddedActivatedAt, date.timeIntervalSince(embeddedActivatedAt) < 5 {
            return
        }
        usesEmbeddedPlayback = false
    }

    private func preferredSnapshot(at date: Date) -> PlaybackSnapshot? {
        if usesEmbeddedPlayback, let embeddedSnapshot {
            let snapshot = Self.mergingMetadata(
                into: embeddedSnapshot,
                from: cachedContext?.snapshot
            )
            return Self.estimatedSnapshot(snapshot, updatedAt: embeddedUpdatedAt, at: date)
        }
        guard let snapshot = cachedContext?.snapshot else {
            return nil
        }
        return Self.estimatedSnapshot(snapshot, updatedAt: fetchedAt, at: date)
    }

    private static func estimatedSnapshot(
        _ snapshot: PlaybackSnapshot,
        updatedAt: Date?,
        at date: Date
    ) -> PlaybackSnapshot {
        guard snapshot.isPlaying, let updatedAt else {
            return snapshot
        }
        let elapsed = max(0, date.timeIntervalSince(updatedAt))
        let position = min(snapshot.position + elapsed, snapshot.track?.duration ?? .greatestFiniteMagnitude)
        return PlaybackSnapshot(
            state: snapshot.state,
            track: snapshot.track,
            position: position,
            message: snapshot.message
        )
    }

    private static func mergingMetadata(
        into embedded: PlaybackSnapshot,
        from apiSnapshot: PlaybackSnapshot?
    ) -> PlaybackSnapshot {
        guard let embeddedTrack = embedded.track,
              let apiTrack = apiSnapshot?.track else {
            return embedded
        }
        let matchingURI = embeddedTrack.sourceURI.map { $0 == apiTrack.sourceURI } ?? false
        let matchingID = embeddedTrack.sourceID.map { $0 == apiTrack.sourceID } ?? false
        guard matchingURI || matchingID else {
            return embedded
        }
        let track = PlaybackTrack(
            title: embeddedTrack.title,
            artist: embeddedTrack.artist,
            album: embeddedTrack.album ?? apiTrack.album,
            duration: embeddedTrack.duration ?? apiTrack.duration,
            artworkURL: embeddedTrack.artworkURL ?? apiTrack.artworkURL,
            sourceID: embeddedTrack.sourceID ?? apiTrack.sourceID,
            sourceURI: embeddedTrack.sourceURI ?? apiTrack.sourceURI,
            isrc: apiTrack.isrc
        )
        return PlaybackSnapshot(
            state: embedded.state,
            track: track,
            position: embedded.position,
            message: embedded.message
        )
    }

    private static func snapshot(from state: SpotifyWebPlaybackState) -> PlaybackSnapshot {
        guard let webTrack = state.track else {
            return PlaybackSnapshot(state: .stopped, message: "No active Spotify playback")
        }
        let track = PlaybackTrack(
            title: webTrack.title,
            artist: webTrack.artist,
            album: webTrack.album,
            duration: webTrack.duration,
            artworkURL: webTrack.artworkURL,
            sourceID: webTrack.id,
            sourceURI: webTrack.uri
        )
        return PlaybackSnapshot(
            state: state.isPaused ? .paused : .playing,
            track: track,
            position: state.position
        )
    }
}

public enum SpotifyPlaybackCoordinatorError: LocalizedError, Equatable {
    case embeddedPlayerUnavailable

    public var errorDescription: String? {
        "LyricX's Spotify player is not ready"
    }
}
