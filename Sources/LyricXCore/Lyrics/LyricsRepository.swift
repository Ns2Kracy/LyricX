import Foundation

public struct LyricsRepository: Sendable {
    private let client: LRCLIBClient
    private let cache: LyricsCache

    public init(client: LRCLIBClient = LRCLIBClient(), cache: LyricsCache = LyricsCache()) {
        self.client = client
        self.cache = cache
    }

    public func timeline(for track: PlaybackTrack) async -> LyricTimeline? {
        if let cached = cache.cachedLyrics(for: track), let timeline = timeline(from: cached) {
            return timeline
        }

        return await refreshTimeline(for: track)
    }

    public func refreshTimeline(for track: PlaybackTrack) async -> LyricTimeline? {
        guard let lyrics = try? await client.fetchSyncedLyrics(for: track), let timeline = timeline(from: lyrics) else {
            return nil
        }

        cache.store(lyrics, for: track)
        return timeline
    }

    private func timeline(from rawLyrics: String) -> LyricTimeline? {
        let lines = LRCParser.parse(rawLyrics)
        guard !lines.isEmpty else {
            return nil
        }
        return LyricTimeline(lines: lines)
    }
}
