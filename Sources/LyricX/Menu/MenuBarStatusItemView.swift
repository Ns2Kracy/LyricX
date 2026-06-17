import AppKit
import LyricXCore

@MainActor
final class MenuBarStatusItemView: NSControl {
    private let statusFont = NSFont.systemFont(ofSize: MenuBarTextMetrics.fontSize, weight: .medium)
    private let viewportWidth = MenuBarTextMetrics.viewportWidth
    private let horizontalPadding: CGFloat = 8
    private let iconSize: CGFloat = 14
    private let iconSpacing: CGFloat = 4
    private var presentation = MenuBarPresentation(
        text: "LyricX",
        accessibilityText: "LyricX",
        symbol: "music.note.list",
        behavior: .staticText
    )
    private var date = Date()
    private var popoverHighlighted = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setFrameSize(intrinsicContentSize)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: width(for: presentation), height: NSStatusBar.system.thickness)
    }

    func update(presentation: MenuBarPresentation, date: Date, highlighted: Bool) {
        self.presentation = presentation
        self.date = date
        self.popoverHighlighted = highlighted
        setAccessibilityLabel(presentation.accessibilityText)
        setFrameSize(intrinsicContentSize)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if popoverHighlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4).fill()
        }

        let color = popoverHighlighted ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
        let textRect = textDrawingRect()
        var textOriginX = textRect.minX

        if let symbol = presentation.symbol {
            drawSymbol(named: symbol, color: color)
            textOriginX += iconSize + iconSpacing
        }

        drawText(in: NSRect(
            x: textOriginX,
            y: textRect.minY,
            width: textRect.maxX - textOriginX,
            height: textRect.height
        ), color: color)
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    private func width(for presentation: MenuBarPresentation) -> CGFloat {
        let textWidth = switch presentation.behavior {
        case .continuousMarquee:
            viewportWidth
        case .staticText:
            min(ceil(attributedText(color: .labelColor).size().width), viewportWidth)
        }
        let iconWidth = presentation.symbol == nil ? 0 : iconSize + iconSpacing
        return max(24, horizontalPadding * 2 + iconWidth + textWidth)
    }

    private func textDrawingRect() -> NSRect {
        let height = attributedText(color: .labelColor).size().height
        return NSRect(
            x: horizontalPadding,
            y: floor((bounds.height - height) / 2),
            width: max(bounds.width - horizontalPadding * 2, 1),
            height: height
        )
    }

    private func drawText(in rect: NSRect, color: NSColor) {
        guard let context = NSGraphicsContext.current else {
            return
        }

        context.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()

        let text = attributedText(color: color)
        switch presentation.behavior {
        case .continuousMarquee(let contentWidth, let startedAt):
            let marquee = MenuBarTimelineMarquee(viewportWidth: Double(viewportWidth))
            let offset = CGFloat(marquee.offset(elapsedTime: date.timeIntervalSince(startedAt), contentWidth: contentWidth))
            text.draw(at: NSPoint(x: rect.minX + offset, y: rect.minY))

            if contentWidth > Double(viewportWidth) {
                text.draw(at: NSPoint(x: rect.minX + offset + CGFloat(contentWidth) + CGFloat(marquee.gap), y: rect.minY))
            }
        case .staticText:
            text.draw(at: NSPoint(x: rect.minX, y: rect.minY))
        }

        context.restoreGraphicsState()
    }

    private func drawSymbol(named name: String, color: NSColor) {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return
        }

        let rect = NSRect(
            x: horizontalPadding,
            y: floor((bounds.height - iconSize) / 2),
            width: iconSize,
            height: iconSize
        )
        tinted(image: image, color: color).draw(in: rect)
    }

    private func attributedText(color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: presentation.text,
            attributes: [
                .font: statusFont,
                .foregroundColor: color
            ]
        )
    }

    private func tinted(image: NSImage, color: NSColor) -> NSImage {
        let image = image.copy() as? NSImage ?? image
        image.lockFocus()
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
