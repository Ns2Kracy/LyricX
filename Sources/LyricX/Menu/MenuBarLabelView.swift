import SwiftUI

struct MenuBarLabelView: View {
    let presentation: MenuBarPresentation

    private let fixedTextWidth: CGFloat = 220

    var body: some View {
        HStack(spacing: 4) {
            if let symbol = presentation.symbol {
                Image(systemName: symbol)
            }

            Text(presentation.text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(width: usesFixedTextWidth ? fixedTextWidth : nil, alignment: .leading)
                .fixedSize(horizontal: !usesFixedTextWidth, vertical: false)
                .clipped()
        }
        .accessibilityLabel(presentation.accessibilityText)
    }

    private var usesFixedTextWidth: Bool {
        presentation.symbol == nil || presentation.behavior == .marquee
    }
}
