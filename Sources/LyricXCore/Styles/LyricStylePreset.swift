import Foundation

public enum LyricAlignment: String, Codable, Equatable, Sendable {
    case leading
    case center
    case trailing
}

public struct LyricStylePreset: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var menuBarWidth: Double
    public var fontSize: Double
    public var fontWeight: String
    public var textColorHex: String
    public var alignment: LyricAlignment
    public var showsTrackWhenLyricsMissing: Bool

    public init(
        id: UUID,
        name: String,
        menuBarWidth: Double,
        fontSize: Double,
        fontWeight: String,
        textColorHex: String,
        alignment: LyricAlignment,
        showsTrackWhenLyricsMissing: Bool
    ) {
        self.id = id
        self.name = name
        self.menuBarWidth = menuBarWidth
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textColorHex = textColorHex
        self.alignment = alignment
        self.showsTrackWhenLyricsMissing = showsTrackWhenLyricsMissing
    }
}

public extension LyricStylePreset {
    static let defaults: [LyricStylePreset] = [
        LyricStylePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            name: "Menu Bar Compact",
            menuBarWidth: 220,
            fontSize: 13,
            fontWeight: "medium",
            textColorHex: "#FFFFFF",
            alignment: .leading,
            showsTrackWhenLyricsMissing: true
        ),
        LyricStylePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            name: "Menu Bar Wide",
            menuBarWidth: 320,
            fontSize: 13,
            fontWeight: "medium",
            textColorHex: "#FFFFFF",
            alignment: .leading,
            showsTrackWhenLyricsMissing: true
        ),
        LyricStylePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            name: "Window Preview",
            menuBarWidth: 260,
            fontSize: 18,
            fontWeight: "semibold",
            textColorHex: "#FFFFFF",
            alignment: .center,
            showsTrackWhenLyricsMissing: true
        )
    ]
}
