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

public struct AppSettings: Codable, Equatable, Sendable {
    public var showsLyrics: Bool
    public var showsTrackWhenLyricsMissing: Bool
    public var menuBarFrameRate: MenuBarAnimationFrameRate
    public var translationEnabled: Bool
    public var translationTargetLanguage: TranslationLanguage
    public var japaneseRomajiEnabled: Bool
    public var menuBarLyricDisplayMode: MenuBarLyricDisplayMode

    public init(
        showsLyrics: Bool = true,
        showsTrackWhenLyricsMissing: Bool = true,
        menuBarFrameRate: MenuBarAnimationFrameRate = .default,
        translationEnabled: Bool = false,
        translationTargetLanguage: TranslationLanguage = .system,
        japaneseRomajiEnabled: Bool = false,
        menuBarLyricDisplayMode: MenuBarLyricDisplayMode = .original
    ) {
        self.showsLyrics = showsLyrics
        self.showsTrackWhenLyricsMissing = showsTrackWhenLyricsMissing
        self.menuBarFrameRate = menuBarFrameRate
        self.translationEnabled = translationEnabled
        self.translationTargetLanguage = translationTargetLanguage
        self.japaneseRomajiEnabled = japaneseRomajiEnabled
        self.menuBarLyricDisplayMode = menuBarLyricDisplayMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        showsLyrics = try container.decodeIfPresent(Bool.self, forKey: .showsLyrics) ?? defaults.showsLyrics
        showsTrackWhenLyricsMissing = try container.decodeIfPresent(Bool.self, forKey: .showsTrackWhenLyricsMissing) ?? defaults.showsTrackWhenLyricsMissing
        menuBarFrameRate = try container.decodeIfPresent(MenuBarAnimationFrameRate.self, forKey: .menuBarFrameRate) ?? defaults.menuBarFrameRate
        translationEnabled = try container.decodeIfPresent(Bool.self, forKey: .translationEnabled) ?? defaults.translationEnabled
        translationTargetLanguage = try container.decodeIfPresent(TranslationLanguage.self, forKey: .translationTargetLanguage) ?? defaults.translationTargetLanguage
        japaneseRomajiEnabled = try container.decodeIfPresent(Bool.self, forKey: .japaneseRomajiEnabled) ?? defaults.japaneseRomajiEnabled
        menuBarLyricDisplayMode = try container.decodeIfPresent(MenuBarLyricDisplayMode.self, forKey: .menuBarLyricDisplayMode) ?? defaults.menuBarLyricDisplayMode
    }

    private enum CodingKeys: String, CodingKey {
        case showsLyrics
        case showsTrackWhenLyricsMissing
        case menuBarFrameRate
        case translationEnabled
        case translationTargetLanguage
        case japaneseRomajiEnabled
        case menuBarLyricDisplayMode
    }
}

public extension AppSettings {
    static let `default` = AppSettings()
}
