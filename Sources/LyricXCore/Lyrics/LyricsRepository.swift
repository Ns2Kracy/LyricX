import Foundation

public struct LyricsRepository: Sendable {
    private let client: LRCLIBClient
    private let cache: LyricsCache
    private let metadataProvider: any TrackMetadataEnriching

    public init(
        client: LRCLIBClient = LRCLIBClient(),
        cache: LyricsCache = LyricsCache(),
        metadataProvider: any TrackMetadataEnriching = MusicBrainzMetadataClient()
    ) {
        self.client = client
        self.cache = cache
        self.metadataProvider = metadataProvider
    }

    public func timeline(for track: PlaybackTrack) async -> LyricTimeline? {
        if let cached = cache.cachedLyrics(for: track), let timeline = timeline(from: cached) {
            return timeline
        }

        return await refreshTimeline(for: track)
    }

    public func refreshTimeline(for track: PlaybackTrack) async -> LyricTimeline? {
        if let result = await fetchTimeline(for: track, searchesNormalizedVariant: true) {
            cache.store(result.lyrics, for: track)
            return result.timeline
        }

        guard let enrichedTrack = try? await metadataProvider.enrichedTrack(for: track),
              enrichedTrack != track,
              let result = await fetchTimeline(for: enrichedTrack, searchesNormalizedVariant: false) else {
            return nil
        }
        cache.store(result.lyrics, for: track)
        return result.timeline
    }

    private func fetchTimeline(
        for track: PlaybackTrack,
        searchesNormalizedVariant: Bool
    ) async -> (lyrics: String, timeline: LyricTimeline)? {
        guard let lyrics = try? await client.fetchSyncedLyrics(
            for: track,
            searchesNormalizedVariant: searchesNormalizedVariant
        ), let timeline = timeline(from: lyrics) else {
            return nil
        }
        return (lyrics, timeline)
    }

    private func timeline(from rawLyrics: String) -> LyricTimeline? {
        let lines = LRCParser.parse(rawLyrics)
        guard !lines.isEmpty else {
            return nil
        }
        return LyricTimeline(lines: lines)
    }
}
