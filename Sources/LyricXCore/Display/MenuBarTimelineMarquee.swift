import Foundation

public struct MenuBarTimelineMarquee: Equatable, Sendable {
    public let viewportWidth: Double
    public let gap: Double
    public let speed: Double
    public let startPause: TimeInterval

    public init(
        viewportWidth: Double,
        gap: Double = 36,
        speed: Double = 34,
        startPause: TimeInterval = 0.8
    ) {
        self.viewportWidth = max(viewportWidth, 1)
        self.gap = max(gap, 0)
        self.speed = max(speed, 1)
        self.startPause = max(startPause, 0)
    }

    public func effectiveStartPause(targetDuration: TimeInterval? = nil) -> TimeInterval {
        guard let targetDuration, targetDuration > 0 else {
            return startPause
        }

        return min(startPause, targetDuration * 0.25)
    }

    public func scrollDuration(contentWidth: Double, targetDuration: TimeInterval? = nil) -> TimeInterval {
        guard contentWidth > viewportWidth else {
            return 0
        }

        let travel = contentWidth - viewportWidth
        if let targetDuration, targetDuration > 0 {
            return min(TimeInterval(travel / speed), max(targetDuration - effectiveStartPause(targetDuration: targetDuration), 0.1))
        }

        return TimeInterval(travel / speed)
    }

    public func offset(elapsedTime: TimeInterval, contentWidth: Double, targetDuration: TimeInterval? = nil) -> Double {
        guard contentWidth > viewportWidth else {
            return 0
        }

        let startPause = effectiveStartPause(targetDuration: targetDuration)
        guard elapsedTime > startPause else {
            return 0
        }

        let travel = contentWidth - viewportWidth
        let duration = scrollDuration(contentWidth: contentWidth, targetDuration: targetDuration)
        guard duration > 0 else {
            return -travel
        }

        let progress = min(max((elapsedTime - startPause) / duration, 0), 1)
        return -(travel * progress)
    }
}
