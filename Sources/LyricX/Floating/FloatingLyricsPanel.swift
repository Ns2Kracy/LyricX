import AppKit

@MainActor
final class FloatingLyricsPanel: NSPanel {
    init() {
        let size = NSSize(width: 820, height: 116)
        let origin = Self.defaultOrigin(for: size)
        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private static func defaultOrigin(for size: NSSize) -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 96
        )
    }
}
