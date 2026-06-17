import Foundation

public struct MenuBarTimelineMarquee: Equatable, Sendable {
    public let viewportWidth: Double
    public let gap: Double
    public let speed: Double
    public let startPause: TimeInterval

    public init(viewportWidth: Double, gap: Double = 36, speed: Double = 34, startPause: TimeInterval = 0.8) {
        self.viewportWidth = max(viewportWidth, 1)
        self.gap = max(gap, 0)
        self.speed = max(speed, 1)
        self.startPause = max(startPause, 0)
    }

    public func cycleDuration(contentWidth: Double) -> TimeInterval {
        guard contentWidth > viewportWidth else {
            return startPause
        }
        return startPause + TimeInterval((contentWidth + gap) / speed)
    }

    public func offset(elapsedTime: TimeInterval, contentWidth: Double) -> Double {
        guard contentWidth > viewportWidth else {
            return 0
        }

        let cycle = cycleDuration(contentWidth: contentWidth)
        let cycleTime = elapsedTime.truncatingRemainder(dividingBy: cycle)
        guard cycleTime > startPause else {
            return 0
        }

        let movingTime = cycleTime - startPause
        let travel = contentWidth + gap
        return -min(travel, movingTime * speed)
    }
}
