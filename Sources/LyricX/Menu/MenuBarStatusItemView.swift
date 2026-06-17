import AppKit
import LyricXCore

@MainActor
final class MenuBarStatusItemView: NSControl {
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

        let color = textColor()
        let textRect = textDrawingRect()

        if let symbol = presentation.symbol {
            drawSymbol(named: symbol, color: color)
        }

        drawText(in: textRect, color: color)
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    private func width(for presentation: MenuBarPresentation) -> CGFloat {
        CGFloat(max(24, layout(for: presentation).statusItemWidth))
    }

    private func textDrawingRect() -> NSRect {
        let layout = layout(for: presentation)
        let height = attributedText(color: .labelColor).size().height
        return NSRect(
            x: CGFloat(layout.textViewportMinX),
            y: floor((bounds.height - height) / 2),
            width: CGFloat(layout.textViewportWidth),
            height: height
        )
    }

    private func layout(for presentation: MenuBarPresentation) -> MenuBarStatusItemLayout {
        MenuBarStatusItemLayout(
            viewportWidth: presentation.style.viewportWidth,
            horizontalPadding: Double(horizontalPadding),
            leadingAccessoryWidth: presentation.symbol == nil ? 0 : Double(iconSize + iconSpacing)
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
            let marquee = MenuBarTimelineMarquee(viewportWidth: Double(rect.width))
            let offset = CGFloat(marquee.offset(elapsedTime: date.timeIntervalSince(startedAt), contentWidth: contentWidth))
            text.draw(at: NSPoint(x: rect.minX + offset, y: rect.minY))

            if contentWidth > Double(rect.width) {
                text.draw(at: NSPoint(x: rect.minX + offset + CGFloat(contentWidth) + CGFloat(marquee.gap), y: rect.minY))
            }
        case .staticText:
            text.draw(at: NSPoint(x: alignedTextX(for: text, in: rect), y: rect.minY))
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
                .font: NSFont.systemFont(ofSize: CGFloat(presentation.style.fontSize), weight: presentation.style.fontWeight.appKitWeight),
                .foregroundColor: color
            ]
        )
    }

    private func alignedTextX(for text: NSAttributedString, in rect: NSRect) -> CGFloat {
        let textWidth = ceil(text.size().width)
        guard textWidth < rect.width else {
            return rect.minX
        }

        switch presentation.style.alignment {
        case .leading:
            return rect.minX
        case .center:
            return rect.minX + floor((rect.width - textWidth) / 2)
        case .trailing:
            return rect.maxX - textWidth
        }
    }

    private func textColor() -> NSColor {
        if popoverHighlighted {
            return .selectedMenuItemTextColor
        }

        return NSColor(hex: presentation.style.textColorHex) ?? .labelColor
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

private extension MenuBarFontWeight {
    var appKitWeight: NSFont.Weight {
        switch self {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        }
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return nil
        }

        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
