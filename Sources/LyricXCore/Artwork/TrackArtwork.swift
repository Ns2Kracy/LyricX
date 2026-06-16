import Foundation

public struct TrackArtwork: Equatable, Sendable {
    public let data: Data
    public let mimeType: String

    public init(data: Data, mimeType: String) {
        self.data = data
        self.mimeType = mimeType
    }
}

public protocol ArtworkProvider: Sendable {
    func artwork(for track: PlaybackTrack) async -> TrackArtwork?
}
