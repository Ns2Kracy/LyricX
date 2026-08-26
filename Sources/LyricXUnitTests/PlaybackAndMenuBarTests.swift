import AppKit
import Foundation
import LyricXCore
import LyricXMac
@testable import LyricXApp

extension LyricXUnitTests {
    static func testSpotifyControlScriptForPlayPause() throws {
        try expectEqual(SpotifyAppleScriptPlayerCommand.playPause.appleScript, "tell application \"Spotify\" to playpause")
    }

    static func testSpotifyControlScriptForNextTrack() throws {
        try expectEqual(SpotifyAppleScriptPlayerCommand.nextTrack.appleScript, "tell application \"Spotify\" to next track")
    }

    static func testSpotifyControlScriptForPreviousTrack() throws {
        try expectEqual(SpotifyAppleScriptPlayerCommand.previousTrack.appleScript, "tell application \"Spotify\" to previous track")
    }

    static func testSpotifyServiceRunsControlCommand() throws {
        let recorder = ScriptRecorder()
        let service = SpotifyAppleScriptPlaybackService(runScript: recorder.run)

        service.nextTrack()

        try expectEqual(recorder.scripts, [SpotifyAppleScriptPlayerCommand.nextTrack.appleScript])
    }

    static func testSpotifyParseReadsArtworkURL() throws {
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

    static func testSpotifyArtworkProviderLoadsArtworkData() async throws {
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

    static func testTrackArtworkStoresPNGData() throws {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let artwork = TrackArtwork(data: data, mimeType: "image/png")

        try expectEqual(artwork.data, data)
        try expectEqual(artwork.mimeType, "image/png")
    }

    @MainActor
    static func testAppModelSelectsMenuBarArtworkOnlyWhenEnabled() throws {
        let model = AppModel(
            settingsStore: AppSettingsStore(
                fileURL: temporaryFileURL(name: "menu-bar-artwork-selection-settings.json")
            ),
            presetStore: LyricStylePresetStore(
                fileURL: temporaryFileURL(name: "menu-bar-artwork-selection-presets.json")
            ),
            startsPolling: false
        )
        let artwork = TrackArtwork(data: Data([0x01, 0x02]), mimeType: "image/test")

        try expectNil(model.menuBarArtwork)

        model.artwork = artwork
        try expectEqual(model.menuBarArtwork, artwork)

        model.showsMenuBarArtwork = false
        try expectNil(model.menuBarArtwork)
    }

    @MainActor
    static func testAppModelSwitchesLyricWhenNextLineStarts() throws {
        let model = AppModel(
            settingsStore: AppSettingsStore(
                fileURL: temporaryFileURL(name: "lyric-switch-boundary-settings.json")
            ),
            presetStore: LyricStylePresetStore(
                fileURL: temporaryFileURL(name: "lyric-switch-boundary-presets.json")
            ),
            startsPolling: false
        )
        let first = LyricLine(time: 10, text: "First")
        let second = LyricLine(time: 20, text: "Second")
        let track = PlaybackTrack(title: "Song", artist: "Artist", duration: 120)
        model.timeline = LyricTimeline(lines: [first, second])

        // The next line's timestamp is the exact switch boundary for every lyric surface.
        model.playback = PlaybackSnapshot(state: .paused, track: track, position: second.time - 0.001)
        try expectEqual(model.lyricContext().currentLine, first)
        try expectEqual(model.menuBarPresentation().text, first.text)

        model.playback = PlaybackSnapshot(state: .paused, track: track, position: second.time)
        try expectEqual(model.lyricContext().currentLine, second)
        try expectEqual(model.menuBarPresentation().text, second.text)
    }

    @MainActor
    static func testMenuBarStatusItemArtworkOccupiesSpaceOnlyWhenDrawable() throws {
        let view = MenuBarStatusItemView(frame: .zero)
        let presentation = MenuBarPresentation(
            text: "Test",
            accessibilityText: "Test",
            symbol: nil,
            behavior: .staticText
        )

        view.update(presentation: presentation, artwork: nil, date: Date())
        let widthWithoutArtwork = view.intrinsicContentSize.width

        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        let imageData = try require(image.tiffRepresentation, "Test image should encode")
        view.update(
            presentation: presentation,
            artwork: TrackArtwork(data: imageData, mimeType: "image/tiff"),
            date: Date()
        )
        try expectEqual(view.intrinsicContentSize.width, widthWithoutArtwork + 16)

        view.update(
            presentation: presentation,
            artwork: TrackArtwork(
                data: Data([0x01]),
                mimeType: "application/octet-stream"
            ),
            date: Date()
        )
        try expectEqual(view.intrinsicContentSize.width, widthWithoutArtwork)
    }

    static func testDefaultStylePresetsIncludeMenuBarCompact() throws {
        let presets = LyricStylePreset.defaults

        try expectEqual(presets.first?.name, "Menu Bar Compact")
        try expectEqual(presets.first?.menuBarWidth, 180)
    }

    static func testStylePresetDerivesMenuBarStyle() throws {
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

    static func testMenuBarBehaviorUsesPresetWidth() throws {
        let startedAt = Date(timeIntervalSinceReferenceDate: 10)
        let compact = MenuBarStyle(viewportWidth: 160, fontSize: 13, fontWeight: .medium, textColorHex: "#FFFFFF", alignment: .leading)
        let wide = MenuBarStyle(viewportWidth: 320, fontSize: 13, fontWeight: .medium, textColorHex: "#FFFFFF", alignment: .leading)

        try expectEqual(MenuBarTextBehavior.behavior(contentWidth: 240, style: compact, startedAt: startedAt), .continuousMarquee(contentWidth: 240, startedAt: startedAt, targetDuration: nil))
        try expectEqual(MenuBarTextBehavior.behavior(contentWidth: 240, style: wide, startedAt: startedAt), .staticText)
    }

    static func testMenuBarLayoutShrinksForShortTextWithoutAccessory() throws {
        let layout = MenuBarStatusItemLayout(
            maxViewportWidth: 180,
            contentWidth: 120,
            horizontalPadding: 8,
            leadingAccessoryWidth: 0,
            trailingAccessoryWidth: 0
        )

        try expectEqual(layout.statusItemWidth, 136)
        try expectEqual(layout.textViewportMinX, 8)
        try expectEqual(layout.textViewportWidth, 120)
    }

    static func testMenuBarLayoutCapsLongTextAtPresetWidth() throws {
        let layout = MenuBarStatusItemLayout(
            maxViewportWidth: 180,
            contentWidth: 320,
            horizontalPadding: 8,
            leadingAccessoryWidth: 18,
            trailingAccessoryWidth: 20
        )

        try expectEqual(layout.statusItemWidth, 234)
        try expectEqual(layout.textViewportMinX, 26)
        try expectEqual(layout.textViewportWidth, 180)
    }

    static func testMenuBarLayoutAddsTrailingAccessoryOnlyWhenPresent() throws {
        let layout = MenuBarStatusItemLayout(
            maxViewportWidth: 180,
            contentWidth: 120,
            horizontalPadding: 8,
            leadingAccessoryWidth: 0,
            trailingAccessoryWidth: 20
        )

        try expectEqual(layout.statusItemWidth, 156)
        try expectEqual(layout.textViewportMinX, 8)
        try expectEqual(layout.textViewportWidth, 120)
    }

    static func testMenuBarLayoutUsesReducedRightPaddingForArtwork() throws {
        let layout = MenuBarStatusItemLayout(
            maxViewportWidth: 180,
            contentWidth: 120,
            leadingPadding: 8,
            trailingPadding: 4,
            leadingAccessoryWidth: 0,
            trailingAccessoryWidth: 20
        )

        try expectEqual(layout.statusItemWidth, 152)
        try expectEqual(layout.textViewportMinX, 8)
        try expectEqual(layout.textViewportWidth, 120)
    }

    static func testMenuBarDisplayTextUsesOriginalMode() throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let translation = LyricTranslationLine(sourceLineID: source.id, time: 10, translatedText: "I love you", romajiText: "kimi ga suki")

        let text = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .original, lineProgress: 0.75)

        try expectEqual(text.text, "君が好き")
        try expectEqual(text.accessibilityText, "君が好き")
    }

    static func testMenuBarDisplayTextFallsBackWhenTranslationMissing() throws {
        let source = LyricLine(time: 10, text: "君が好き")

        let text = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: nil, mode: .translation, lineProgress: 0.75)

        try expectEqual(text.text, "君が好き")
        try expectEqual(text.accessibilityText, "君が好き")
    }

    static func testMenuBarDisplayTextUsesTranslationMode() throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let translation = LyricTranslationLine(sourceLineID: source.id, time: 10, translatedText: "I love you", romajiText: nil)

        let text = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .translation, lineProgress: 0.25)

        try expectEqual(text.text, "I love you")
        try expectEqual(text.accessibilityText, "I love you")
    }

    static func testMenuBarDisplayTextAlternatesOriginalThenTranslation() throws {
        let source = LyricLine(time: 10, text: "君が好き")
        let translation = LyricTranslationLine(sourceLineID: source.id, time: 10, translatedText: "I love you", romajiText: nil)

        let early = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .alternateOriginalTranslation, lineProgress: 0.25)
        let late = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .alternateOriginalTranslation, lineProgress: 0.75)

        try expectEqual(early.text, "君が好き")
        try expectEqual(late.text, "I love you")
        try expectEqual(early.accessibilityText, "君が好き")
        try expectEqual(late.accessibilityText, "I love you")
    }

    static func testMenuBarDisplayTextAlternatesOriginalThenRomaji() throws {
        let source = LyricLine(time: 10, text: "きみ が すき")
        let translation = LyricTranslationLine(sourceLineID: source.id, time: 10, translatedText: nil, romajiText: "kimi ga suki")

        let early = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .alternateOriginalRomaji, lineProgress: 0.25)
        let late = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: translation, mode: .alternateOriginalRomaji, lineProgress: 0.75)

        try expectEqual(early.text, "きみ が すき")
        try expectEqual(late.text, "kimi ga suki")
        try expectEqual(early.accessibilityText, "きみ が すき")
        try expectEqual(late.accessibilityText, "kimi ga suki")
    }

    static func testMenuBarDisplayTextFallsBackToOriginalWhenRomajiMissing() throws {
        let source = LyricLine(time: 10, text: "hello")

        let text = MenuBarLyricDisplayText.resolve(sourceLine: source, translationLine: nil, mode: .alternateOriginalRomaji, lineProgress: 0.75)

        try expectEqual(text.text, "hello")
        try expectEqual(text.accessibilityText, "hello")
    }

    static func testMenuBarDisplayTextKeepsSourceWhenTranslationFailed() throws {
        let source = LyricLine(time: 10, text: "君が好き")

        let text = MenuBarLyricDisplayText.resolve(
            sourceLine: source,
            translationLine: nil,
            mode: .alternateOriginalTranslation,
            lineProgress: 0.9
        )

        try expectEqual(text.text, "君が好き")
    }


}
