import Foundation

public protocol PlayerService: Sendable {
    func currentSnapshot() async -> PlaybackSnapshot
    func playPause() async
    func nextTrack() async
    func previousTrack() async
}

public protocol PlaybackArtworkService: PlayerService, ArtworkProvider {}
