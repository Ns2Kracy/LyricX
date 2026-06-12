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

    @ObservationIgnored private let playbackService: SpotifyPlaybackService
    @ObservationIgnored private let lyricsRepository: LyricsRepository
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var lastLyricsTrack: PlaybackTrack?

    var isLyricsVisible: Bool {
        get { settings.showsLyrics }
        set { settings.showsLyrics = newValue }
    }

    var isFloatingPanelLocked: Bool {
        get { settings.locksFloatingPanel }
        set { settings.locksFloatingPanel = newValue }
    }

    var isClickThroughEnabled: Bool {
        get { settings.clickThroughFloatingPanel }
        set { settings.clickThroughFloatingPanel = newValue }
    }

    var menuBarSymbol: String {
        playback.isPlaying ? "music.note" : "music.note.list"
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
            lyricsStatus = "No synced lyrics found"
        } else {
            lyricsStatus = "Lyrics synced"
        }
        updateActiveLines(at: playback.position)
    }

    private func updateActiveLines(at position: TimeInterval) {
        currentLine = timeline?.currentLine(at: position)
        nextLine = timeline?.nextLine(after: position)
    }
}
