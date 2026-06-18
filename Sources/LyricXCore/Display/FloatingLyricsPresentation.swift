import Foundation

public struct FloatingLyricsSegmentPresentation: Equatable, Sendable {
    public let text: String
    public let isHighlighted: Bool

    public init(text: String, isHighlighted: Bool) {
        self.text = text
        self.isHighlighted = isHighlighted
    }
}

public struct FloatingLyricsPresentation: Equatable, Sendable {
    public let currentText: String
    public let nextText: String?
    public let segments: [FloatingLyricsSegmentPresentation]
    public let usesKTV: Bool
    public let backgroundOpacity: Double

    public init(
        currentText: String,
        nextText: String?,
        segments: [FloatingLyricsSegmentPresentation],
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
        settings: AppSettings
    ) -> FloatingLyricsPresentation {
        let basePosition = playbackPosition + Double(settings.floatingLyricsLyricOffsetMs) / 1000
        let linePosition = basePosition + Double(settings.floatingLyricsLineOffsetMs) / 1000
        let segmentPosition = basePosition + Double(settings.floatingLyricsSegmentOffsetMs) / 1000

        if let context = timeline?.context(at: linePosition), let currentLine = context.currentLine {
            let ktvSegments = currentLine.segments.map {
                FloatingLyricsSegmentPresentation(text: $0.text, isHighlighted: $0.time <= segmentPosition)
            }
            let usesKTV = settings.floatingLyricsKTVEnabled && !ktvSegments.isEmpty

            return FloatingLyricsPresentation(
                currentText: currentLine.text,
                nextText: context.nextLine?.text,
                segments: usesKTV ? ktvSegments : [],
                usesKTV: usesKTV,
                backgroundOpacity: settings.floatingLyricsBackgroundOpacity
            )
        }

        let fallbackText: String
        if showsTrackWhenLyricsMissing, let trackText, !trackText.isEmpty {
            fallbackText = trackText
        } else {
            fallbackText = statusText
        }

        return FloatingLyricsPresentation(
            currentText: fallbackText,
            nextText: nil,
            segments: [],
            usesKTV: false,
            backgroundOpacity: settings.floatingLyricsBackgroundOpacity
        )
    }
}
