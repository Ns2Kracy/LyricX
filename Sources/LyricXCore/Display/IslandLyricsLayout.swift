import Foundation

public enum IslandLyricsDisplayState: Equatable, Sendable {
    case collapsed
    case expanded
}

public enum IslandLyricsLayout {
    public struct Size: Equatable, Sendable {
        public let width: Double
        public let height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    public struct ScreenFrame: Equatable, Sendable {
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

    public static func size(
        for state: IslandLyricsDisplayState,
        preferredContentWidth: Double
    ) -> Size {
        switch state {
        case .collapsed:
            return Size(width: min(max(preferredContentWidth, 180), 420), height: 22)
        case .expanded:
            return Size(width: min(max(preferredContentWidth, 520), 680), height: 128)
        }
    }

    public static func frame(
        in visibleFrame: ScreenFrame,
        state: IslandLyricsDisplayState,
        preferredContentWidth: Double,
        topInset: Double
    ) -> ScreenFrame {
        let size = size(for: state, preferredContentWidth: preferredContentWidth)
        let visibleWidth = max(visibleFrame.width, 0)
        let width = min(size.width, visibleWidth)
        return ScreenFrame(
            x: visibleFrame.x + (visibleWidth - width) / 2,
            y: visibleFrame.y + visibleFrame.height - size.height - topInset,
            width: width,
            height: size.height
        )
    }

    public static func frame(
        in screenFrame: ScreenFrame,
        visibleFrame: ScreenFrame,
        state: IslandLyricsDisplayState,
        preferredContentWidth: Double,
        topInset: Double
    ) -> ScreenFrame {
        let size = size(for: state, preferredContentWidth: preferredContentWidth)
        let screenWidth = max(screenFrame.width, 0)
        let width = min(size.width, screenWidth)
        let screenMaxY = screenFrame.y + screenFrame.height
        let visibleMaxY = visibleFrame.y + visibleFrame.height
        let menuBarHeight = max(screenMaxY - visibleMaxY, 0)
        let centeredInMenuBarY = visibleMaxY + (menuBarHeight - size.height) / 2
        let topAttachedY = screenMaxY - size.height - topInset
        let y = menuBarHeight > 0 ? min(centeredInMenuBarY, topAttachedY) : topAttachedY

        return ScreenFrame(
            x: screenFrame.x + (screenWidth - width) / 2,
            y: y,
            width: width,
            height: size.height
        )
    }
}
