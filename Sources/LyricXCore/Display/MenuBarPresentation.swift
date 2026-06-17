import Foundation

public enum MenuBarFontWeight: String, Codable, Equatable, Sendable {
    case regular
    case medium
    case semibold
}

public struct MenuBarStyle: Equatable, Sendable {
    public var viewportWidth: Double
    public var fontSize: Double
    public var fontWeight: MenuBarFontWeight
    public var textColorHex: String
    public var alignment: LyricAlignment

    public init(
        viewportWidth: Double,
        fontSize: Double,
        fontWeight: MenuBarFontWeight,
        textColorHex: String,
        alignment: LyricAlignment
    ) {
        self.viewportWidth = max(viewportWidth, 1)
        self.fontSize = max(fontSize, 1)
        self.fontWeight = fontWeight
        self.textColorHex = textColorHex
        self.alignment = alignment
    }

    public static let `default` = MenuBarStyle(
        viewportWidth: 220,
        fontSize: 13,
        fontWeight: .medium,
        textColorHex: "#FFFFFF",
        alignment: .leading
    )
}

public enum MenuBarTextBehavior: Equatable, Sendable {
    case staticText
    case continuousMarquee(contentWidth: Double, startedAt: Date)

    public static func behavior(contentWidth: Double, style: MenuBarStyle, startedAt: Date) -> MenuBarTextBehavior {
        guard contentWidth > style.viewportWidth else {
            return .staticText
        }

        return .continuousMarquee(contentWidth: contentWidth, startedAt: startedAt)
    }
}

public struct MenuBarPresentation: Equatable, Sendable {
    public let text: String
    public let accessibilityText: String
    public let symbol: String?
    public let behavior: MenuBarTextBehavior
    public let style: MenuBarStyle

    public init(
        text: String,
        accessibilityText: String,
        symbol: String?,
        behavior: MenuBarTextBehavior,
        style: MenuBarStyle = .default
    ) {
        self.text = text
        self.accessibilityText = accessibilityText
        self.symbol = symbol
        self.behavior = behavior
        self.style = style
    }
}

public extension LyricStylePreset {
    var menuBarStyle: MenuBarStyle {
        MenuBarStyle(
            viewportWidth: menuBarWidth,
            fontSize: fontSize,
            fontWeight: MenuBarFontWeight(rawValue: fontWeight.lowercased()) ?? .medium,
            textColorHex: textColorHex,
            alignment: alignment
        )
    }
}
