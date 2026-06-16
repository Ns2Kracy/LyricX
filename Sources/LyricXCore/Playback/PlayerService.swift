import Foundation

public protocol PlayerService: Sendable {
    func currentSnapshot() -> PlaybackSnapshot
    func playPause()
    func nextTrack()
    func previousTrack()
}

public enum SpotifyPlayerCommand: Equatable, Sendable {
    case playPause
    case nextTrack
    case previousTrack

    public var appleScript: String {
        switch self {
        case .playPause:
            return "tell application \"Spotify\" to playpause"
        case .nextTrack:
            return "tell application \"Spotify\" to next track"
        case .previousTrack:
            return "tell application \"Spotify\" to previous track"
        }
    }
}
