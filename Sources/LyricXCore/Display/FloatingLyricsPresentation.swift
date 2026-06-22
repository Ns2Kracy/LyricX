import Foundation

public struct LyricOverlaySegmentPresentation: Equatable, Sendable {
    public let text: String
    public let isHighlighted: Bool

    public init(text: String, isHighlighted: Bool) {
        self.text = text
        self.isHighlighted = isHighlighted
    }
}

public struct LyricOverlayPresentation: Equatable, Sendable {
    public let currentText: String
    public let nextText: String?
    public let segments: [LyricOverlaySegmentPresentation]
    public let usesKTV: Bool
    public let backgroundOpacity: Double

    public init(
        currentText: String,
        nextText: String?,
        segments: [LyricOverlaySegmentPresentation],
        usesKTV: Bool,
        backgroundOpacity: Double
    ) {
        self.currentText = currentText
        self.nextText = nextText
        self.segments = segments
        self.usesKTV = usesKTV
        self.backgroundOpacity = min(max(backgroundOpacity, 0), 1)
    }

    public static func make(
        timeline: LyricTimeline?,
        playbackPosition: TimeInterval,
        statusText: String,
        trackText: String?,
        showsTrackWhenLyricsMissing: Bool,
        settings: AppSettings,
        ktvEnabled: Bool,
        backgroundOpacity: Double
    ) -> LyricOverlayPresentation {
        let basePosition = playbackPosition + Double(settings.floatingLyricsLyricOffsetMs) / 1000
        let linePosition = basePosition + Double(settings.floatingLyricsLineOffsetMs) / 1000
        let segmentPosition = basePosition + Double(settings.floatingLyricsSegmentOffsetMs) / 1000

        if let context = timeline?.context(at: linePosition), let currentLine = context.currentLine {
            let ktvSegments = currentLine.segments.map {
                LyricOverlaySegmentPresentation(text: $0.text, isHighlighted: $0.time <= segmentPosition)
            }
            let usesKTV = ktvEnabled && !ktvSegments.isEmpty

            return LyricOverlayPresentation(
                currentText: currentLine.text,
                nextText: context.nextLine?.text,
                segments: usesKTV ? ktvSegments : [],
                usesKTV: usesKTV,
                backgroundOpacity: backgroundOpacity
            )
        }

        let fallbackText: String
        if showsTrackWhenLyricsMissing, let trackText, !trackText.isEmpty {
            fallbackText = trackText
        } else {
            fallbackText = statusText
        }

        return LyricOverlayPresentation(
            currentText: fallbackText,
            nextText: nil,
            segments: [],
            usesKTV: false,
            backgroundOpacity: backgroundOpacity
        )
    }
}

public typealias FloatingLyricsSegmentPresentation = LyricOverlaySegmentPresentation
public typealias FloatingLyricsPresentation = LyricOverlayPresentation
