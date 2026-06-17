import LyricXCore
import SwiftUI

struct MenuBarLabelView: View {
    let presentation: MenuBarPresentation

    @State private var continuousTextWidth: CGFloat = 0

    private let fixedTextWidth: CGFloat = 220

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
        case .continuousMarquee(let progress):
            continuousMarqueeText(progress: progress)
        case .staticText, .marquee:
            Text(presentation.text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(width: usesFixedTextWidth ? fixedTextWidth : nil, alignment: .leading)
                .fixedSize(horizontal: !usesFixedTextWidth, vertical: false)
                .clipped()
        }
    }

    private func continuousMarqueeText(progress: Double) -> some View {
        let offset = CGFloat(MenuBarMarquee.scrollOffset(
            progress: progress,
            contentWidth: Double(continuousTextWidth),
            visibleWidth: Double(fixedTextWidth)
        ))

        return ZStack(alignment: .leading) {
            Text(presentation.text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(TextWidthReader())
                .offset(x: offset)
        }
        .frame(width: fixedTextWidth, alignment: .leading)
        .clipped()
        .onPreferenceChange(TextWidthPreferenceKey.self) { width in
            continuousTextWidth = width
        }
        .onChange(of: presentation.text) { _, _ in
            continuousTextWidth = 0
        }
        .animation(.linear(duration: 0.18), value: offset)
    }

    private var usesFixedTextWidth: Bool {
        if case .continuousMarquee = presentation.behavior {
            return true
        }
        return presentation.symbol == nil || presentation.behavior == .marquee
    }
}

private struct TextWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TextWidthReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: TextWidthPreferenceKey.self, value: proxy.size.width)
        }
    }
}
