import Foundation

public enum IslandLyricsDisplayState: Equatable, Sendable {
    case collapsed
    case expanded
}

public struct OverlaySize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct OverlayScreenFrame: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum IslandLyricsLayout {
    public static func size(
        for state: IslandLyricsDisplayState,
        preferredContentWidth: Double
    ) -> OverlaySize {
        switch state {
        case .collapsed:
            return OverlaySize(width: min(max(preferredContentWidth, 180), 420), height: 38)
        case .expanded:
            return OverlaySize(width: min(max(preferredContentWidth, 520), 680), height: 128)
        }
    }

    public static func frame(
        in visibleFrame: OverlayScreenFrame,
        state: IslandLyricsDisplayState,
        preferredContentWidth: Double,
        topInset: Double
    ) -> OverlayScreenFrame {
        let size = size(for: state, preferredContentWidth: preferredContentWidth)
        return OverlayScreenFrame(
            x: visibleFrame.x + (visibleFrame.width - size.width) / 2,
            y: visibleFrame.y + visibleFrame.height - size.height - topInset,
            width: size.width,
            height: size.height
        )
    }
}
