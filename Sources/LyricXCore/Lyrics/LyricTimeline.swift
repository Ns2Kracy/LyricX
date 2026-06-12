import Foundation

public struct LyricTimeline: Equatable, Sendable {
    public let lines: [LyricLine]

    public init(lines: [LyricLine]) {
        self.lines = lines.sorted { lhs, rhs in
            if lhs.time == rhs.time {
                lhs.text < rhs.text
            } else {
                lhs.time < rhs.time
            }
        }
    }

    public func currentLine(at position: TimeInterval) -> LyricLine? {
        lines.last { $0.time <= position }
    }

    public func nextLine(after position: TimeInterval) -> LyricLine? {
        lines.first { $0.time > position }
    }
}
