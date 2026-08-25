import Foundation

public enum TranslationLanguage: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system:
            return "System"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .traditionalChinese:
            return "Traditional Chinese"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        }
    }
}

public enum MenuBarLyricDisplayMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case original
    case translation
    case alternateOriginalTranslation
    case alternateOriginalRomaji

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .original:
            return "Original"
        case .translation:
            return "Translation"
        case .alternateOriginalTranslation:
            return "Original / Translation"
        case .alternateOriginalRomaji:
            return "Original / Romaji"
        }
    }
}

public enum TranslationSourceMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case auto
    case existingLyricsOnly
    case chineseLyricSourcesOnly
    case machineTranslationOnly

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .auto:
            return "Auto"
        case .existingLyricsOnly:
            return "Existing lyric translations only"
        case .chineseLyricSourcesOnly:
            return "Chinese lyric sources only"
        case .machineTranslationOnly:
            return "Machine translation only"
        }
    }
}

public enum MachineTranslationProvider: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case none
    case openAICompatible

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none:
            return "None"
        case .openAICompatible:
            return "OpenAI-compatible"
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var showsLyrics: Bool
    public var showsTrackWhenLyricsMissing: Bool
    public var menuBarFrameRate: MenuBarAnimationFrameRate
    public var showsMenuBarArtwork: Bool
    public var translationEnabled: Bool
    public var translationTargetLanguage: TranslationLanguage
    public var japaneseRomajiEnabled: Bool
    public var menuBarLyricDisplayMode: MenuBarLyricDisplayMode
    public var translationSourceMode: TranslationSourceMode
    public var machineTranslationProvider: MachineTranslationProvider
    public var openAICompatibleBaseURL: String
    public var openAICompatibleModel: String
    public var openAICompatibleAPIKey: String
    public var netEaseTranslationSourceEnabled: Bool
    public var qqMusicTranslationSourceEnabled: Bool

    public init(
        showsLyrics: Bool = true,
        showsTrackWhenLyricsMissing: Bool = true,
        menuBarFrameRate: MenuBarAnimationFrameRate = .default,
        showsMenuBarArtwork: Bool = true,
        translationEnabled: Bool = false,
        translationTargetLanguage: TranslationLanguage = .system,
        japaneseRomajiEnabled: Bool = false,
        menuBarLyricDisplayMode: MenuBarLyricDisplayMode = .original,
        translationSourceMode: TranslationSourceMode = .auto,
        machineTranslationProvider: MachineTranslationProvider = .none,
        openAICompatibleBaseURL: String = "",
        openAICompatibleModel: String = "",
        openAICompatibleAPIKey: String = "",
        netEaseTranslationSourceEnabled: Bool = false,
        qqMusicTranslationSourceEnabled: Bool = false
    ) {
        self.showsLyrics = showsLyrics
        self.showsTrackWhenLyricsMissing = showsTrackWhenLyricsMissing
        self.menuBarFrameRate = menuBarFrameRate
        self.showsMenuBarArtwork = showsMenuBarArtwork
        self.translationEnabled = translationEnabled
        self.translationTargetLanguage = translationTargetLanguage
        self.japaneseRomajiEnabled = japaneseRomajiEnabled
        self.menuBarLyricDisplayMode = menuBarLyricDisplayMode
        self.translationSourceMode = translationSourceMode
        self.machineTranslationProvider = machineTranslationProvider
        self.openAICompatibleBaseURL = openAICompatibleBaseURL
        self.openAICompatibleModel = openAICompatibleModel
        self.openAICompatibleAPIKey = openAICompatibleAPIKey
        self.netEaseTranslationSourceEnabled = netEaseTranslationSourceEnabled
        self.qqMusicTranslationSourceEnabled = qqMusicTranslationSourceEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        showsLyrics = try container.decodeIfPresent(Bool.self, forKey: .showsLyrics) ?? defaults.showsLyrics
        showsTrackWhenLyricsMissing = try container.decodeIfPresent(Bool.self, forKey: .showsTrackWhenLyricsMissing) ?? defaults.showsTrackWhenLyricsMissing
        menuBarFrameRate = try container.decodeIfPresent(MenuBarAnimationFrameRate.self, forKey: .menuBarFrameRate) ?? defaults.menuBarFrameRate
        showsMenuBarArtwork = try container.decodeIfPresent(Bool.self, forKey: .showsMenuBarArtwork) ?? defaults.showsMenuBarArtwork
        translationEnabled = try container.decodeIfPresent(Bool.self, forKey: .translationEnabled) ?? defaults.translationEnabled
        translationTargetLanguage = try container.decodeIfPresent(TranslationLanguage.self, forKey: .translationTargetLanguage) ?? defaults.translationTargetLanguage
        japaneseRomajiEnabled = try container.decodeIfPresent(Bool.self, forKey: .japaneseRomajiEnabled) ?? defaults.japaneseRomajiEnabled
        menuBarLyricDisplayMode = try container.decodeIfPresent(MenuBarLyricDisplayMode.self, forKey: .menuBarLyricDisplayMode) ?? defaults.menuBarLyricDisplayMode
        translationSourceMode = try container.decodeIfPresent(TranslationSourceMode.self, forKey: .translationSourceMode) ?? defaults.translationSourceMode
        machineTranslationProvider = try container.decodeIfPresent(MachineTranslationProvider.self, forKey: .machineTranslationProvider) ?? defaults.machineTranslationProvider
        openAICompatibleBaseURL = try container.decodeIfPresent(String.self, forKey: .openAICompatibleBaseURL) ?? defaults.openAICompatibleBaseURL
        openAICompatibleModel = try container.decodeIfPresent(String.self, forKey: .openAICompatibleModel) ?? defaults.openAICompatibleModel
        openAICompatibleAPIKey = try container.decodeIfPresent(String.self, forKey: .openAICompatibleAPIKey) ?? defaults.openAICompatibleAPIKey
        netEaseTranslationSourceEnabled = try container.decodeIfPresent(Bool.self, forKey: .netEaseTranslationSourceEnabled) ?? defaults.netEaseTranslationSourceEnabled
        qqMusicTranslationSourceEnabled = try container.decodeIfPresent(Bool.self, forKey: .qqMusicTranslationSourceEnabled) ?? defaults.qqMusicTranslationSourceEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case showsLyrics
        case showsTrackWhenLyricsMissing
        case menuBarFrameRate
        case showsMenuBarArtwork
        case translationEnabled
        case translationTargetLanguage
        case japaneseRomajiEnabled
        case menuBarLyricDisplayMode
        case translationSourceMode
        case machineTranslationProvider
        case openAICompatibleBaseURL
        case openAICompatibleModel
        case openAICompatibleAPIKey
        case netEaseTranslationSourceEnabled
        case qqMusicTranslationSourceEnabled
    }
}

public extension AppSettings {
    static let `default` = AppSettings()
}
