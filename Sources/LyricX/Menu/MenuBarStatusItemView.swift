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
    private var clickFeedback = MenuBarClickFeedbackState()
    private var clickReleaseMonitors: [Any] = []
    private var cachedTextKey: AttributedTextKey?
    private var cachedAttributedText: NSAttributedString?

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

    func update(presentation: MenuBarPresentation, date: Date) {
        self.presentation = presentation
        self.date = date
        setAccessibilityLabel(presentation.accessibilityText)
        setFrameSize(intrinsicContentSize)
        needsDisplay = true
    }

    func beginClickFeedback() {
        _ = clickFeedback.press()
        startClickReleaseMonitoring()
        needsDisplay = true
    }

    func endClickFeedback() {
        stopClickReleaseMonitoring()
        let generation = clickFeedback.release()
        needsDisplay = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else {
                return
            }

            self.clickFeedback.expire(generation: generation)
            self.needsDisplay = true
        }
    }

    private func startClickReleaseMonitoring() {
        stopClickReleaseMonitoring()

        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.endClickFeedback()
            }
            return event
        }

        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.endClickFeedback()
            }
        }

        clickReleaseMonitors = [localMonitor, globalMonitor].compactMap { $0 }
    }

    private func stopClickReleaseMonitoring() {
        for monitor in clickReleaseMonitors {
            NSEvent.removeMonitor(monitor)
        }
        clickReleaseMonitors.removeAll()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if clickFeedback.isVisible {
            NSColor.labelColor.withAlphaComponent(0.12).setFill()
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
        beginClickFeedback()
        sendAction(action, to: target)
    }

    override func mouseUp(with event: NSEvent) {
        endClickFeedback()
    }

    private func width(for presentation: MenuBarPresentation) -> CGFloat {
        CGFloat(max(24, layout(for: presentation, attributedText: attributedText()).statusItemWidth))
    }

    private func textDrawingRect() -> NSRect {
        let text = attributedText()
        let layout = layout(for: presentation, attributedText: text)
        let height = text.size().height
        return NSRect(
            x: CGFloat(layout.textViewportMinX),
            y: floor((bounds.height - height) / 2),
            width: CGFloat(layout.textViewportWidth),
            height: height
        )
    }

    private func layout(for presentation: MenuBarPresentation, attributedText: NSAttributedString) -> MenuBarStatusItemLayout {
        MenuBarStatusItemLayout(
            maxViewportWidth: presentation.style.viewportWidth,
            contentWidth: contentWidth(for: presentation, attributedText: attributedText),
            horizontalPadding: Double(horizontalPadding),
            leadingAccessoryWidth: presentation.symbol == nil ? 0 : Double(iconSize + iconSpacing)
        )
    }

    private func contentWidth(for presentation: MenuBarPresentation, attributedText: NSAttributedString) -> Double {
        switch presentation.behavior {
        case .continuousMarquee(let contentWidth, _):
            return contentWidth
        case .staticText:
            return Double(ceil(attributedText.size().width))
        }
    }

    private func drawText(in rect: NSRect, color: NSColor) {
        guard let context = NSGraphicsContext.current else {
            return
        }

        context.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()

        let text = attributedText()
        switch presentation.behavior {
        case .continuousMarquee(let contentWidth, let startedAt):
            let marquee = MenuBarTimelineMarquee(viewportWidth: Double(rect.width))
            let offset = CGFloat(marquee.offset(elapsedTime: date.timeIntervalSince(startedAt), contentWidth: contentWidth))
            text.draw(at: NSPoint(x: rect.minX + offset, y: rect.minY))
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

    private func attributedText() -> NSAttributedString {
        let key = AttributedTextKey(presentation: presentation)
        if cachedTextKey == key, let cachedAttributedText {
            return cachedAttributedText
        }

        let text = NSAttributedString(
            string: presentation.text,
            attributes: [
                .font: NSFont.systemFont(ofSize: CGFloat(presentation.style.fontSize), weight: presentation.style.fontWeight.appKitWeight),
                .foregroundColor: textColor()
            ]
        )
        cachedTextKey = key
        cachedAttributedText = text
        return text
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

private struct AttributedTextKey: Equatable {
    let text: String
    let fontSize: Double
    let fontWeight: MenuBarFontWeight
    let textColorHex: String

    init(presentation: MenuBarPresentation) {
        self.text = presentation.text
        self.fontSize = presentation.style.fontSize
        self.fontWeight = presentation.style.fontWeight
        self.textColorHex = presentation.style.textColorHex
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
