import Foundation

public struct LyricTranslationLine: Identifiable, Codable, Equatable, Sendable {
    public let sourceLineID: String
    public let time: TimeInterval
    public let translatedText: String?
    public let romajiText: String?

    public var id: String { sourceLineID }

    public init(sourceLineID: String, time: TimeInterval, translatedText: String?, romajiText: String?) {
        self.sourceLineID = sourceLineID
        self.time = time
        self.translatedText = translatedText?.nilIfBlank
        self.romajiText = romajiText?.nilIfBlank
    }
}

public struct LyricTranslationTimeline: Codable, Equatable, Sendable {
    public let targetLanguage: TranslationLanguage
    public let lines: [LyricTranslationLine]

    public init(targetLanguage: TranslationLanguage, lines: [LyricTranslationLine]) {
        self.targetLanguage = targetLanguage
        self.lines = lines.sorted { lhs, rhs in
            if lhs.time == rhs.time {
                lhs.sourceLineID < rhs.sourceLineID
            } else {
                lhs.time < rhs.time
            }
        }
    }

    public func line(for sourceLine: LyricLine) -> LyricTranslationLine? {
        lines.first { line in
            line.sourceLineID == sourceLine.id && abs(line.time - sourceLine.time) < 0.001
        }
    }
}

public enum LyricTranslationStatus: Equatable, Sendable {
    case disabled
    case loading
    case available
    case failed(String)

    public var label: String {
        switch self {
        case .disabled:
            return "Translation disabled"
        case .loading:
            return "Translating lyrics"
        case .available:
            return "Translation available"
        case .failed(let message):
            return "Translation failed: \(message)"
        }
    }
}

public protocol LyricTranslationService: Sendable {
    func translationTimeline(
        for sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) async throws -> LyricTranslationTimeline
}

public struct LocalLyricTranslationService: LyricTranslationService {
    public init() {}

    public func translationTimeline(
        for sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) async throws -> LyricTranslationTimeline {
        LyricTranslationTimeline(
            targetLanguage: targetLanguage,
            lines: sourceTimeline.lines.map { line in
                LyricTranslationLine(
                    sourceLineID: line.id,
                    time: line.time,
                    translatedText: nil,
                    romajiText: includeRomaji ? JapaneseRomaji.romanizedText(for: line.text) : nil
                )
            }
        )
    }
}
