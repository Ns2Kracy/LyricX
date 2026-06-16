import Foundation

public struct PlaybackTrack: Equatable, Hashable, Sendable {
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: TimeInterval?
    public let artworkURL: URL?

    public init(title: String, artist: String, album: String? = nil, duration: TimeInterval? = nil, artworkURL: URL? = nil) {
        self.title = title
        self.artist = artist
        self.album = album?.nilIfBlank
        self.duration = duration
        self.artworkURL = artworkURL
    }
}

public enum PlaybackState: String, Equatable, Sendable {
    case notRunning
    case stopped
    case paused
    case playing
    case unavailable
}

public struct PlaybackSnapshot: Equatable, Sendable {
    public let state: PlaybackState
    public let track: PlaybackTrack?
    public let position: TimeInterval
    public let message: String?

    public var isPlaying: Bool {
        state == .playing
    }

    public init(state: PlaybackState, track: PlaybackTrack? = nil, position: TimeInterval = 0, message: String? = nil) {
        self.state = state
        self.track = track
        self.position = position
        self.message = message
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
