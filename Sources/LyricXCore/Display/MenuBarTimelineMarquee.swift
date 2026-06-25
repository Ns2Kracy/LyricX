import Foundation

public struct MenuBarTimelineMarquee: Equatable, Sendable {
    public let viewportWidth: Double
    public let gap: Double
    public let speed: Double
    public let startPause: TimeInterval
    public let endPause: TimeInterval

    public init(
        viewportWidth: Double,
        gap: Double = 36,
        speed: Double = 34,
        startPause: TimeInterval = 0.8,
        endPause: TimeInterval = 0.9
    ) {
        self.viewportWidth = max(viewportWidth, 1)
        self.gap = max(gap, 0)
        self.speed = max(speed, 1)
        self.startPause = max(startPause, 0)
        self.endPause = max(endPause, 0)
    }

    public func cycleDuration(contentWidth: Double) -> TimeInterval {
        guard contentWidth > viewportWidth else {
            return startPause
        }
        return startPause + TimeInterval((contentWidth - viewportWidth) / speed) + endPause
    }

    public func offset(elapsedTime: TimeInterval, contentWidth: Double) -> Double {
        guard contentWidth > viewportWidth else {
            return 0
        }

        guard elapsedTime > startPause else {
            return 0
        }

        let travel = contentWidth - viewportWidth
        let cycleElapsed = elapsedTime.truncatingRemainder(dividingBy: cycleDuration(contentWidth: contentWidth))
        guard cycleElapsed > startPause else {
            return 0
        }

        let movingTime = cycleElapsed - startPause
        return -min(travel, movingTime * speed)
    }
}
