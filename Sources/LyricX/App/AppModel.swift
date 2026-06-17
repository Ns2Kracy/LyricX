import Foundation
import LyricXCore
import Observation

@MainActor
@Observable
final class AppModel {
    var settings = AppSettings.default
    var playback = PlaybackSnapshot(state: .notRunning, message: "Waiting for Spotify")
    var timeline: LyricTimeline?
    var currentLine: LyricLine?
    var nextLine: LyricLine?
    var artwork: TrackArtwork?
    var lyricsStatus = "Waiting for Spotify"
    var stylePresets = LyricStylePreset.defaults
    var activeStylePresetID = LyricStylePreset.defaults[0].id
    var latestUpdate: AppUpdate?
    var updateStatus = "Updates not checked"
    var isMainWindowRequested = false
    var displayTick = 0

    @ObservationIgnored private let playbackService: SpotifyPlaybackService
    @ObservationIgnored private let lyricsRepository: LyricsRepository
    @ObservationIgnored private let settingsStore: AppSettingsStore
    @ObservationIgnored private let presetStore: LyricStylePresetStore
    @ObservationIgnored private let updateService: any UpdateService
    @ObservationIgnored private let marquee = MenuBarMarquee(visibleCharacters: 28)
    @ObservationIgnored private let menuBarTextMetrics = MenuBarTextMetrics()
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var displayRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var lastLyricsTrack: PlaybackTrack?
    @ObservationIgnored private var playbackUpdatedAt = Date()

    var isLyricsVisible: Bool {
        get { settings.showsLyrics }
        set {
            settings.showsLyrics = newValue
            persistSettings()
        }
    }

    var showsTrackWhenLyricsMissing: Bool {
        get { settings.showsTrackWhenLyricsMissing }
        set {
            settings.showsTrackWhenLyricsMissing = newValue
            persistSettings()
        }
    }

    var menuBarFrameRate: MenuBarAnimationFrameRate {
        get { settings.menuBarFrameRate }
        set {
            settings.menuBarFrameRate = newValue
            persistSettings()
        }
    }

    var activeStylePreset: LyricStylePreset {
        stylePresets.first { $0.id == activeStylePresetID } ?? LyricStylePreset.defaults[0]
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
            let contentWidth = Double(menuBarTextMetrics.width(for: lyric))
            let isMarquee = contentWidth > Double(MenuBarTextMetrics.viewportWidth)
            let behavior = isMarquee
                ? MenuBarTextBehavior.continuousMarquee(
                    contentWidth: contentWidth,
                    startedAt: lyricStartedAt(for: line, position: position, date: date)
                )
                : .staticText
            return MenuBarPresentation(
                text: lyric,
                accessibilityText: lyric,
                symbol: nil,
                behavior: behavior
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
        lyricsRepository: LyricsRepository = LyricsRepository(),
        settingsStore: AppSettingsStore = AppSettingsStore(fileURL: AppModel.defaultSettingsStoreURL()),
        presetStore: LyricStylePresetStore = LyricStylePresetStore(fileURL: AppModel.defaultPresetStoreURL()),
        updateService: any UpdateService = GitHubReleaseUpdateService(
            owner: "ns2kracy",
            repository: "LyricX",
            currentVersion: AppModel.currentAppVersion()
        )
    ) {
        self.playbackService = playbackService
        self.lyricsRepository = lyricsRepository
        self.settingsStore = settingsStore
        self.presetStore = presetStore
        self.updateService = updateService
        settings = (try? settingsStore.load()) ?? .default
        loadPresetState()
        startPolling()
        startDisplayRefresh()
    }

    deinit {
        pollingTask?.cancel()
        displayRefreshTask?.cancel()
        artworkTask?.cancel()
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

    func playPause() {
        runPlayerCommand { service in
            service.playPause()
        }
    }

    func nextTrack() {
        runPlayerCommand { service in
            service.nextTrack()
        }
    }

    func previousTrack() {
        runPlayerCommand { service in
            service.previousTrack()
        }
    }

    func checkForUpdates() {
        updateStatus = "Checking for updates..."
        let service = updateService

        Task { [weak self, service] in
            do {
                let update = try await service.latestVersion()
                await MainActor.run {
                    self?.latestUpdate = update
                    if let update {
                        self?.updateStatus = "LyricX \(update.version) is available"
                    } else {
                        self?.updateStatus = "LyricX is up to date"
                    }
                }
            } catch {
                await MainActor.run {
                    self?.updateStatus = "Update check failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func selectPreset(_ preset: LyricStylePreset) {
        activeStylePresetID = preset.id
        showsTrackWhenLyricsMissing = preset.showsTrackWhenLyricsMissing
        persistPresetState()
    }

    func updatePreset(_ preset: LyricStylePreset) {
        if let index = stylePresets.firstIndex(where: { $0.id == preset.id }) {
            stylePresets[index] = preset
        } else {
            stylePresets.append(preset)
        }

        if preset.id == activeStylePresetID {
            showsTrackWhenLyricsMissing = preset.showsTrackWhenLyricsMissing
        }
        persistPresetState()
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
            artwork = nil
            artworkTask?.cancel()
            lyricsStatus = snapshot.message ?? "Waiting for Spotify"
            return
        }

        if track != lastLyricsTrack {
            lastLyricsTrack = track
            timeline = nil
            currentLine = nil
            nextLine = nil
            artwork = nil
            lyricsStatus = "Finding synced lyrics"
            loadArtwork(for: track)
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

    private func loadArtwork(for track: PlaybackTrack) {
        artworkTask?.cancel()
        let service = playbackService
        artworkTask = Task { [weak self] in
            let loadedArtwork = await service.artwork(for: track)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard self?.playback.track == track else {
                    return
                }
                self?.artwork = loadedArtwork
            }
        }
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

    private func lyricStartedAt(for line: LyricLine, position: TimeInterval, date: Date) -> Date {
        date.addingTimeInterval(line.time - position)
    }

    private func nonBlank(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func runPlayerCommand(_ command: @escaping @Sendable (SpotifyPlaybackService) -> Void) {
        let service = playbackService
        Task { [weak self] in
            await Task.detached {
                command(service)
            }.value
            try? await Task.sleep(nanoseconds: 300_000_000)
            await self?.pollOnce()
        }
    }

    private func loadPresetState() {
        let state = (try? presetStore.load()) ?? LyricStylePresetStore.defaultState
        stylePresets = state.presets.isEmpty ? LyricStylePreset.defaults : state.presets
        activeStylePresetID = stylePresets.contains { $0.id == state.activePresetID }
            ? state.activePresetID
            : stylePresets[0].id
        showsTrackWhenLyricsMissing = activeStylePreset.showsTrackWhenLyricsMissing
    }

    private func persistPresetState() {
        try? presetStore.save(presets: stylePresets, activePresetID: activeStylePresetID)
    }

    private func persistSettings() {
        try? settingsStore.save(settings)
    }

    private static func defaultSettingsStoreURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("LyricX", isDirectory: true)
            .appendingPathComponent("app-settings.json")
    }

    private static func defaultPresetStoreURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("LyricX", isDirectory: true)
            .appendingPathComponent("style-presets.json")
    }

    private static func currentAppVersion() -> AppVersion {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        return AppVersion(version)
    }
}
