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
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationTimeline
}

public struct LocalLyricTranslationService: LyricTranslationService {
    public init() {}

    public func translationTimeline(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationTimeline {
        LyricTranslationTimeline(
            targetLanguage: targetLanguage,
            lines: sourceTimeline.lines.map { line in
                LyricTranslationLine(
                    sourceLineID: line.id,
                    time: line.time,
                    translatedText: nil,
                    romajiText: options.includeRomaji ? JapaneseRomaji.romanizedText(for: line.text) : nil
                )
            }
        )
    }
}

public enum TranslationProviderKind: String, Codable, Equatable, Sendable {
    case embeddedLyrics
    case netEaseCloudMusic
    case qqMusic
}

public struct LyricTranslationProviderOptions: Equatable, Sendable {
    public let sourceMode: TranslationSourceMode
    public let netEaseEnabled: Bool
    public let qqMusicEnabled: Bool
    public let includeRomaji: Bool

    public init(
        sourceMode: TranslationSourceMode = .auto,
        netEaseEnabled: Bool = false,
        qqMusicEnabled: Bool = false,
        includeRomaji: Bool = false
    ) {
        self.sourceMode = sourceMode
        self.netEaseEnabled = netEaseEnabled
        self.qqMusicEnabled = qqMusicEnabled
        self.includeRomaji = includeRomaji
    }

    public static let `default` = LyricTranslationProviderOptions()
}

public struct LyricTranslationProviderResult: Equatable, Sendable {
    public let timeline: LyricTranslationTimeline
    public let providerKind: TranslationProviderKind
    public let confidence: Double

    public init(timeline: LyricTranslationTimeline, providerKind: TranslationProviderKind, confidence: Double) {
        self.timeline = timeline
        self.providerKind = providerKind
        self.confidence = confidence
    }

    public var hasTranslatedText: Bool {
        timeline.lines.contains { line in
            line.translatedText?.nilIfBlank != nil
        }
    }
}

public protocol LyricTranslationProvider: Sendable {
    var kind: TranslationProviderKind { get }

    func translation(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationProviderResult?
}

public struct LyricTranslationProviderChain: Sendable {
    private let providers: [any LyricTranslationProvider]

    public init(providers: [any LyricTranslationProvider]) {
        self.providers = providers
    }

    public func translation(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationProviderResult? {
        var lastError: Error?
        for provider in providers {
            do {
                guard let result = try await provider.translation(
                    for: track,
                    sourceTimeline: sourceTimeline,
                    targetLanguage: targetLanguage,
                    options: options
                ) else {
                    continue
                }

                if result.hasTranslatedText {
                    return result
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        return nil
    }
}

public struct ProviderChainLyricTranslationService: LyricTranslationService {
    private let chain: LyricTranslationProviderChain

    public init(providers: [any LyricTranslationProvider] = []) {
        self.chain = LyricTranslationProviderChain(providers: providers)
    }

    public func translationTimeline(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationTimeline {
        if let result = try await chain.translation(for: track, sourceTimeline: sourceTimeline, targetLanguage: targetLanguage, options: options) {
            return result.timeline
        }

        return LyricTranslationTimeline(
            targetLanguage: targetLanguage,
            lines: sourceTimeline.lines.map { line in
                LyricTranslationLine(
                    sourceLineID: line.id,
                    time: line.time,
                    translatedText: nil,
                    romajiText: options.includeRomaji ? JapaneseRomaji.romanizedText(for: line.text) : nil
                )
            }
        )
    }
}
