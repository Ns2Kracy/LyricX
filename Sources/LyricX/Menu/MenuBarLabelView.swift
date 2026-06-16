import SwiftUI

struct MenuBarLabelView: View {
    let presentation: MenuBarPresentation
    let date: Date

    var body: some View {
        HStack(spacing: 4) {
            if let symbol = presentation.symbol {
                Image(systemName: symbol)
            }

            switch presentation.behavior {
            case .staticText:
                Text(presentation.text)
                    .font(Self.font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            case .marquee:
                SmoothMenuBarMarqueeText(text: presentation.text, date: date)
            }
        }
        .accessibilityLabel(presentation.accessibilityText)
    }

    private static let font = Font.system(size: 13, weight: .medium)
}

private struct SmoothMenuBarMarqueeText: View {
    let text: String
    let date: Date

    @State private var textWidth: CGFloat = 0

    private let viewportWidth: CGFloat = 220
    private let gap: CGFloat = 36
    private let speed: CGFloat = 34
    private let startPause: TimeInterval = 0.8

    var body: some View {
        ZStack(alignment: .leading) {
            marqueeText
                .readWidth { textWidth = $0 }
                .offset(x: offset)

            if textWidth > viewportWidth {
                marqueeText
                    .offset(x: offset + textWidth + gap)
            }
        }
        .frame(width: viewportWidth, height: 18, alignment: .leading)
        .clipped()
    }

    private var marqueeText: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var offset: CGFloat {
        guard textWidth > viewportWidth else {
            return 0
        }

        let travel = textWidth + gap
        let movingDuration = TimeInterval(travel / speed)
        let cycleDuration = startPause + movingDuration
        let cycleTime = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)
        guard cycleTime > startPause else {
            return 0
        }

        let progress = min((cycleTime - startPause) / movingDuration, 1)
        return -travel * CGFloat(progress)
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func readWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: WidthPreferenceKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(WidthPreferenceKey.self, perform: onChange)
    }
}
