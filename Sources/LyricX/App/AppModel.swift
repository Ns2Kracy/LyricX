import Foundation
import LyricXCore
import LyricXMac
import Observation

@MainActor
@Observable
final class AppModel {
    var settings = AppSettings.default
    var playback = PlaybackSnapshot(state: .notRunning, message: "Waiting for Spotify")
    var timeline: LyricTimeline?
    var currentLine: LyricLine?
    var nextLine: LyricLine?
    var translationTimeline: LyricTranslationTimeline?
    var translationStatus: LyricTranslationStatus = .disabled
    var artwork: TrackArtwork?
    var lyricsStatus = "Waiting for Spotify"
    var stylePresets = LyricStylePreset.defaults
    var activeStylePresetID = LyricStylePreset.defaults[0].id
    var latestUpdate: AppUpdate?
    var updateStatus = "Updates not checked"

    @ObservationIgnored private let playbackService: SpotifyAppleScriptPlaybackService
    @ObservationIgnored private let lyricsRepository: LyricsRepository
    @ObservationIgnored private let settingsStore: AppSettingsStore
    @ObservationIgnored private let presetStore: LyricStylePresetStore
    @ObservationIgnored private let updateService: any UpdateService
    @ObservationIgnored private let translationService: any LyricTranslationService
    @ObservationIgnored private let translationCache: LyricTranslationCache
    @ObservationIgnored private let menuBarTextMetrics = MenuBarTextMetrics()
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var translationTask: Task<Void, Never>?
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
            updateActivePresetShowsTrackWhenLyricsMissing(newValue)
        }
    }

    var menuBarFrameRate: MenuBarAnimationFrameRate {
        get { settings.menuBarFrameRate }
        set {
            settings.menuBarFrameRate = newValue
            persistSettings()
        }
    }

    var translationEnabled: Bool {
        get { settings.translationEnabled }
        set {
            settings.translationEnabled = newValue
            persistSettings()
            reloadTranslationForCurrentTrack()
        }
    }

    var translationTargetLanguage: TranslationLanguage {
        get { settings.translationTargetLanguage }
        set {
            settings.translationTargetLanguage = newValue
            persistSettings()
            reloadTranslationForCurrentTrack()
        }
    }

    var japaneseRomajiEnabled: Bool {
        get { settings.japaneseRomajiEnabled }
        set {
            settings.japaneseRomajiEnabled = newValue
            persistSettings()
            reloadTranslationForCurrentTrack()
        }
    }

    var menuBarLyricDisplayMode: MenuBarLyricDisplayMode {
        get { settings.menuBarLyricDisplayMode }
        set {
            settings.menuBarLyricDisplayMode = newValue
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
        let style = activeStylePreset.menuBarStyle

        guard isLyricsVisible else {
            return MenuBarPresentation(
                text: "LyricX",
                accessibilityText: "LyricX",
                symbol: menuBarSymbol,
                behavior: .staticText,
                style: style
            )
        }

        let position = estimatedPlaybackPosition(at: date)
        if let line = timeline?.currentLine(at: position), let lyric = nonBlank(line.text) {
            let startedAt = lyricStartedAt(for: line, position: position, date: date)
            let targetDuration = menuBarTargetDuration(for: line)
            let lineProgress = menuBarLineProgress(for: line, position: position)
            let displayText = MenuBarLyricDisplayText.resolve(
                sourceLine: line,
                translationLine: translationTimeline?.line(for: line),
                mode: settings.menuBarLyricDisplayMode,
                lineProgress: lineProgress
            )
            let text = nonBlank(displayText.text) ?? lyric
            return MenuBarPresentation(
                text: text,
                accessibilityText: displayText.accessibilityText,
                symbol: nil,
                behavior: menuBarBehavior(for: text, startedAt: startedAt, targetDuration: targetDuration, style: style),
                style: style
            )
        }

        if let track = playback.track, showsTrackWhenLyricsMissing {
            let title = "\(track.title) - \(track.artist)"
            return MenuBarPresentation(
                text: title,
                accessibilityText: title,
                symbol: nil,
                behavior: menuBarBehavior(for: title, startedAt: .menuBarReferenceStart, targetDuration: nil, style: style),
                style: style
            )
        }

        return MenuBarPresentation(
            text: lyricsStatus,
            accessibilityText: lyricsStatus,
            symbol: menuBarSymbol,
            behavior: menuBarBehavior(for: lyricsStatus, startedAt: .menuBarReferenceStart, targetDuration: nil, style: style),
            style: style
        )
    }

    func lyricContext(at date: Date = Date()) -> LyricTimelineContext {
        guard let timeline else {
            return .empty
        }

        return timeline.context(at: estimatedPlaybackPosition(at: date))
    }


    func refreshLyricContext(at date: Date = Date()) {
        updateActiveLines(at: estimatedPlaybackPosition(at: date))
    }

    init(
        playbackService: SpotifyAppleScriptPlaybackService = SpotifyAppleScriptPlaybackService(),
        lyricsRepository: LyricsRepository = LyricsRepository(),
        settingsStore: AppSettingsStore = AppSettingsStore(fileURL: AppModel.defaultSettingsStoreURL()),
        presetStore: LyricStylePresetStore = LyricStylePresetStore(fileURL: AppModel.defaultPresetStoreURL()),
        updateService: any UpdateService = GitHubReleaseUpdateService(
            owner: "ns2kracy",
            repository: "LyricX",
            currentVersion: AppModel.currentAppVersion()
        ),
        translationService: any LyricTranslationService = LocalLyricTranslationService(),
        translationCache: LyricTranslationCache = LyricTranslationCache(),
        startsPolling: Bool = true
    ) {
        self.playbackService = playbackService
        self.lyricsRepository = lyricsRepository
        self.settingsStore = settingsStore
        self.presetStore = presetStore
        self.updateService = updateService
        self.translationService = translationService
        self.translationCache = translationCache
        settings = (try? settingsStore.load()) ?? .default
        loadPresetState()
        if startsPolling {
            startPolling()
        }
    }

    deinit {
        pollingTask?.cancel()
        artworkTask?.cancel()
        translationTask?.cancel()
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
            translationTask?.cancel()
            translationTimeline = nil
            translationStatus = .disabled
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
            translationTask?.cancel()
            translationTimeline = nil
            translationStatus = .disabled
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
            translationTask?.cancel()
            translationTimeline = nil
            translationStatus = settings.translationEnabled ? .loading : .disabled
            artwork = nil
            lyricsStatus = "Finding synced lyrics"
            loadArtwork(for: track)
            await loadLyrics(for: track, bypassCache: false)

            guard TrackScopedLyricLoad.canApply(
                loadedFor: track,
                currentTrack: playback.track,
                requestedTrack: lastLyricsTrack
            ) else {
                return
            }
        }

        updateActiveLines(at: playback.position)
    }

    private func loadLyrics(for track: PlaybackTrack, bypassCache: Bool) async {
        let loadedTimeline: LyricTimeline?
        if bypassCache {
            loadedTimeline = await lyricsRepository.refreshTimeline(for: track)
        } else {
            loadedTimeline = await lyricsRepository.timeline(for: track)
        }

        guard TrackScopedLyricLoad.canApply(
            loadedFor: track,
            currentTrack: playback.track,
            requestedTrack: lastLyricsTrack
        ) else {
            return
        }

        timeline = loadedTimeline
        if let loadedTimeline {
            lyricsStatus = "Lyrics synced"
            loadTranslation(for: track, sourceTimeline: loadedTimeline)
        } else {
            lyricsStatus = "No synced lyrics for \(track.title)"
            translationTimeline = nil
            translationStatus = settings.translationEnabled ? .failed("No source lyrics") : .disabled
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
        let context = timeline?.context(at: position) ?? .empty
        if currentLine != context.currentLine {
            currentLine = context.currentLine
        }
        if nextLine != context.nextLine {
            nextLine = context.nextLine
        }
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

    private func menuBarTargetDuration(for line: LyricLine) -> TimeInterval? {
        guard let nextLine = timeline?.nextLine(after: line.time) else {
            return nil
        }

        return max(nextLine.time - line.time, 0)
    }

    private func menuBarLineProgress(for line: LyricLine, position: TimeInterval) -> Double {
        guard let duration = menuBarTargetDuration(for: line), duration > 0 else {
            return 0
        }

        return min(max((position - line.time) / duration, 0), 1)
    }

    private func menuBarBehavior(for text: String, startedAt: Date, targetDuration: TimeInterval?, style: MenuBarStyle) -> MenuBarTextBehavior {
        let contentWidth = Double(menuBarTextMetrics.width(for: text, style: style))
        return MenuBarTextBehavior.behavior(contentWidth: contentWidth, style: style, startedAt: startedAt, targetDuration: targetDuration)
    }

    private func reloadTranslationForCurrentTrack() {
        guard let track = playback.track, let timeline else {
            translationTask?.cancel()
            translationTimeline = nil
            translationStatus = settings.translationEnabled ? .loading : .disabled
            return
        }

        loadTranslation(for: track, sourceTimeline: timeline)
    }

    private func loadTranslation(for track: PlaybackTrack, sourceTimeline: LyricTimeline) {
        translationTask?.cancel()

        guard settings.translationEnabled || settings.japaneseRomajiEnabled else {
            translationTimeline = nil
            translationStatus = .disabled
            return
        }

        let targetLanguage = settings.translationTargetLanguage
        let includeRomaji = settings.japaneseRomajiEnabled

        if let cached = translationCache.cachedTimeline(
            for: track,
            sourceTimeline: sourceTimeline,
            targetLanguage: targetLanguage,
            includeRomaji: includeRomaji
        ) {
            translationTimeline = cached
            translationStatus = .available
            return
        }

        translationStatus = .loading
        let service = translationService
        let cache = translationCache
        translationTask = Task { [weak self] in
            do {
                let loadedTimeline = try await service.translationTimeline(
                    for: sourceTimeline,
                    targetLanguage: targetLanguage,
                    includeRomaji: includeRomaji
                )
                await MainActor.run {
                    guard self?.playback.track == track, self?.timeline == sourceTimeline else {
                        return
                    }
                    self?.translationTimeline = loadedTimeline
                    self?.translationStatus = .available
                    cache.store(loadedTimeline, for: track, sourceTimeline: sourceTimeline, includeRomaji: includeRomaji)
                }
            } catch {
                await MainActor.run {
                    guard self?.playback.track == track, self?.timeline == sourceTimeline else {
                        return
                    }
                    self?.translationTimeline = nil
                    self?.translationStatus = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func updateActivePresetShowsTrackWhenLyricsMissing(_ value: Bool) {
        guard let index = stylePresets.firstIndex(where: { $0.id == activeStylePresetID }),
              stylePresets[index].showsTrackWhenLyricsMissing != value else {
            return
        }

        stylePresets[index].showsTrackWhenLyricsMissing = value
        persistPresetState()
    }

    private func nonBlank(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func runPlayerCommand(_ command: @escaping @Sendable (SpotifyAppleScriptPlaybackService) -> Void) {
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

private extension Date {
    static let menuBarReferenceStart = Date(timeIntervalSinceReferenceDate: 0)
}
