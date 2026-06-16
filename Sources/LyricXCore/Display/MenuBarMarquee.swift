import Foundation

public struct MenuBarMarquee: Sendable {
    public let visibleCharacters: Int
    public let paddingCharacters: Int

    public init(visibleCharacters: Int, paddingCharacters: Int = 4) {
        self.visibleCharacters = max(1, visibleCharacters)
        self.paddingCharacters = max(1, paddingCharacters)
    }

    public func displayText(_ text: String, offset: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > visibleCharacters else {
            return trimmed
        }

        let padded = Array(trimmed + String(repeating: " ", count: paddingCharacters))
        let start = offset % padded.count
        return String((0..<visibleCharacters).map { padded[(start + $0) % padded.count] })
    }
}
