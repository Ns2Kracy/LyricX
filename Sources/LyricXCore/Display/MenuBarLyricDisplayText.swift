import Foundation

public struct MenuBarLyricDisplayText: Equatable, Sendable {
    public let text: String
    public let accessibilityText: String

    public init(text: String, accessibilityText: String) {
        self.text = text
        self.accessibilityText = accessibilityText
    }

    public static func resolve(
        sourceLine: LyricLine,
        translationLine: LyricTranslationLine?,
        mode: MenuBarLyricDisplayMode,
        lineProgress: Double
    ) -> MenuBarLyricDisplayText {
        let source = sourceLine.text
        let translation = translationLine?.translatedText?.nilIfBlank
        let romaji = translationLine?.romajiText?.nilIfBlank
        let useSecondary = lineProgress >= 0.5

        let selected: String
        switch mode {
        case .original:
            selected = source
        case .translation:
            selected = translation ?? source
        case .alternateOriginalTranslation:
            selected = useSecondary ? (translation ?? source) : source
        case .alternateOriginalRomaji:
            selected = useSecondary ? (romaji ?? source) : source
        }

        let accessibilityParts = [source, translation, romaji]
            .compactMap { $0?.nilIfBlank }
            .reduce(into: [String]()) { result, value in
                if !result.contains(value) {
                    result.append(value)
                }
            }

        return MenuBarLyricDisplayText(
            text: selected,
            accessibilityText: accessibilityParts.isEmpty ? selected : accessibilityParts.joined(separator: ", ")
        )
    }
}
