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
    var displayTick = 0

    @ObservationIgnored private let playbackService: SpotifyPlaybackService
    @ObservationIgnored private let lyricsRepository: LyricsRepository
    @ObservationIgnored private let marquee = MenuBarMarquee(visibleCharacters: 28)
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var displayRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var lastLyricsTrack: PlaybackTrack?
    @ObservationIgnored private var playbackUpdatedAt = Date()

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

    var shouldShowMenuBarIcon: Bool {
        menuBarPresentation().symbol != nil
    }

    var menuBarText: String {
        menuBarPresentation().accessibilityText
    }

    var trackSummary: String {
        guard let track = playback.track else {
            return playback.message ?? "Waiting for Spotify"
        }
        return "\(track.title) - \(track.artist)"
    }

    func menuBarPresentation(at date: Date = Date()) -> MenuBarPresentation {
        let marqueeOffset = displayTick

        guard isLyricsVisible else {
            return MenuBarPresentation(
                text: "LyricX",
                accessibilityText: "LyricX",
                symbol: menuBarSymbol,
                behavior: .staticText
            )
        }

        let position = estimatedPlaybackPosition(at: date)
        if let line = timeline?.currentLine(at: position), let lyric = nonBlank(line.text) {
            let isMarquee = lyric.count > marquee.visibleCharacters
            return MenuBarPresentation(
                text: isMarquee ? marquee.displayText(lyric, progress: lyricProgress(for: line, at: position)) : lyric,
                accessibilityText: lyric,
                symbol: nil,
                behavior: isMarquee ? .marquee : .staticText
            )
        }

        if let track = playback.track, showsTrackWhenLyricsMissing {
            let title = "\(track.title) - \(track.artist)"
            let isMarquee = title.count > marquee.visibleCharacters
            return MenuBarPresentation(
                text: isMarquee ? marquee.displayText(title, offset: marqueeOffset) : title,
                accessibilityText: title,
                symbol: nil,
                behavior: isMarquee ? .marquee : .staticText
            )
        }

        let isMarquee = lyricsStatus.count > marquee.visibleCharacters
        return MenuBarPresentation(
            text: isMarquee ? marquee.displayText(lyricsStatus, offset: marqueeOffset) : lyricsStatus,
            accessibilityText: lyricsStatus,
            symbol: menuBarSymbol,
            behavior: isMarquee ? .marquee : .staticText
        )
    }

    init(
        playbackService: SpotifyPlaybackService = SpotifyPlaybackService(),
        lyricsRepository: LyricsRepository = LyricsRepository()
    ) {
        self.playbackService = playbackService
        self.lyricsRepository = lyricsRepository
        startPolling()
        startDisplayRefresh()
    }

    deinit {
        pollingTask?.cancel()
        displayRefreshTask?.cancel()
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

    func startDisplayRefresh() {
        guard displayRefreshTask == nil else {
            return
        }

        displayRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.displayTick = ((self?.displayTick ?? 0) + 1) % 10_000
                try? await Task.sleep(nanoseconds: 180_000_000)
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
        playbackUpdatedAt = Date()

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

    private func estimatedPlaybackPosition(at date: Date) -> TimeInterval {
        guard playback.isPlaying else {
            return playback.position
        }

        let estimatedPosition = playback.position + max(0, date.timeIntervalSince(playbackUpdatedAt))
        if let duration = playback.track?.duration {
            return min(estimatedPosition, duration)
        }
        return estimatedPosition
    }

    private func lyricProgress(for line: LyricLine, at position: TimeInterval) -> Double {
        let endTime = nextLineEndTime(for: line, at: position)
        let duration = max(endTime - line.time, 0.5)
        return min(max((position - line.time) / duration, 0), 1)
    }

    private func nextLineEndTime(for line: LyricLine, at position: TimeInterval) -> TimeInterval {
        if let nextLine = timeline?.nextLine(after: position) {
            return nextLine.time
        }

        if let duration = playback.track?.duration, duration > line.time {
            return duration
        }

        return line.time + 6.0
    }

    private func nonBlank(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
