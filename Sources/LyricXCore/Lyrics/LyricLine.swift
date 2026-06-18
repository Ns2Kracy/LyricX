import Foundation

public struct LyricSegment: Equatable, Sendable {
    public let time: TimeInterval
    public let text: String

    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}

public struct LyricLine: Identifiable, Equatable, Sendable {
    public let time: TimeInterval
    public let text: String
    public let segments: [LyricSegment]

    public var id: String {
        "\(time)-\(text)"
    }

    public init(time: TimeInterval, text: String, segments: [LyricSegment] = []) {
        self.time = time
        self.text = text
        self.segments = segments
    }
}
