import Foundation
import LyricXCore
import LyricXMac
@testable import LyricXApp

extension LyricXUnitTests {
    static func testParsesTimestampedLine() throws {
        let lines = LRCParser.parse("[00:12.34]First line")
        try expectEqual(lines, [LyricLine(time: 12.34, text: "First line")])
    }

    static func testParsesMultipleTimestampsOnOneLine() throws {
        let lines = LRCParser.parse("[00:10.00][00:20.50]Chorus")
        try expectEqual(lines, [
            LyricLine(time: 10.0, text: "Chorus"),
            LyricLine(time: 20.5, text: "Chorus")
        ])
    }

    static func testIgnoresMetadataAndBlankLines() throws {
        let lrc = """
        [ar:Artist]

        [ti:Song]
        [00:01.00]Opening
        """
        try expectEqual(LRCParser.parse(lrc), [LyricLine(time: 1.0, text: "Opening")])
    }

    static func testSortsParsedLinesByTime() throws {
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

    static func testParsesEnhancedInlineSegmentTimestamps() throws {
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

    static func testNormalTimestampedLineHasNoSegments() throws {
        let lines = LRCParser.parse("[00:12.34]First line")

        try expectEqual(lines, [LyricLine(time: 12.34, text: "First line")])
        try expectEqual(lines[0].segments, [])
    }

    static func testTimelineReturnsNilBeforeFirstLine() throws {
        let timeline = LyricTimeline(lines: [LyricLine(time: 10.0, text: "First")])
        try expectNil(timeline.currentLine(at: 9.9))
    }

    static func testTimelineReturnsCurrentLineAtAndBetweenTimestamps() throws {
        let timeline = LyricTimeline(lines: [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second")
        ])

        try expectEqual(timeline.currentLine(at: 10.0), LyricLine(time: 10.0, text: "First"))
        try expectEqual(timeline.currentLine(at: 19.9), LyricLine(time: 10.0, text: "First"))
        try expectEqual(timeline.currentLine(at: 20.0), LyricLine(time: 20.0, text: "Second"))
    }

    static func testTimelineCanDelaySwitchWithinLeadTolerance() throws {
        let timeline = LyricTimeline(lines: [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second")
        ])

        try expectEqual(
            timeline.currentLine(at: 20.08, switchLeadTolerance: 0.12),
            LyricLine(time: 10.0, text: "First")
        )
        try expectEqual(
            timeline.currentLine(at: 20.12, switchLeadTolerance: 0.12),
            LyricLine(time: 20.0, text: "Second")
        )
    }

    static func testTimelineReturnsNextLineAfterPosition() throws {
        let timeline = LyricTimeline(lines: [
            LyricLine(time: 10.0, text: "First"),
            LyricLine(time: 20.0, text: "Second")
        ])

        try expectEqual(timeline.nextLine(after: 10.0), LyricLine(time: 20.0, text: "Second"))
        try expectNil(timeline.nextLine(after: 20.0))
    }

    static func testTimelineContextReturnsPreviousCurrentAndNextLine() throws {
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

    static func testTranslationTimelineMatchesSourceLineByIDAndTime() throws {
        let source = LyricLine(time: 12.0, text: "君が好き")
        let translated = LyricTranslationLine(
            sourceLineID: source.id,
            time: source.time,
            translatedText: "I love you",
            romajiText: "kimi ga suki"
        )
        let timeline = LyricTranslationTimeline(targetLanguage: .english, lines: [translated])

        try expectEqual(timeline.line(for: source), translated)
    }

    static func testTranslationTimelineRejectsSameIDWithDifferentTime() throws {
        let source = LyricLine(time: 12.0, text: "君が好き")
        let shifted = LyricTranslationLine(
            sourceLineID: source.id,
            time: 13.0,
            translatedText: "I love you",
            romajiText: nil
        )
        let timeline = LyricTranslationTimeline(targetLanguage: .english, lines: [shifted])

        try expectNil(timeline.line(for: source))
    }

    static func testTranslationCacheKeyDiffersByLanguage() throws {
        let cache = LyricTranslationCache(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
        let track = PlaybackTrack(title: "Song", artist: "Artist", album: "Album", duration: 120)
        let timeline = LyricTimeline(lines: [LyricLine(time: 1, text: "Hello")])

        let english = cache.fileURL(for: track, sourceTimeline: timeline, targetLanguage: .english, includeRomaji: false)
        let chinese = cache.fileURL(for: track, sourceTimeline: timeline, targetLanguage: .simplifiedChinese, includeRomaji: false)

        try expectEqual(english == chinese, false)
    }

    static func testTranslationCacheSavesAndLoadsTimeline() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = LyricTranslationCache(directory: directory)
        let track = PlaybackTrack(title: "Song", artist: "Artist", album: "Album", duration: 120)
        let sourceTimeline = LyricTimeline(lines: [LyricLine(time: 1, text: "Hello")])
        let translationTimeline = LyricTranslationTimeline(
            targetLanguage: .english,
            lines: [LyricTranslationLine(sourceLineID: sourceTimeline.lines[0].id, time: 1, translatedText: "Hello", romajiText: nil)]
        )

        cache.store(translationTimeline, for: track, sourceTimeline: sourceTimeline, includeRomaji: false)

        try expectEqual(
            cache.cachedTimeline(for: track, sourceTimeline: sourceTimeline, targetLanguage: .english, includeRomaji: false),
            translationTimeline
        )
    }

    static func testTranslationCacheIgnoresInvalidJSON() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = LyricTranslationCache(directory: directory)
        let track = PlaybackTrack(title: "Song", artist: "Artist", album: "Album", duration: 120)
        let sourceTimeline = LyricTimeline(lines: [LyricLine(time: 1, text: "Hello")])
        let fileURL = cache.fileURL(for: track, sourceTimeline: sourceTimeline, targetLanguage: .english, includeRomaji: false)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: fileURL)

        try expectNil(cache.cachedTimeline(for: track, sourceTimeline: sourceTimeline, targetLanguage: .english, includeRomaji: false))
    }

    static func testJapaneseRomajiRomanizesKana() throws {
        try expectEqual(JapaneseRomaji.romanizedText(for: "きみ が すき"), "kimi ga suki")
    }

    static func testJapaneseRomajiRomanizesSmallTsuAndLongVowelMark() throws {
        try expectEqual(JapaneseRomaji.romanizedText(for: "ハッピー"), "happii")
    }

    static func testJapaneseRomajiRomanizesSmallYoonKana() throws {
        try expectEqual(JapaneseRomaji.romanizedText(for: "きょう"), "kyou")
    }

    static func testJapaneseRomajiRomanizesKatakanaLoanwordSmallVowels() throws {
        try expectEqual(JapaneseRomaji.romanizedText(for: "パーティー"), "paatii")
        try expectEqual(JapaneseRomaji.romanizedText(for: "ファイト"), "faito")
        try expectEqual(JapaneseRomaji.romanizedText(for: "ディスコ"), "disuko")
    }

    static func testJapaneseRomajiReturnsNilForNonJapaneseText() throws {
        try expectNil(JapaneseRomaji.romanizedText(for: "hello world"))
    }

    static func testJapaneseRomajiReturnsNilForKanjiText() throws {
        try expectNil(JapaneseRomaji.romanizedText(for: "君が好き"))
    }


    static func testTrackScopedLyricLoadRejectsStaleTrack() throws {
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

    static func testTrackScopedLyricLoadRejectsSupersededRequest() throws {
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

    static func testTrackScopedLyricLoadAcceptsCurrentTrack() throws {
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

    static func testMenuBarMarqueeKeepsShortTextWhole() throws {
        let marquee = MenuBarMarquee(visibleCharacters: 10)

        try expectEqual(marquee.displayText("Short", offset: 5), "Short")
    }

    static func testMenuBarMarqueeReturnsFixedWindowForLongText() throws {
        let marquee = MenuBarMarquee(visibleCharacters: 6, paddingCharacters: 2)

        try expectEqual(marquee.displayText("abcdefghij", offset: 0), "abcdef")
        try expectEqual(marquee.displayText("abcdefghij", offset: 3), "defghi")
        try expectEqual(marquee.displayText("abcdefghij", offset: 9), "j  abc")
    }

    static func testMenuBarMarqueeReturnsTimedWindowForLongLyric() throws {
        let marquee = MenuBarMarquee(visibleCharacters: 6)

        try expectEqual(marquee.displayText("abcdefghij", progress: 0.0), "abcdef")
        try expectEqual(marquee.displayText("abcdefghij", progress: 0.5), "cdefgh")
        try expectEqual(marquee.displayText("abcdefghij", progress: 1.0), "efghij")
    }

    static func testMenuBarMarqueeShowsFinalWindowBeforeLineSwitch() throws {
        let marquee = MenuBarMarquee(visibleCharacters: 6)

        try expectEqual(marquee.displayText("abcdefghij", progress: 0.99), "efghij")
    }

    static func testMenuBarMarqueeCalculatesContinuousScrollOffset() throws {
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 0.0, contentWidth: 300, visibleWidth: 220), 0)
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 0.5, contentWidth: 300, visibleWidth: 220), -40)
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 1.0, contentWidth: 300, visibleWidth: 220), -80)
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 1.0, contentWidth: 200, visibleWidth: 220), 0)
    }

    static func testMenuBarMarqueeClampsContinuousScrollProgress() throws {
        try expectEqual(MenuBarMarquee.scrollOffset(progress: -1.0, contentWidth: 300, visibleWidth: 220), 0)
        try expectEqual(MenuBarMarquee.scrollOffset(progress: 2.0, contentWidth: 300, visibleWidth: 220), -80)
    }

    static func testMenuBarAnimationFrameRatesExposeSupportedValues() throws {
        try expectEqual(MenuBarAnimationFrameRate.allCases, [.fps15, .fps30, .fps60, .fps120])
        try expectEqual(MenuBarAnimationFrameRate.default, .fps30)
    }

    static func testMenuBarAnimationFrameRateIntervals() throws {
        try expectEqual(MenuBarAnimationFrameRate.fps15.frameInterval, 1.0 / 15.0)
        try expectEqual(MenuBarAnimationFrameRate.fps30.frameInterval, 1.0 / 30.0)
        try expectEqual(MenuBarAnimationFrameRate.fps60.frameInterval, 1.0 / 60.0)
        try expectEqual(MenuBarAnimationFrameRate.fps120.frameInterval, 1.0 / 120.0)
    }

    static func testMenuBarAnimationFrameRateCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(MenuBarAnimationFrameRate.fps120)
        let decoded = try JSONDecoder().decode(MenuBarAnimationFrameRate.self, from: data)

        try expectEqual(decoded, .fps120)
    }

    static func testTimelineMarqueeOffsetPausesBeforeMoving() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 0.4, contentWidth: 320), 0)
    }

    static func testTimelineMarqueeOffsetMovesAtConfiguredSpeed() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 1.8, contentWidth: 320), -34)
    }

    static func testTimelineMarqueeOffsetAdaptsToShortLyricDuration() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.effectiveStartPause(targetDuration: 1.8), 0.45)
        try expectEqual(marquee.scrollDuration(contentWidth: 320, targetDuration: 1.8), 1.35)
        try expectEqual(marquee.offset(elapsedTime: 1.8, contentWidth: 320, targetDuration: 1.8), -100)
        try expectEqual(marquee.effectiveStartPause(targetDuration: 0.6), 0.15)
        try expectEqual(marquee.offset(elapsedTime: 0.6, contentWidth: 320, targetDuration: 0.6), -100)
    }

    static func testTimelineMarqueeOffsetStopsAtEnd() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 3.8, contentWidth: 320), -100)
    }

    static func testTimelineMarqueeOffsetStaysAtEndAfterScrollCompletes() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 10, contentWidth: 320), -100)
    }

    static func testTimelineMarqueeOffsetStaysZeroWithoutOverflow() throws {
        let marquee = MenuBarTimelineMarquee(viewportWidth: 220, gap: 36, speed: 34, startPause: 0.8)

        try expectEqual(marquee.offset(elapsedTime: 10, contentWidth: 200), 0)
    }


}
