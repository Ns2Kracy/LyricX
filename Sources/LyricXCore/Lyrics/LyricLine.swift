import Foundation

public struct LyricLine: Identifiable, Equatable, Sendable {
    public let time: TimeInterval
    public let text: String

    public var id: String {
        "\(time)-\(text)"
    }

    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}
