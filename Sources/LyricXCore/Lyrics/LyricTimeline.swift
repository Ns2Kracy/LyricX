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

    public func context(at position: TimeInterval) -> LyricTimelineContext {
        let current = currentLine(at: position)
        let previous = current.flatMap { current in
            lines.last { $0.time < current.time }
        }

        return LyricTimelineContext(
            previousLine: previous,
            currentLine: current,
            nextLine: nextLine(after: position)
        )
    }
}

public struct LyricTimelineContext: Equatable, Sendable {
    public let previousLine: LyricLine?
    public let currentLine: LyricLine?
    public let nextLine: LyricLine?

    public init(previousLine: LyricLine?, currentLine: LyricLine?, nextLine: LyricLine?) {
        self.previousLine = previousLine
        self.currentLine = currentLine
        self.nextLine = nextLine
    }

    public static let empty = LyricTimelineContext(previousLine: nil, currentLine: nil, nextLine: nil)
}
