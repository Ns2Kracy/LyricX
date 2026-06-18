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
        return startPause + TimeInterval((contentWidth - viewportWidth) / speed)
    }

    public func offset(elapsedTime: TimeInterval, contentWidth: Double) -> Double {
        guard contentWidth > viewportWidth else {
            return 0
        }

        guard elapsedTime > startPause else {
            return 0
        }

        let movingTime = elapsedTime - startPause
        let travel = contentWidth - viewportWidth
        return -min(travel, movingTime * speed)
    }
}
