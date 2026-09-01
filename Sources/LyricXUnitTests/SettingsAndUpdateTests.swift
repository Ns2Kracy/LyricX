import Foundation
import LyricXCore
import LyricXMac
@testable import LyricXApp

extension LyricXUnitTests {
    static func testMenuBarClickFeedbackStaysVisibleWhilePressed() throws {
        var feedback = MenuBarClickFeedbackState()
        let pressGeneration = feedback.press()

        feedback.expire(generation: pressGeneration)

        try expectEqual(feedback.isVisible, true)
        try expectEqual(feedback.isPressed, true)

        let releaseGeneration = feedback.release()
        feedback.expire(generation: releaseGeneration)

        try expectEqual(feedback.isVisible, false)
        try expectEqual(feedback.isPressed, false)
    }

    static func testMenuBarClickFeedbackIgnoresStaleReleaseTimeout() throws {
        var feedback = MenuBarClickFeedbackState()
        _ = feedback.press()
        let firstReleaseGeneration = feedback.release()
        _ = feedback.press()

        feedback.expire(generation: firstReleaseGeneration)

        try expectEqual(feedback.isVisible, true)
        try expectEqual(feedback.isPressed, true)
    }

    static func testStylePresetCodableRoundTrip() throws {
        let preset = LyricStylePreset.defaults[0]
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(LyricStylePreset.self, from: data)

        try expectEqual(decoded, preset)
    }

    static func testStylePresetStoreSavesAndLoadsSelection() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = LyricStylePresetStore(fileURL: url)
        let preset = LyricStylePreset.defaults[1]

        try store.save(presets: LyricStylePreset.defaults, activePresetID: preset.id)
        let loaded = try store.load()

        try? FileManager.default.removeItem(at: url)
        try expectEqual(loaded.activePresetID, preset.id)
        try expectEqual(loaded.presets, LyricStylePreset.defaults)
    }

    static func testAppSettingsDefaultFrameRateIsThirtyFPS() throws {
        try expectEqual(AppSettings.default.menuBarFrameRate, .fps30)
    }

    static func testAppSettingsStoreSavesAndLoadsFrameRate() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = AppSettingsStore(fileURL: url)
        var settings = AppSettings.default
        settings.menuBarFrameRate = .fps120

        try store.save(settings)
        let loaded = try store.load()

        try? FileManager.default.removeItem(at: url)
        try expectEqual(loaded, settings)
    }

    static func testAppSettingsDefaultsToShowingMenuBarArtwork() throws {
        try expectEqual(AppSettings.default.showsMenuBarArtwork, true)
    }

    static func testAppSettingsDecodesMenuBarArtworkDefaultFromOldJSON() throws {
        let data = Data(#"{"showsLyrics":true,"showsTrackWhenLyricsMissing":false,"menuBarFrameRate":15}"#.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        try expectEqual(settings.showsMenuBarArtwork, true)
    }

    static func testAppSettingsStoreSavesMenuBarArtworkPreference() throws {
        let url = temporaryFileURL(name: "menu-bar-artwork-settings.json")
        let store = AppSettingsStore(fileURL: url)
        var settings = AppSettings.default
        settings.showsMenuBarArtwork = false

        try store.save(settings)
        let loaded = try store.load()

        try? FileManager.default.removeItem(at: url)
        try expectEqual(loaded.showsMenuBarArtwork, false)
    }

    @MainActor
    static func testAppModelMigratesOnlyUntouchedCompactPresetWidth() throws {
        let presetURL = temporaryFileURL(name: "compact-preset-migration.json")
        let settingsURL = temporaryFileURL(name: "compact-preset-migration-settings.json")
        var oldCompact = LyricStylePreset.defaults[0]
        oldCompact.menuBarWidth = 220
        var customizedWide = LyricStylePreset.defaults[1]
        customizedWide.menuBarWidth = 280
        let store = LyricStylePresetStore(fileURL: presetURL)
        try store.save(presets: [oldCompact, customizedWide], activePresetID: oldCompact.id)

        let model = AppModel(
            settingsStore: AppSettingsStore(fileURL: settingsURL),
            presetStore: store,
            startsPolling: false
        )

        try? FileManager.default.removeItem(at: presetURL)
        try? FileManager.default.removeItem(at: settingsURL)
        try expectEqual(model.stylePresets[0].menuBarWidth, 180)
        try expectEqual(model.stylePresets[1].menuBarWidth, 280)
    }

    static func testAppSettingsDecodesTranslationDefaultsFromOldJSON() throws {
        let data = Data(#"{"showsLyrics":true,"showsTrackWhenLyricsMissing":false,"menuBarFrameRate":15}"#.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        try expectEqual(settings.showsLyrics, true)
        try expectEqual(settings.showsTrackWhenLyricsMissing, false)
        try expectEqual(settings.menuBarFrameRate, .fps15)
        try expectEqual(settings.translationEnabled, false)
        try expectEqual(settings.translationTargetLanguage, .system)
        try expectEqual(settings.japaneseRomajiEnabled, false)
        try expectEqual(settings.menuBarLyricDisplayMode, .original)
    }

    static func testAppSettingsMigratesRemovedMachineTranslationMode() throws {
        let data = Data(#"{"translationSourceMode":"machineTranslationOnly"}"#.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        try expectEqual(settings.translationSourceMode, .auto)
    }

    static func testAppSettingsDecodesProviderDefaultsFromOldJSON() throws {
        let data = Data(#"{"showsLyrics":true,"showsTrackWhenLyricsMissing":false,"menuBarFrameRate":15}"#.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        try expectEqual(settings.translationSourceMode, .auto)
        try expectEqual(settings.netEaseTranslationSourceEnabled, false)
        try expectEqual(settings.qqMusicTranslationSourceEnabled, false)
    }

    static func testTranslationSourceSettingsCodableRoundTrip() throws {
        let settings = AppSettings(
            translationEnabled: true,
            translationTargetLanguage: .simplifiedChinese,
            translationSourceMode: .chineseLyricSourcesOnly,
            netEaseTranslationSourceEnabled: true,
            qqMusicTranslationSourceEnabled: true
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        try expectEqual(decoded.translationSourceMode, .chineseLyricSourcesOnly)
        try expectEqual(decoded.netEaseTranslationSourceEnabled, true)
        try expectEqual(decoded.qqMusicTranslationSourceEnabled, true)
    }

    static func testMenuBarLyricDisplayModeCodableRoundTrip() throws {
        let encoded = try JSONEncoder().encode(MenuBarLyricDisplayMode.alternateOriginalTranslation)
        let decoded = try JSONDecoder().decode(MenuBarLyricDisplayMode.self, from: encoded)

        try expectEqual(decoded, .alternateOriginalTranslation)
    }

    static func testTranslationLanguageCodableRoundTrip() throws {
        let encoded = try JSONEncoder().encode(TranslationLanguage.simplifiedChinese)
        let decoded = try JSONDecoder().decode(TranslationLanguage.self, from: encoded)

        try expectEqual(decoded, .simplifiedChinese)
    }


    static func testAppVersionComparisonFindsNewerPatch() throws {
        try expectEqual(AppVersion("0.1.2") > AppVersion("0.1.1"), true)
    }

    static func testAppVersionIgnoresLeadingV() throws {
        try expectEqual(AppVersion("v0.1.2"), AppVersion("0.1.2"))
    }

    static func testGitHubReleaseDecoderFindsPackageAsset() throws {
        let data = Data(#"""
        {
          "tag_name": "v0.1.2",
          "html_url": "https://github.com/ns2kracy/LyricX/releases/tag/v0.1.2",
          "assets": [
            {
              "name": "LyricX.zip",
              "browser_download_url": "https://github.com/ns2kracy/LyricX/releases/download/v0.1.2/LyricX.zip"
            },
            {
              "name": "LyricX.zip.sha256",
              "browser_download_url": "https://github.com/ns2kracy/LyricX/releases/download/v0.1.2/LyricX.zip.sha256"
            }
          ]
        }
        """#.utf8)

        let update = try GitHubReleaseUpdateService.decodeRelease(data: data)

        try expectEqual(update.version, AppVersion("0.1.2"))
        try expectEqual(update.pageURL.absoluteString, "https://github.com/ns2kracy/LyricX/releases/tag/v0.1.2")
        try expectEqual(update.packageURL?.absoluteString, "https://github.com/ns2kracy/LyricX/releases/download/v0.1.2/LyricX.zip")
        try expectEqual(update.checksumURL?.absoluteString, "https://github.com/ns2kracy/LyricX/releases/download/v0.1.2/LyricX.zip.sha256")
    }

    static func testLRCLIBLookupURLEncodesTrackQuery() throws {
        let client = LRCLIBClient(baseURL: URL(string: "https://example.test")!)
        let track = PlaybackTrack(
            title: "Sweet / Song",
            artist: "Artist & Friend",
            album: "Album Name",
            duration: 123.4
        )
        let url = client.lookupURL(for: track)
        let components = try require(URLComponents(url: url, resolvingAgainstBaseURL: false), "URL should be parseable")

        try expectEqual(components.scheme, "https")
        try expectEqual(components.host, "example.test")
        try expectEqual(components.path, "/api/get")
        try expectEqual(queryValue("track_name", in: components), "Sweet / Song")
        try expectEqual(queryValue("artist_name", in: components), "Artist & Friend")
        try expectEqual(queryValue("album_name", in: components), "Album Name")
        try expectEqual(queryValue("duration", in: components), "123")
    }

    static func testLRCLIBSearchURLEncodesTrackQuery() throws {
        let client = LRCLIBClient(baseURL: URL(string: "https://example.test")!)
        let track = PlaybackTrack(
            title: "Sweet / Song",
            artist: "Artist & Friend",
            album: "Album Name",
            duration: 123.4
        )
        let url = client.searchURL(for: track)
        let components = try require(URLComponents(url: url, resolvingAgainstBaseURL: false), "URL should be parseable")

        try expectEqual(components.scheme, "https")
        try expectEqual(components.host, "example.test")
        try expectEqual(components.path, "/api/search")
        try expectEqual(queryValue("track_name", in: components), "Sweet / Song")
        try expectEqual(queryValue("artist_name", in: components), "Artist & Friend")
        try expectEqual(queryValue("album_name", in: components), "Album Name")
    }

    static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) throws {
        guard actual == expected else {
            throw TestFailure(message: "Expected \(expected), got \(actual)", file: String(describing: file), line: line)
        }
    }

    static func testMenuBarContextMenuItemsExposeSettingsFirst() throws {
        let items = MenuBarContextMenuItem.allCases
        try expectEqual(items.map(\.title), ["Settings…", "Show LyricX", "Quit LyricX"])
        try expectEqual(items.map(\.systemImage), ["gearshape", "rectangle.on.rectangle", "power"])
        try expectEqual(items.first, .settings)
    }

    static func expectNil<T>(_ actual: T?, file: StaticString = #file, line: UInt = #line) throws {
        guard actual == nil else {
            throw TestFailure(message: "Expected nil, got \(String(describing: actual))", file: String(describing: file), line: line)
        }
    }

    static func require<T>(_ value: T?, _ message: String, file: StaticString = #file, line: UInt = #line) throws -> T {
        guard let value else {
            throw TestFailure(message: message, file: String(describing: file), line: line)
        }
        return value
    }

    static func temporaryFileURL(name: String) -> URL {
        let url = temporaryDirectoryURL(name: UUID().uuidString).appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        return url
    }

    static func temporaryDirectoryURL(name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LyricXUnitTests-\(name)", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func queryValue(_ name: String, in components: URLComponents) -> String? {
        components.queryItems?.first { $0.name == name }?.value
    }
}
