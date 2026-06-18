import LyricXCore
import SwiftUI

struct FloatingLyricsView: View {
    let presentation: FloatingLyricsPresentation

    var body: some View {
        VStack(spacing: 6) {
            if presentation.usesKTV {
                ktvLine
            } else {
                Text(presentation.currentText)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            if let nextText = presentation.nextText {
                Text(nextText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(width: 720, height: 112)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(presentation.backgroundOpacity))
        )
    }

    private var ktvLine: some View {
        HStack(spacing: 0) {
            ForEach(Array(presentation.segments.enumerated()), id: \.offset) { _, segment in
                Text(segment.text)
                    .foregroundStyle(segment.isHighlighted ? Color.white : Color.white.opacity(0.35))
            }
        }
        .font(.system(size: 28, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}
