import Foundation

public protocol PlayerService: Sendable {
    func currentSnapshot() -> PlaybackSnapshot
    func playPause()
    func nextTrack()
    func previousTrack()
}

public protocol PlaybackArtworkService: PlayerService, ArtworkProvider {}
