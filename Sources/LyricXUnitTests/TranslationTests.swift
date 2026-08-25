import Foundation
import LyricXCore
import LyricXMac
@testable import LyricXApp

extension LyricXUnitTests {
    @MainActor
    static func testAppModelKeepsSourceMenuBarTextWhenTranslationFails() async throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let timeline = LyricTimeline(lines: [source])
        let track = PlaybackTrack(title: "Song", artist: "Artist", duration: 120)
        let model = AppModel(
            settingsStore: AppSettingsStore(fileURL: temporaryFileURL(name: "app-model-settings.json")),
            presetStore: LyricStylePresetStore(fileURL: temporaryFileURL(name: "app-model-presets.json")),
            translationService: FailingLyricTranslationService(),
            translationCache: LyricTranslationCache(directory: temporaryDirectoryURL(name: "app-model-translation-cache")),
            startsPolling: false
        )
        model.playback = PlaybackSnapshot(state: .playing, track: track, position: 10.5)
        model.timeline = timeline
        model.settings.menuBarLyricDisplayMode = .alternateOriginalTranslation

        model.translationEnabled = true
        try await Task.sleep(nanoseconds: 20_000_000)

        try expectEqual(model.translationStatus, .failed("translation unavailable"))
        try expectEqual(model.menuBarPresentation(at: Date()).text, "君が好き")
    }

    @MainActor
    static func testAppModelIgnoresStaleTranslationAfterSettingsChange() async throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let sourceTimeline = LyricTimeline(lines: [source])
        let track = PlaybackTrack(title: "Song", artist: "Artist", duration: 120)
        let requests = ControlledTranslationRequests()
        let model = AppModel(
            settingsStore: AppSettingsStore(fileURL: temporaryFileURL(name: "stale-settings.json")),
            presetStore: LyricStylePresetStore(fileURL: temporaryFileURL(name: "stale-presets.json")),
            translationService: ControlledLyricTranslationService(requests: requests),
            translationCache: LyricTranslationCache(directory: temporaryDirectoryURL(name: "stale-translation-cache")),
            startsPolling: false
        )
        model.playback = PlaybackSnapshot(state: .playing, track: track, position: 10.5)
        model.timeline = sourceTimeline
        model.translationTargetLanguage = .english

        model.translationEnabled = true
        try await requests.waitForRequestCount(1)
        model.translationTargetLanguage = .simplifiedChinese
        try await requests.waitForRequestCount(2)

        await requests.completeRequest(
            at: 0,
            with: LyricTranslationTimeline(
                targetLanguage: .english,
                lines: [LyricTranslationLine(sourceLineID: source.id, time: source.time, translatedText: "I love you", romajiText: nil)]
            )
        )
        try await Task.sleep(nanoseconds: 20_000_000)

        try expectNil(model.translationTimeline)
        try expectEqual(model.translationStatus, .loading)

        await requests.completeRequest(
            at: 1,
            with: LyricTranslationTimeline(
                targetLanguage: .simplifiedChinese,
                lines: [LyricTranslationLine(sourceLineID: source.id, time: source.time, translatedText: "我喜欢你", romajiText: nil)]
            )
        )
        try await Task.sleep(nanoseconds: 20_000_000)

        try expectEqual(model.translationTimeline?.targetLanguage, .simplifiedChinese)
        try expectEqual(model.translationStatus, .available)
    }

    @MainActor
    static func testAppModelReportsUnavailableTranslationProvider() async throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let timeline = LyricTimeline(lines: [source])
        let track = PlaybackTrack(title: "Song", artist: "Artist", duration: 120)
        let model = AppModel(
            settingsStore: AppSettingsStore(fileURL: temporaryFileURL(name: "unavailable-provider-settings.json")),
            presetStore: LyricStylePresetStore(fileURL: temporaryFileURL(name: "unavailable-provider-presets.json")),
            translationService: LocalLyricTranslationService(),
            translationCache: LyricTranslationCache(directory: temporaryDirectoryURL(name: "unavailable-provider-cache")),
            startsPolling: false
        )
        model.playback = PlaybackSnapshot(state: .playing, track: track, position: 10.5)
        model.timeline = timeline

        model.translationEnabled = true
        try await Task.sleep(nanoseconds: 20_000_000)

        try expectEqual(model.translationTimeline?.line(for: source)?.translatedText, nil)
        try expectEqual(model.translationStatus, .failed("No translation provider configured"))
    }

    @MainActor
    static func testAppModelUsesConfiguredTranslationProvider() async throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let timeline = LyricTimeline(lines: [source])
        let track = PlaybackTrack(title: "Song", artist: "Artist", duration: 120)
        let model = AppModel(
            settingsStore: AppSettingsStore(fileURL: temporaryFileURL(name: "configured-provider-settings.json")),
            presetStore: LyricStylePresetStore(fileURL: temporaryFileURL(name: "configured-provider-presets.json")),
            translationService: ConfiguredLyricTranslationService(translatedText: "I love you"),
            translationCache: LyricTranslationCache(directory: temporaryDirectoryURL(name: "configured-provider-cache")),
            startsPolling: false
        )
        model.playback = PlaybackSnapshot(state: .playing, track: track, position: 10.5)
        model.timeline = timeline
        model.translationSourceMode = .machineTranslationOnly
        model.machineTranslationProvider = .openAICompatible
        model.openAICompatibleBaseURL = "https://api.example.test/v1/chat/completions"
        model.openAICompatibleModel = "translation-model"
        model.openAICompatibleAPIKey = "test-key"

        model.translationEnabled = true
        try await Task.sleep(nanoseconds: 20_000_000)

        try expectEqual(model.translationStatus, .available)
        try expectEqual(model.translationTimeline?.line(for: source)?.translatedText, "I love you")
    }

    static func testProviderChainStopsAtFirstTranslatedResult() async throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let timeline = LyricTimeline(lines: [source])
        let track = PlaybackTrack(title: "Song", artist: "Artist", duration: 120)
        let first = RecordingTranslationProvider(
            kind: .embeddedLyrics,
            result: LyricTranslationProviderResult(
                timeline: LyricTranslationTimeline(
                    targetLanguage: .english,
                    lines: [LyricTranslationLine(sourceLineID: source.id, time: source.time, translatedText: "I love you", romajiText: nil)]
                ),
                providerKind: .embeddedLyrics,
                confidence: 1
            )
        )
        let second = RecordingTranslationProvider(kind: .openAICompatible, result: nil)
        let chain = LyricTranslationProviderChain(providers: [first, second])

        let result = try await chain.translation(for: track, sourceTimeline: timeline, targetLanguage: .english, options: .default)

        try expectEqual(result?.providerKind, .embeddedLyrics)
        try expectEqual(result?.timeline.line(for: source)?.translatedText, "I love you")
        try await expectEqual(first.callCount, 1)
        try await expectEqual(second.callCount, 0)
    }

    static func testProviderChainFallsThroughEmptyResult() async throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let timeline = LyricTimeline(lines: [source])
        let track = PlaybackTrack(title: "Song", artist: "Artist", duration: 120)
        let empty = RecordingTranslationProvider(
            kind: .embeddedLyrics,
            result: LyricTranslationProviderResult(
                timeline: LyricTranslationTimeline(
                    targetLanguage: .english,
                    lines: [LyricTranslationLine(sourceLineID: source.id, time: source.time, translatedText: nil, romajiText: nil)]
                ),
                providerKind: .embeddedLyrics,
                confidence: 1
            )
        )
        let fallback = RecordingTranslationProvider(
            kind: .openAICompatible,
            result: LyricTranslationProviderResult(
                timeline: LyricTranslationTimeline(
                    targetLanguage: .english,
                    lines: [LyricTranslationLine(sourceLineID: source.id, time: source.time, translatedText: "I love you", romajiText: nil)]
                ),
                providerKind: .openAICompatible,
                confidence: 0.8
            )
        )
        let chain = LyricTranslationProviderChain(providers: [empty, fallback])

        let result = try await chain.translation(for: track, sourceTimeline: timeline, targetLanguage: .english, options: .default)

        try expectEqual(result?.providerKind, .openAICompatible)
        try expectEqual(result?.timeline.line(for: source)?.translatedText, "I love you")
        try await expectEqual(empty.callCount, 1)
        try await expectEqual(fallback.callCount, 1)
    }

    static func testOpenAICompatibleProviderParsesTranslationsByID() throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let timeline = LyricTimeline(lines: [source])
        let data = Data(#"{"translations":[{"id":"\#(source.id)","text":"I love you"}]}"#.utf8)

        let translated = try OpenAICompatibleLyricTranslationProvider.decodeTimeline(
            from: data,
            sourceTimeline: timeline,
            targetLanguage: .english,
            includeRomaji: true
        )

        try expectEqual(translated.line(for: source)?.translatedText, "I love you")
        try expectEqual(translated.line(for: source)?.romajiText, nil)
    }

    static func testOpenAICompatibleProviderRejectsMissingConfiguration() async throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let timeline = LyricTimeline(lines: [source])
        let provider = OpenAICompatibleLyricTranslationProvider()
        let track = PlaybackTrack(title: "Song", artist: "Artist", duration: 120)

        do {
            _ = try await provider.translation(
                for: track,
                sourceTimeline: timeline,
                targetLanguage: .english,
                options: LyricTranslationProviderOptions(machineProvider: .openAICompatible)
            )
            throw TestFailure(message: "Expected missing provider configuration", file: #file, line: #line)
        } catch let error as LyricTranslationProviderError {
            try expectEqual(error, .missingConfiguration("OpenAI-compatible translation requires a base URL, model, and API key."))
        }
    }


}
