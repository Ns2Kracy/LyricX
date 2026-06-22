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
    public var showsIslandLyrics: Bool
    public var islandLyricsAutoExpandOnHover: Bool
    public var islandLyricsClickThrough: Bool
    public var islandLyricsKTVEnabled: Bool
    public var islandLyricsBackgroundOpacity: Double

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
        floatingLyricsWindowFrame: FloatingLyricsWindowFrame? = nil,
        showsIslandLyrics: Bool = false,
        islandLyricsAutoExpandOnHover: Bool = true,
        islandLyricsClickThrough: Bool = false,
        islandLyricsKTVEnabled: Bool = true,
        islandLyricsBackgroundOpacity: Double = 0.82
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
        self.showsIslandLyrics = showsIslandLyrics
        self.islandLyricsAutoExpandOnHover = islandLyricsAutoExpandOnHover
        self.islandLyricsClickThrough = islandLyricsClickThrough
        self.islandLyricsKTVEnabled = islandLyricsKTVEnabled
        self.islandLyricsBackgroundOpacity = islandLyricsBackgroundOpacity
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
        showsIslandLyrics = try container.decodeIfPresent(Bool.self, forKey: .showsIslandLyrics) ?? defaults.showsIslandLyrics
        islandLyricsAutoExpandOnHover = try container.decodeIfPresent(Bool.self, forKey: .islandLyricsAutoExpandOnHover) ?? defaults.islandLyricsAutoExpandOnHover
        islandLyricsClickThrough = try container.decodeIfPresent(Bool.self, forKey: .islandLyricsClickThrough) ?? defaults.islandLyricsClickThrough
        islandLyricsKTVEnabled = try container.decodeIfPresent(Bool.self, forKey: .islandLyricsKTVEnabled) ?? defaults.islandLyricsKTVEnabled
        islandLyricsBackgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .islandLyricsBackgroundOpacity) ?? defaults.islandLyricsBackgroundOpacity
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
        case showsIslandLyrics
        case islandLyricsAutoExpandOnHover
        case islandLyricsClickThrough
        case islandLyricsKTVEnabled
        case islandLyricsBackgroundOpacity
    }
}

public extension AppSettings {
    static let `default` = AppSettings()
}
