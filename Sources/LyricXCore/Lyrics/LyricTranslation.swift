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

public enum TranslationProviderKind: String, Codable, Equatable, Sendable {
    case embeddedLyrics
    case netEaseCloudMusic
    case qqMusic
    case appleSystem
    case openAICompatible
}

public struct LyricTranslationProviderOptions: Equatable, Sendable {
    public let sourceMode: TranslationSourceMode
    public let machineProvider: MachineTranslationProvider
    public let openAICompatibleBaseURL: String
    public let openAICompatibleModel: String
    public let openAICompatibleAPIKey: String
    public let netEaseEnabled: Bool
    public let qqMusicEnabled: Bool
    public let includeRomaji: Bool

    public init(
        sourceMode: TranslationSourceMode = .auto,
        machineProvider: MachineTranslationProvider = .none,
        openAICompatibleBaseURL: String = "",
        openAICompatibleModel: String = "",
        openAICompatibleAPIKey: String = "",
        netEaseEnabled: Bool = false,
        qqMusicEnabled: Bool = false,
        includeRomaji: Bool = false
    ) {
        self.sourceMode = sourceMode
        self.machineProvider = machineProvider
        self.openAICompatibleBaseURL = openAICompatibleBaseURL
        self.openAICompatibleModel = openAICompatibleModel
        self.openAICompatibleAPIKey = openAICompatibleAPIKey
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

public enum LyricTranslationProviderError: LocalizedError, Equatable, Sendable {
    case missingConfiguration(String)
    case invalidEndpoint
    case invalidResponse
    case requestFailed(statusCode: Int)
    case invalidProviderPayload

    public var errorDescription: String? {
        switch self {
        case .missingConfiguration(let message):
            return message
        case .invalidEndpoint:
            return "Translation provider endpoint is invalid."
        case .invalidResponse:
            return "Translation provider returned an invalid response."
        case .requestFailed(let statusCode):
            return "Translation provider request failed with HTTP \(statusCode)."
        case .invalidProviderPayload:
            return "Translation provider returned unreadable translations."
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

public struct OpenAICompatibleLyricTranslationProvider: LyricTranslationProvider {
    public let kind: TranslationProviderKind = .openAICompatible

    public init() {}

    public func translation(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationProviderResult? {
        guard options.machineProvider == .openAICompatible else {
            return nil
        }

        let baseURL = options.openAICompatibleBaseURL.nilIfBlank
        let model = options.openAICompatibleModel.nilIfBlank
        let apiKey = options.openAICompatibleAPIKey.nilIfBlank
        guard let baseURL, let model, let apiKey else {
            throw LyricTranslationProviderError.missingConfiguration("OpenAI-compatible translation requires a base URL, model, and API key.")
        }
        guard let url = URL(string: baseURL) else {
            throw LyricTranslationProviderError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            OpenAICompatibleRequest(
                model: model,
                messages: [
                    OpenAICompatibleMessage(role: "system", content: systemPrompt(for: targetLanguage)),
                    OpenAICompatibleMessage(role: "user", content: userPrompt(for: track, sourceTimeline: sourceTimeline))
                ],
                temperature: 0
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricTranslationProviderError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LyricTranslationProviderError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let timeline = try Self.decodeTimeline(fromChatCompletionsResponse: data, sourceTimeline: sourceTimeline, targetLanguage: targetLanguage, includeRomaji: options.includeRomaji)
        return LyricTranslationProviderResult(timeline: timeline, providerKind: kind, confidence: 0.7)
    }

    public static func decodeTimeline(
        from data: Data,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) throws -> LyricTranslationTimeline {
        let payload = try JSONDecoder().decode(OpenAICompatibleTranslationsPayload.self, from: data)
        return timeline(from: payload, sourceTimeline: sourceTimeline, targetLanguage: targetLanguage, includeRomaji: includeRomaji)
    }

    private static func decodeTimeline(
        fromChatCompletionsResponse data: Data,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) throws -> LyricTranslationTimeline {
        let response = try JSONDecoder().decode(OpenAICompatibleResponse.self, from: data)
        guard let content = response.choices.first?.message.content.data(using: .utf8) else {
            throw LyricTranslationProviderError.invalidProviderPayload
        }
        return try decodeTimeline(from: content, sourceTimeline: sourceTimeline, targetLanguage: targetLanguage, includeRomaji: includeRomaji)
    }

    private static func timeline(
        from payload: OpenAICompatibleTranslationsPayload,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        includeRomaji: Bool
    ) -> LyricTranslationTimeline {
        let translationsByID = Dictionary(uniqueKeysWithValues: payload.translations.map { ($0.id, $0.text) })
        return LyricTranslationTimeline(
            targetLanguage: targetLanguage,
            lines: sourceTimeline.lines.map { line in
                LyricTranslationLine(
                    sourceLineID: line.id,
                    time: line.time,
                    translatedText: translationsByID[line.id],
                    romajiText: includeRomaji ? JapaneseRomaji.romanizedText(for: line.text) : nil
                )
            }
        )
    }

    private func systemPrompt(for targetLanguage: TranslationLanguage) -> String {
        "Translate song lyrics into \(targetLanguage.label). Return only strict JSON with shape {\"translations\":[{\"id\":\"source-line-id\",\"text\":\"translated lyric\"}]}. Preserve meaning and line count where possible."
    }

    private func userPrompt(for track: PlaybackTrack, sourceTimeline: LyricTimeline) -> String {
        let lines = sourceTimeline.lines.map { line in
            "{\"id\":\"\(line.id)\",\"text\":\"\(line.text)\"}"
        }.joined(separator: ",")
        return "Track: \(track.title) - \(track.artist)\nLines: [\(lines)]"
    }
}

private struct OpenAICompatibleRequest: Encodable {
    let model: String
    let messages: [OpenAICompatibleMessage]
    let temperature: Double
}

private struct OpenAICompatibleMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAICompatibleResponse: Decodable {
    struct Choice: Decodable {
        let message: OpenAICompatibleMessage
    }

    let choices: [Choice]
}

private struct OpenAICompatibleTranslationsPayload: Decodable {
    struct Translation: Decodable {
        let id: String
        let text: String
    }

    let translations: [Translation]
}
