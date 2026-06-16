import Foundation
import LyricXCore
import Observation

@MainActor
@Observable
final class AppModel {
    var settings = AppSettings()
    var playback = PlaybackSnapshot(state: .notRunning, message: "Waiting for Spotify")
    var timeline: LyricTimeline?
    var currentLine: LyricLine?
    var nextLine: LyricLine?
    var lyricsStatus = "Waiting for Spotify"
    var marqueeTick = 0

    @ObservationIgnored private let playbackService: SpotifyPlaybackService
    @ObservationIgnored private let lyricsRepository: LyricsRepository
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var lastLyricsTrack: PlaybackTrack?

    var isLyricsVisible: Bool {
        get { settings.showsLyrics }
        set { settings.showsLyrics = newValue }
    }

    var showsTrackWhenLyricsMissing: Bool {
        get { settings.showsTrackWhenLyricsMissing }
        set { settings.showsTrackWhenLyricsMissing = newValue }
    }

    var menuBarSymbol: String {
        playback.isPlaying ? "music.note" : "music.note.list"
    }

    var menuBarText: String {
        guard isLyricsVisible else {
            return "LyricX"
        }

        if let lyric = nonBlank(currentLine?.text) {
            return lyric
        }

        if let track = playback.track, showsTrackWhenLyricsMissing {
            return "♪ \(track.title) - \(track.artist)"
        }

        return lyricsStatus
    }

    var menuBarDisplayText: String {
        marquee(menuBarText, visibleCharacters: 28, offset: marqueeTick)
    }

    var trackSummary: String {
        guard let track = playback.track else {
            return playback.message ?? "Waiting for Spotify"
        }
        return "\(track.title) - \(track.artist)"
    }

    init(
        playbackService: SpotifyPlaybackService = SpotifyPlaybackService(),
        lyricsRepository: LyricsRepository = LyricsRepository()
    ) {
        self.playbackService = playbackService
        self.lyricsRepository = lyricsRepository
        startPolling()
    }

    deinit {
        pollingTask?.cancel()
    }

    func startPolling() {
        guard pollingTask == nil else {
            return
        }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                self?.marqueeTick += 1
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func refreshLyrics() {
        guard let track = playback.track else {
            lyricsStatus = "No Spotify track to refresh"
            return
        }

        Task { [weak self] in
            await self?.loadLyrics(for: track, bypassCache: true)
        }
    }

    private func pollOnce() async {
        let service = playbackService
        let snapshot = await Task.detached {
            service.currentSnapshot()
        }.value

        playback = snapshot

        guard let track = snapshot.track else {
            lastLyricsTrack = nil
            timeline = nil
            currentLine = nil
            nextLine = nil
            lyricsStatus = snapshot.message ?? "Waiting for Spotify"
            return
        }

        if track != lastLyricsTrack {
            lastLyricsTrack = track
            timeline = nil
            currentLine = nil
            nextLine = nil
            lyricsStatus = "Finding synced lyrics"
            await loadLyrics(for: track, bypassCache: false)
        }

        updateActiveLines(at: snapshot.position)
    }

    private func loadLyrics(for track: PlaybackTrack, bypassCache: Bool) async {
        let loadedTimeline: LyricTimeline?
        if bypassCache {
            loadedTimeline = await lyricsRepository.refreshTimeline(for: track)
        } else {
            loadedTimeline = await lyricsRepository.timeline(for: track)
        }

        timeline = loadedTimeline
        if loadedTimeline == nil {
            lyricsStatus = "No synced lyrics for \(track.title)"
        } else {
            lyricsStatus = "Lyrics synced"
        }
        updateActiveLines(at: playback.position)
    }

    private func updateActiveLines(at position: TimeInterval) {
        currentLine = timeline?.currentLine(at: position)
        nextLine = timeline?.nextLine(after: position)
    }

    private func marquee(_ text: String, visibleCharacters: Int, offset: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > visibleCharacters else {
            return trimmed
        }

        let padded = Array(trimmed + "    ")
        let start = offset % padded.count
        return String((0..<visibleCharacters).map { padded[(start + $0) % padded.count] })
    }

    private func nonBlank(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
