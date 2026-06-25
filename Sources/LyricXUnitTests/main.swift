import Foundation
import LyricXCore
import LyricXMac

@main
struct LyricXUnitTests {
    static func main() async throws {
        try testParsesTimestampedLine()
        try testParsesMultipleTimestampsOnOneLine()
        try testIgnoresMetadataAndBlankLines()
        try testSortsParsedLinesByTime()
        try testParsesEnhancedInlineSegmentTimestamps()
        try testNormalTimestampedLineHasNoSegments()
        try testTimelineReturnsNilBeforeFirstLine()
        try testTimelineReturnsCurrentLineAtAndBetweenTimestamps()
        try testTimelineReturnsNextLineAfterPosition()
        try testTimelineContextReturnsPreviousCurrentAndNextLine()
        try testTrackScopedLyricLoadRejectsStaleTrack()
        try testTrackScopedLyricLoadRejectsSupersededRequest()
        try testTrackScopedLyricLoadAcceptsCurrentTrack()
        try testMenuBarMarqueeKeepsShortTextWhole()
        try testMenuBarMarqueeReturnsFixedWindowForLongText()
        try testMenuBarMarqueeReturnsTimedWindowForLongLyric()
        try testMenuBarMarqueeShowsFinalWindowBeforeLineSwitch()
        try testMenuBarMarqueeCalculatesContinuousScrollOffset()
        try testMenuBarMarqueeClampsContinuousScrollProgress()
        try testMenuBarAnimationFrameRatesExposeSupportedValues()
        try testMenuBarAnimationFrameRateIntervals()
        try testMenuBarAnimationFrameRateCodableRoundTrip()
        try testTimelineMarqueeOffsetPausesBeforeMoving()
        try testTimelineMarqueeOffsetMovesAtConfiguredSpeed()
        try testTimelineMarqueeOffsetStopsAtEnd()
        try testTimelineMarqueeOffsetStaysZeroWithoutOverflow()
        try testTimelineMarqueeOffsetPausesAtEndBeforeReset()
        try testTimelineMarqueeOffsetResetsAfterEndPause()
        try testSpotifyControlScriptForPlayPause()
        try testSpotifyControlScriptForNextTrack()
        try testSpotifyControlScriptForPreviousTrack()
        try testSpotifyServiceRunsControlCommand()
        try testSpotifyParseReadsArtworkURL()
        try await testSpotifyArtworkProviderLoadsArtworkData()
        try testTrackArtworkStoresPNGData()
        try testDefaultStylePresetsIncludeMenuBarCompact()
        try testStylePresetDerivesMenuBarStyle()
        try testMenuBarBehaviorUsesPresetWidth()
        try testMenuBarLayoutCompactsShortTextWithoutAccessory()
        try testMenuBarLayoutUsesPresetWidthForLongTextWithoutAccessory()
        try testMenuBarLayoutCompactsShortTextWithAccessory()
        try testMenuBarLayoutUsesPresetWidthForLongTextWithAccessory()
        try testMenuBarClickFeedbackStaysVisibleWhilePressed()
        try testMenuBarClickFeedbackIgnoresStaleReleaseTimeout()
        try testStylePresetCodableRoundTrip()
        try testStylePresetStoreSavesAndLoadsSelection()
        try testAppSettingsDefaultFrameRateIsThirtyFPS()
        try testAppSettingsStoreSavesAndLoadsFrameRate()
        try testAppVersionComparisonFindsNewerPatch()
        try testAppVersionIgnoresLeadingV()
        try testGitHubReleaseDecoderFindsPackageAsset()
        try testLRCLIBLookupURLEncodesTrackQuery()
        try testLRCLIBSearchURLEncodesTrackQuery()
        print("LyricXUnitTests passed")
    }

    private static func testParsesTimestampedLine() throws {
        let lines = LRCParser.parse("[00:12.34]First line")
        try expectEqual(lines, [LyricLine(time: 12.34, text: "First line")])
    }

    private static func testParsesMultipleTimestampsOnOneLine() throws {
        let lines = LRCParser.parse("[00:10.00][00:20.50]Chorus")
        try expectEqual(lines, [
            LyricLine(time: 10.0, text: "Chorus"),
            LyricLine(time: 20.5, text: "Chorus")
        ])
    }

    private static func testIgnoresMetadataAndBlankLines() throws {
        let lrc = """
        [ar:Artist]

        [ti:Song]
        [00:01.00]Opening
        """
        try expectEqual(LRCParser.parse(lrc), [LyricLine(time: 1.0, text: "Opening")])
    }

    private static func testSortsParsedLinesByTime() throws {
        let lrc = """
        [00:30.00]Third
        [00:10.00]First
        [00:20.00]Second
        """
        try expectEqual(LRCParser.parse(lrc), [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second"),
            LyricLine(time: 30.0, text: "Third")
        ])
    }

    private static func testParsesEnhancedInlineSegmentTimestamps() throws {
        let lines = LRCParser.parse("[00:10.00]<00:10.00>Hello <00:10.50>world")

        try expectEqual(lines, [
            LyricLine(
                time: 10.0,
                text: "Hello world",
                segments: [
                    LyricSegment(time: 10.0, text: "Hello "),
                    LyricSegment(time: 10.5, text: "world")
                ]
            )
        ])
    }

    private static func testNormalTimestampedLineHasNoSegments() throws {
        let lines = LRCParser.parse("[00:12.34]First line")

        try expectEqual(lines, [LyricLine(time: 12.34, text: "First line")])
        try expectEqual(lines[0].segments, [])
    }

    private static func testTimelineReturnsNilBeforeFirstLine() throws {
        let timeline = LyricTimeline(lines: [LyricLine(time: 10.0, text: "First")])
        try expectNil(timeline.currentLine(at: 9.9))
    }

    private static func testTimelineReturnsCurrentLineAtAndBetweenTimestamps() throws {
        let timeline = LyricTimeline(lines: [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second")
        ])

        try expectEqual(timeline.currentLine(at: 10.0), LyricLine(time: 10.0, text: "First"))
        try expectEqual(timeline.currentLine(at: 19.9), LyricLine(time: 10.0, text: "First"))
        try expectEqual(timeline.currentLine(at: 20.0), LyricLine(time: 20.0, text: "Second"))
    }

    private static func testTimelineReturnsNextLineAfterPosition() throws {
        let timeline = LyricTimeline(lines: [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second")
        ])

        try expectEqual(timeline.nextLine(after: 10.0), LyricLine(time: 20.0, text: "Second"))
        try expectNil(timeline.nextLine(after: 20.0))
    }

    private static func testTimelineContextReturnsPreviousCurrentAndNextLine() throws {
        let timeline = LyricTimeline(lines: [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second"),
            LyricLine(time: 30.0, text: "Third")
        ])

        let context = timeline.context(at: 22.0)

        try expectEqual(context.previousLine, LyricLine(time: 10.0, text: "First"))
        try expectEqual(context.currentLine, LyricLine(time: 20.0, text: "Second"))
        try expectEqual(context.nextLine, LyricLine(time: 30.0, text: "Third"))
    }


    private static func testTrackScopedLyricLoadRejectsStaleTrack() throws {
        let staleTrack = PlaybackTrack(title: "Old Song", artist: "Artist")
        let currentTrack = PlaybackTrack(title: "New Song", artist: "Artist")

        try expectEqual(
            TrackScopedLyricLoad.canApply(
                loadedFor: staleTrack,
                currentTrack: currentTrack,
                requestedTrack: currentTrack
            ),
            false
        )
    }

    private static func testTrackScopedLyricLoadRejectsSupersededRequest() throws {
        let loadedTrack = PlaybackTrack(title: "Loaded Song", artist: "Artist")
        let requestedTrack = PlaybackTrack(title: "Requested Song", artist: "Artist")

        try expectEqual(
            TrackScopedLyricLoad.canApply(
                loadedFor: loadedTrack,
                currentTrack: loadedTrack,
                requestedTrack: requestedTrack
            ),
            false
        )
    }

    private static func testTrackScopedLyricLoadAcceptsCurrentTrack() throws {
        let currentTrack = PlaybackTrack(title: "Current Song", artist: "Artist")

        try expectEqual(
            TrackScopedLyricLoad.canApply(
                loadedFor: currentTrack,
                currentTrack: currentTrack,
                requestedTrack: currentTrack
            ),
            true
        )
    }

    private static func testMenuBarMarqueeKeepsShortTextWhole() throws {
        let marquee = MenuBarMarquee(visibleCharacters: 10)

        try expectEqual(marquee.displayText("Short", offset: 5), "Short")
    }

    private static func testMenuBarMarqueeReturnsFixedWindowForLongText() throws {
        let marquee = MenuBarMarquee(visibleCharacters: 6, paddingCharacters: 2)

        try expectEqual(marquee.displayText("abcdefghij", offset: 0), "abcdef")
        try expectEqual(marquee.displayText("abcdefghij", offset: 3), "defghi")
        try expectEqual(marquee.displayText("abcdefghij", offset: 9), "j  abc")
    }

    private static func testMenuBarMarqueeReturnsTimedWindowForLongLyric() throws {
        let marquee = MenuBarMarquee(visibleCharacters: 6)

        try expectEqual(marquee.displayText("abcdefghij", progress: 0.0), "abcdef")
        try expectEqual(marquee.displayText("abcdefghij", progress: 0.5), "cdefgh")
        try expectEqual(marquee.displayText("abcdefghij", progress: 1.0), "efghij")
    }

    private static func testMenuBarMarqueeShowsFinalWindowBeforeLineSwitch() throws {
        let marquee = MenuBarMarquee(visibleCharacters: 6)

        try expectEqual(marquee.displayText("abcdefghij", progress: 0.99), "efghij")
    }

    private static func testMenuBarMarqueeCalculatesContinuousScrollOffset() throws {
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 0.0, contentWidth: 300, visibleWidth: 220), 0)
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 0.5, contentWidth: 300, visibleWidth: 220), -40)
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 1.0, contentWidth: 300, visibleWidth: 220), -80)
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 1.0, contentWidth: 200, visibleWidth: 220), 0)
    }

    private static func testMenuBarMarqueeClampsContinuousScrollProgress() throws {
        try expectEqual(MenuBarMarquee.scrollOffset(progress: -1.0, contentWidth: 300, visibleWidth: 220), 0)
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 2.0, contentWidth: 300, visibleWidth: 220), -80)
    }

    private static func testMenuBarAnimationFrameRatesExposeSupportedValues() throws {
        try expectEqual(MenuBarAnimationFrameRate.allCases, [.fps15, .fps30, .fps60, .fps120])
        try expectEqual(MenuBarAnimationFrameRate.default, .fps30)
    }

    private static func testMenuBarAnimationFrameRateIntervals() throws {
        try expectEqual(MenuBarAnimationFrameRate.fps15.frameInterval, 1.0 / 15.0)
        try expectEqual(MenuBarAnimationFrameRate.fps30.frameInterval, 1.0 / 30.0)
        try expectEqual(MenuBarAnimationFrameRate.fps60.frameInterval, 1.0 / 60.0)
        try expectEqual(MenuBarAnimationFrameRate.fps120.frameInterval, 1.0 / 120.0)
    }

    private static func testMenuBarAnimationFrameRateCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(MenuBarAnimationFrameRate.fps120)
        let decoded = try JSONDecoder().decode(MenuBarAnimationFrameRate.self, from: data)

        try expectEqual(decoded, .fps120)
    }

    private static func testTimelineMarqueeOffsetPausesBeforeMoving() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 0.4, contentWidth: 320), 0)
    }

    private static func testTimelineMarqueeOffsetMovesAtConfiguredSpeed() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 1.8, contentWidth: 320), -34)
    }

    private static func testTimelineMarqueeOffsetStopsAtEnd() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 3.8, contentWidth: 320), -100)
    }

    private static func testTimelineMarqueeOffsetPausesAtEndBeforeReset() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 4.3, contentWidth: 320), -100)
    }

    private static func testTimelineMarqueeOffsetResetsAfterEndPause() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 4.7, contentWidth: 320), 0)
    }

    private static func testTimelineMarqueeOffsetStaysZeroWithoutOverflow() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 10, contentWidth: 200), 0)
    }

    private static func testSpotifyControlScriptForPlayPause() throws {
        try expectEqual(SpotifyAppleScriptPlayerCommand.playPause.appleScript, "tell application \"Spotify\" to playpause")
    }

    private static func testSpotifyControlScriptForNextTrack() throws {
        try expectEqual(SpotifyAppleScriptPlayerCommand.nextTrack.appleScript, "tell application \"Spotify\" to next track")
    }

    private static func testSpotifyControlScriptForPreviousTrack() throws {
        try expectEqual(SpotifyAppleScriptPlayerCommand.previousTrack.appleScript, "tell application \"Spotify\" to previous track")
    }

    private static func testSpotifyServiceRunsControlCommand() throws {
        let recorder = ScriptRecorder()
        let service = SpotifyAppleScriptPlaybackService(runScript: recorder.run)

        service.nextTrack()

        try expectEqual(recorder.scripts, [SpotifyAppleScriptPlayerCommand.nextTrack.appleScript])
    }

    private static func testSpotifyParseReadsArtworkURL() throws {
        let service = SpotifyAppleScriptPlaybackService(runScript: { _ in
            """
        playing
        Aimai
        9Lana
        Aimai
        220000
        11
        https://i.scdn.co/image/example
        """
        })
        let snapshot = service.currentSnapshot()

        try expectEqual(snapshot.track?.artworkURL, URL(string: "https://i.scdn.co/image/example"))
    }

    private static func testSpotifyArtworkProviderLoadsArtworkData() async throws {
        let expectedURL = try require(URL(string: "https://i.scdn.co/image/example"), "URL should be valid")
        let service = SpotifyAppleScriptPlaybackService(
            runScript: { _ in "" },
            fetchArtwork: { url in
                try expectEqual(url, expectedURL)
                return (Data([0x01, 0x02, 0x03]), "image/jpeg")
            }
        )
        let track = PlaybackTrack(
            title: "Aimai",
            artist: "9Lana",
            album: "Aimai",
            duration: 220,
            artworkURL: expectedURL
        )

        let artwork = try require(await service.artwork(for: track), "Artwork should load")

        try expectEqual(artwork.data, Data([0x01, 0x02, 0x03]))
        try expectEqual(artwork.mimeType, "image/jpeg")
    }

    private static func testTrackArtworkStoresPNGData() throws {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let artwork = TrackArtwork(data: data, mimeType: "image/png")

        try expectEqual(artwork.data, data)
        try expectEqual(artwork.mimeType, "image/png")
    }

    private static func testDefaultStylePresetsIncludeMenuBarCompact() throws {
        let presets = LyricStylePreset.defaults

        try expectEqual(presets.first?.name, "Menu Bar Compact")
    }

    private static func testStylePresetDerivesMenuBarStyle() throws {
        let preset = LyricStylePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            name: "Custom",
            menuBarWidth: 320,
            fontSize: 18,
            fontWeight: "semibold",
            textColorHex: "#FF3366",
            alignment: .center,
            showsTrackWhenLyricsMissing: true
        )

        try expectEqual(preset.menuBarStyle.viewportWidth, 320)
        try expectEqual(preset.menuBarStyle.fontSize, 18)
        try expectEqual(preset.menuBarStyle.fontWeight, .semibold)
        try expectEqual(preset.menuBarStyle.textColorHex, "#FF3366")
        try expectEqual(preset.menuBarStyle.alignment, .center)
    }

    private static func testMenuBarBehaviorUsesPresetWidth() throws {
        let startedAt = Date(timeIntervalSinceReferenceDate: 10)
        let compact = MenuBarStyle(viewportWidth: 160, fontSize: 13, fontWeight: .medium, textColorHex: "#FFFFFF", alignment: .leading)
        let wide = MenuBarStyle(viewportWidth: 320, fontSize: 13, fontWeight: .medium, textColorHex: "#FFFFFF", alignment: .leading)

        try expectEqual(MenuBarTextBehavior.behavior(contentWidth: 240, style: compact, startedAt: startedAt), .continuousMarquee(contentWidth: 240, startedAt: startedAt))
        try expectEqual(MenuBarTextBehavior.behavior(contentWidth: 240, style: wide, startedAt: startedAt), .staticText)
    }

    private static func testMenuBarLayoutCompactsShortTextWithoutAccessory() throws {
        let layout = MenuBarStatusItemLayout(maxViewportWidth: 220, contentWidth: 120, horizontalPadding: 8, leadingAccessoryWidth: 0)

        try expectEqual(layout.statusItemWidth, 120)
        try expectEqual(layout.textViewportMinX, 0)
        try expectEqual(layout.textViewportWidth, 120)
    }

    private static func testMenuBarLayoutUsesPresetWidthForLongTextWithoutAccessory() throws {
        let layout = MenuBarStatusItemLayout(maxViewportWidth: 220, contentWidth: 320, horizontalPadding: 8, leadingAccessoryWidth: 0)

        try expectEqual(layout.statusItemWidth, 220)
        try expectEqual(layout.textViewportMinX, 0)
        try expectEqual(layout.textViewportWidth, 220)
    }

    private static func testMenuBarLayoutCompactsShortTextWithAccessory() throws {
        let layout = MenuBarStatusItemLayout(maxViewportWidth: 220, contentWidth: 120, horizontalPadding: 8, leadingAccessoryWidth: 18)

        try expectEqual(layout.statusItemWidth, 154)
        try expectEqual(layout.textViewportMinX, 26)
        try expectEqual(layout.textViewportWidth, 120)
    }

    private static func testMenuBarLayoutUsesPresetWidthForLongTextWithAccessory() throws {
        let layout = MenuBarStatusItemLayout(maxViewportWidth: 220, contentWidth: 320, horizontalPadding: 8, leadingAccessoryWidth: 18)

        try expectEqual(layout.statusItemWidth, 254)
        try expectEqual(layout.textViewportMinX, 26)
        try expectEqual(layout.textViewportWidth, 220)
    }

    private static func testMenuBarClickFeedbackStaysVisibleWhilePressed() throws {
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

    private static func testMenuBarClickFeedbackIgnoresStaleReleaseTimeout() throws {
        var feedback = MenuBarClickFeedbackState()
        _ = feedback.press()
        let firstReleaseGeneration = feedback.release()
        _ = feedback.press()

        feedback.expire(generation: firstReleaseGeneration)

        try expectEqual(feedback.isVisible, true)
        try expectEqual(feedback.isPressed, true)
    }

    private static func testStylePresetCodableRoundTrip() throws {
        let preset = LyricStylePreset.defaults[0]
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(LyricStylePreset.self, from: data)

        try expectEqual(decoded, preset)
    }

    private static func testStylePresetStoreSavesAndLoadsSelection() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = LyricStylePresetStore(fileURL: url)
        let preset = LyricStylePreset.defaults[1]

        try store.save(presets: LyricStylePreset.defaults, activePresetID: preset.id)
        let loaded = try store.load()

        try? FileManager.default.removeItem(at: url)
        try expectEqual(loaded.activePresetID, preset.id)
        try expectEqual(loaded.presets, LyricStylePreset.defaults)
    }

    private static func testAppSettingsDefaultFrameRateIsThirtyFPS() throws {
        try expectEqual(AppSettings.default.menuBarFrameRate, .fps30)
    }

    private static func testAppSettingsStoreSavesAndLoadsFrameRate() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = AppSettingsStore(fileURL: url)
        var settings = AppSettings.default
        settings.menuBarFrameRate = .fps120

        try store.save(settings)
        let loaded = try store.load()

        try? FileManager.default.removeItem(at: url)
        try expectEqual(loaded, settings)
    }


    private static func testAppVersionComparisonFindsNewerPatch() throws {
        try expectEqual(AppVersion("0.1.2") > AppVersion("0.1.1"), true)
    }

    private static func testAppVersionIgnoresLeadingV() throws {
        try expectEqual(AppVersion("v0.1.2"), AppVersion("0.1.2"))
    }

    private static func testGitHubReleaseDecoderFindsPackageAsset() throws {
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

    private static func testLRCLIBLookupURLEncodesTrackQuery() throws {
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

    private static func testLRCLIBSearchURLEncodesTrackQuery() throws {
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

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) throws {
        guard actual == expected else {
            throw TestFailure(message: "Expected \(expected), got \(actual)", file: String(describing: file), line: line)
        }
    }

    private static func expectNil<T>(_ actual: T?, file: StaticString = #file, line: UInt = #line) throws {
        guard actual == nil else {
            throw TestFailure(message: "Expected nil, got \(String(describing: actual))", file: String(describing: file), line: line)
        }
    }

    private static func require<T>(_ value: T?, _ message: String, file: StaticString = #file, line: UInt = #line) throws -> T {
        guard let value else {
            throw TestFailure(message: message, file: String(describing: file), line: line)
        }
        return value
    }

    private static func queryValue(_ name: String, in components: URLComponents) -> String? {
        components.queryItems?.first { $0.name == name }?.value
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    let file: String
    let line: UInt

    var description: String {
        "\(file):\(line): \(message)"
    }
}

private final class ScriptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedScripts: [String] = []

    var scripts: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedScripts
    }

    func run(_ script: String) throws -> String {
        lock.lock()
        recordedScripts.append(script)
        lock.unlock()
        return ""
    }
}
