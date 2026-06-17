import LyricXCore
import SwiftUI

struct MenuBarLabelView: View {
    let presentation: MenuBarPresentation
    let date: Date

    private let fixedTextWidth = MenuBarTextMetrics.viewportWidth

    var body: some View {
        HStack(spacing: 4) {
            if let symbol = presentation.symbol {
                Image(systemName: symbol)
            }

            labelText
        }
        .accessibilityLabel(presentation.accessibilityText)
    }

    @ViewBuilder
    private var labelText: some View {
        switch presentation.behavior {
        case .continuousMarquee(let contentWidth, let startedAt):
            continuousMarqueeText(contentWidth: contentWidth, startedAt: startedAt)
        case .staticText, .marquee:
            Text(presentation.text)
                .font(Self.font)
                .lineLimit(1)
                .frame(width: usesFixedTextWidth ? fixedTextWidth : nil, alignment: .leading)
                .fixedSize(horizontal: !usesFixedTextWidth, vertical: false)
                .clipped()
        }
    }

    private func continuousMarqueeText(contentWidth: Double, startedAt: Date) -> some View {
        let marquee = MenuBarTimelineMarquee(viewportWidth: Double(fixedTextWidth))
        let offset = CGFloat(marquee.offset(elapsedTime: date.timeIntervalSince(startedAt), contentWidth: contentWidth))
        let gap = CGFloat(marquee.gap)

        return ZStack(alignment: .leading) {
            marqueeText.offset(x: offset)

            if contentWidth > Double(fixedTextWidth) {
                marqueeText.offset(x: offset + CGFloat(contentWidth) + gap)
            }
        }
        .frame(width: fixedTextWidth, height: 18, alignment: .leading)
        .clipped()
    }

    private var usesFixedTextWidth: Bool {
        if case .continuousMarquee = presentation.behavior {
            return true
        }
        return presentation.symbol == nil || presentation.behavior == .marquee
    }

    private var marqueeText: some View {
        Text(presentation.text)
            .font(Self.font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private static let font = Font.system(size: MenuBarTextMetrics.fontSize, weight: .medium)
}
