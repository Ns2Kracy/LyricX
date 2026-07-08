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

    public func currentLine(at position: TimeInterval, switchLeadTolerance: TimeInterval = 0) -> LyricLine? {
        let effectivePosition = max(0, position - max(0, switchLeadTolerance))
        return lines.last { $0.time <= effectivePosition }
    }

    public func nextLine(after position: TimeInterval) -> LyricLine? {
        lines.first { $0.time > position }
    }

    public func context(at position: TimeInterval, switchLeadTolerance: TimeInterval = 0) -> LyricTimelineContext {
        let current = currentLine(at: position, switchLeadTolerance: switchLeadTolerance)
        let effectivePosition = max(0, position - max(0, switchLeadTolerance))
        let previous = current.flatMap { current in
            lines.last { $0.time < current.time }
        }

        return LyricTimelineContext(
            previousLine: previous,
            currentLine: current,
            nextLine: nextLine(after: effectivePosition)
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
