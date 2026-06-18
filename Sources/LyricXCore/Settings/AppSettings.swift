import Foundation

public struct FloatingLyricsWindowFrame: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var showsLyrics: Bool
    public var showsTrackWhenLyricsMissing: Bool
    public var menuBarFrameRate: MenuBarAnimationFrameRate
    public var showsFloatingLyrics: Bool
    public var floatingLyricsLocked: Bool
    public var floatingLyricsClickThrough: Bool
    public var floatingLyricsKTVEnabled: Bool
    public var floatingLyricsBackgroundOpacity: Double
    public var floatingLyricsLyricOffsetMs: Int
    public var floatingLyricsLineOffsetMs: Int
    public var floatingLyricsSegmentOffsetMs: Int
    public var floatingLyricsWindowFrame: FloatingLyricsWindowFrame?

    public init(
        showsLyrics: Bool = true,
        showsTrackWhenLyricsMissing: Bool = true,
        menuBarFrameRate: MenuBarAnimationFrameRate = .default,
        showsFloatingLyrics: Bool = false,
        floatingLyricsLocked: Bool = false,
        floatingLyricsClickThrough: Bool = false,
        floatingLyricsKTVEnabled: Bool = true,
        floatingLyricsBackgroundOpacity: Double = 0.68,
        floatingLyricsLyricOffsetMs: Int = 0,
        floatingLyricsLineOffsetMs: Int = 0,
        floatingLyricsSegmentOffsetMs: Int = 0,
        floatingLyricsWindowFrame: FloatingLyricsWindowFrame? = nil
    ) {
        self.showsLyrics = showsLyrics
        self.showsTrackWhenLyricsMissing = showsTrackWhenLyricsMissing
        self.menuBarFrameRate = menuBarFrameRate
        self.showsFloatingLyrics = showsFloatingLyrics
        self.floatingLyricsLocked = floatingLyricsLocked
        self.floatingLyricsClickThrough = floatingLyricsClickThrough
        self.floatingLyricsKTVEnabled = floatingLyricsKTVEnabled
        self.floatingLyricsBackgroundOpacity = floatingLyricsBackgroundOpacity
        self.floatingLyricsLyricOffsetMs = floatingLyricsLyricOffsetMs
        self.floatingLyricsLineOffsetMs = floatingLyricsLineOffsetMs
        self.floatingLyricsSegmentOffsetMs = floatingLyricsSegmentOffsetMs
        self.floatingLyricsWindowFrame = floatingLyricsWindowFrame
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        showsLyrics = try container.decodeIfPresent(Bool.self, forKey: .showsLyrics) ?? defaults.showsLyrics
        showsTrackWhenLyricsMissing = try container.decodeIfPresent(Bool.self, forKey: .showsTrackWhenLyricsMissing) ?? defaults.showsTrackWhenLyricsMissing
        menuBarFrameRate = try container.decodeIfPresent(MenuBarAnimationFrameRate.self, forKey: .menuBarFrameRate) ?? defaults.menuBarFrameRate
        showsFloatingLyrics = try container.decodeIfPresent(Bool.self, forKey: .showsFloatingLyrics) ?? defaults.showsFloatingLyrics
        floatingLyricsLocked = try container.decodeIfPresent(Bool.self, forKey: .floatingLyricsLocked) ?? defaults.floatingLyricsLocked
        floatingLyricsClickThrough = try container.decodeIfPresent(Bool.self, forKey: .floatingLyricsClickThrough) ?? defaults.floatingLyricsClickThrough
        floatingLyricsKTVEnabled = try container.decodeIfPresent(Bool.self, forKey: .floatingLyricsKTVEnabled) ?? defaults.floatingLyricsKTVEnabled
        floatingLyricsBackgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .floatingLyricsBackgroundOpacity) ?? defaults.floatingLyricsBackgroundOpacity
        floatingLyricsLyricOffsetMs = try container.decodeIfPresent(Int.self, forKey: .floatingLyricsLyricOffsetMs) ?? defaults.floatingLyricsLyricOffsetMs
        floatingLyricsLineOffsetMs = try container.decodeIfPresent(Int.self, forKey: .floatingLyricsLineOffsetMs) ?? defaults.floatingLyricsLineOffsetMs
        floatingLyricsSegmentOffsetMs = try container.decodeIfPresent(Int.self, forKey: .floatingLyricsSegmentOffsetMs) ?? defaults.floatingLyricsSegmentOffsetMs
        floatingLyricsWindowFrame = try container.decodeIfPresent(FloatingLyricsWindowFrame.self, forKey: .floatingLyricsWindowFrame)
    }

    private enum CodingKeys: String, CodingKey {
        case showsLyrics
        case showsTrackWhenLyricsMissing
        case menuBarFrameRate
        case showsFloatingLyrics
        case floatingLyricsLocked
        case floatingLyricsClickThrough
        case floatingLyricsKTVEnabled
        case floatingLyricsBackgroundOpacity
        case floatingLyricsLyricOffsetMs
        case floatingLyricsLineOffsetMs
        case floatingLyricsSegmentOffsetMs
        case floatingLyricsWindowFrame
    }
}

public extension AppSettings {
    static let `default` = AppSettings()
}
